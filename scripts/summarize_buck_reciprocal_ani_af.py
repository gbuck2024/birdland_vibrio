#!/usr/bin/env python3
"""Summarize reciprocal ANI and alignment fraction for the Buck genomes."""

from __future__ import annotations

import csv
import os
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
STAGE_DIR = PROJECT_DIR / Path(os.environ.get("STAGE_DIR", "ani/reference_panel_plus_unknown_matrix"))
METRICS_DIR = STAGE_DIR / "metrics"
LONG_TSV = METRICS_DIR / "fastani_matrix_long.tsv"
OUTPUT_TSV = METRICS_DIR / "buck_reciprocal_ani_af_summary.tsv"
OUTPUT_MD = METRICS_DIR / "buck_reciprocal_ani_af_summary.md"
MIN_AF = float(os.environ.get("MIN_RECIPROCAL_AF", "0.50"))
SPECIES_ANI_THRESHOLD = float(os.environ.get("SPECIES_ANI_THRESHOLD", "95.0"))


def read_long_table(path: Path) -> list[dict[str, str]]:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"ERROR: Missing or empty fastANI long table: {path}")
    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    required = {
        "query_id",
        "query_is_unknown",
        "reference_id",
        "reference_species",
        "reference_is_unknown",
        "ani_pct",
        "alignment_fraction",
    }
    missing = sorted(required.difference(rows[0].keys())) if rows else sorted(required)
    if missing:
        raise SystemExit(f"ERROR: Long table missing column(s): {', '.join(missing)}")
    return rows


def parse_float(value: str) -> float | None:
    if value == "NA" or value == "":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def format_float(value: float | None, digits: int) -> str:
    if value is None:
        return "NA"
    return f"{value:.{digits}f}"


def interpret(ani: float | None, buck_to_ref_af: float | None, ref_to_buck_af: float | None) -> str:
    has_reciprocal_af = (
        buck_to_ref_af is not None
        and ref_to_buck_af is not None
        and buck_to_ref_af >= MIN_AF
        and ref_to_buck_af >= MIN_AF
    )
    has_one_low_af = (
        buck_to_ref_af is None
        or ref_to_buck_af is None
        or buck_to_ref_af < MIN_AF
        or ref_to_buck_af < MIN_AF
    )

    if ani is None:
        return "No reciprocal ANI hit; unresolved with this reference panel."
    if ani >= SPECIES_ANI_THRESHOLD and has_reciprocal_af:
        return "Strong species-level support; ANI is above threshold and reciprocal AF is adequate."
    if ani >= SPECIES_ANI_THRESHOLD and has_one_low_af:
        return "High ANI but incomplete reciprocal genome coverage; treat cautiously."
    if has_reciprocal_af:
        return "Best reciprocal-covered candidate, but ANI is below the usual species threshold."
    return "Weak reciprocal coverage; candidate is tentative and should not be treated as species-level support."


def candidate_sort_key(candidate: dict[str, object]) -> tuple[float, float, float, float]:
    min_af = candidate["min_af"]
    reciprocal_ani = candidate["reciprocal_ani"]
    buck_to_ref_af = candidate["buck_to_ref_af"]
    ref_to_buck_af = candidate["ref_to_buck_af"]
    return (
        reciprocal_ani if isinstance(reciprocal_ani, float) else -1.0,
        min_af if isinstance(min_af, float) else -1.0,
        buck_to_ref_af if isinstance(buck_to_ref_af, float) else -1.0,
        ref_to_buck_af if isinstance(ref_to_buck_af, float) else -1.0,
    )


def write_markdown(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        handle.write("# Buck Reciprocal ANI/AF Summary\n\n")
        handle.write(
            f"Candidate calls are selected from non-Buck references using the highest reciprocal ANI; "
            f"AF is then reported in both directions to show genome coverage. AF is "
            f"`fragment_mappings / query_fragments`; reciprocal AF support requires both "
            f"directions to be at least `{MIN_AF:.2f}`.\n\n"
        )
        headers = ["buck isolate", "candidate species", "ANI", "Buck->ref AF", "ref AF -> Buck", "interpretation"]
        handle.write("| " + " | ".join(headers) + " |\n")
        handle.write("| " + " | ".join(["---"] * len(headers)) + " |\n")
        for row in rows:
            handle.write(
                "| "
                + " | ".join(
                    [
                        row["buck isolate"],
                        row["candidate species"],
                        row["ANI"],
                        row["Buck->ref AF"],
                        row["ref AF -> Buck"],
                        row["interpretation"],
                    ]
                )
                + " |\n"
            )


def main() -> int:
    rows = read_long_table(LONG_TSV)
    by_pair = {(row["query_id"], row["reference_id"]): row for row in rows}
    buck_ids = sorted({row["query_id"] for row in rows if row["query_is_unknown"] == "yes"})
    if not buck_ids:
        raise SystemExit("ERROR: No Buck/unknown query rows found in fastANI long table.")

    summary_rows: list[dict[str, str]] = []
    for buck_id in buck_ids:
        candidates: list[dict[str, object]] = []
        for row in rows:
            if row["query_id"] != buck_id or row["reference_is_unknown"] == "yes":
                continue
            reverse = by_pair.get((row["reference_id"], buck_id))
            buck_to_ref_ani = parse_float(row["ani_pct"])
            ref_to_buck_ani = parse_float(reverse["ani_pct"]) if reverse else None
            buck_to_ref_af = parse_float(row["alignment_fraction"])
            ref_to_buck_af = parse_float(reverse["alignment_fraction"]) if reverse else None
            ani_values = [value for value in [buck_to_ref_ani, ref_to_buck_ani] if value is not None]
            reciprocal_ani = sum(ani_values) / len(ani_values) if ani_values else None
            af_values = [value for value in [buck_to_ref_af, ref_to_buck_af] if value is not None]
            min_af = min(af_values) if af_values else None
            candidates.append(
                {
                    "candidate_species": row["reference_species"],
                    "reciprocal_ani": reciprocal_ani,
                    "buck_to_ref_af": buck_to_ref_af,
                    "ref_to_buck_af": ref_to_buck_af,
                    "min_af": min_af,
                }
            )
        if not candidates:
            raise SystemExit(f"ERROR: No non-Buck candidate references found for {buck_id}")
        best = max(candidates, key=candidate_sort_key)
        reciprocal_ani = best["reciprocal_ani"] if isinstance(best["reciprocal_ani"], float) else None
        buck_to_ref_af = best["buck_to_ref_af"] if isinstance(best["buck_to_ref_af"], float) else None
        ref_to_buck_af = best["ref_to_buck_af"] if isinstance(best["ref_to_buck_af"], float) else None
        summary_rows.append(
            {
                "buck isolate": buck_id,
                "candidate species": str(best["candidate_species"]),
                "ANI": format_float(reciprocal_ani, 4),
                "Buck->ref AF": format_float(buck_to_ref_af, 4),
                "ref AF -> Buck": format_float(ref_to_buck_af, 4),
                "interpretation": interpret(reciprocal_ani, buck_to_ref_af, ref_to_buck_af),
            }
        )

    with OUTPUT_TSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["buck isolate", "candidate species", "ANI", "Buck->ref AF", "ref AF -> Buck", "interpretation"],
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(summary_rows)
    write_markdown(OUTPUT_MD, summary_rows)
    print(f"Wrote Buck reciprocal ANI/AF summary: {OUTPUT_TSV.relative_to(PROJECT_DIR)}")
    print(f"Wrote Buck reciprocal ANI/AF report: {OUTPUT_MD.relative_to(PROJECT_DIR)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
