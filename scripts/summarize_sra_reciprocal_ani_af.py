#!/usr/bin/env python3
"""Summarize SRA best ANI assignments with reciprocal alignment fractions."""

from __future__ import annotations

import csv
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parent.parent
FORWARD_LONG = PROJECT_DIR / "ani/sra_vs_reference_panel/metrics/fastani_matrix_long.tsv"
REVERSE_LONG = PROJECT_DIR / "ani/sra_reciprocal_reference_to_sra/metrics/fastani_matrix_long.tsv"
OUTPUT_TSV = PROJECT_DIR / "ani/sra_vs_reference_panel/metrics/sra_reciprocal_ani_af_summary.tsv"
OUTPUT_MD = PROJECT_DIR / "ani/sra_vs_reference_panel/metrics/sra_reciprocal_ani_af_summary.md"


def load_rows(path: Path) -> list[dict[str, str]]:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"Missing or empty ANI long table: {path}")
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def numeric(value: str) -> float:
    if value == "NA" or value == "":
        return -1.0
    return float(value)


def main() -> int:
    forward_rows = load_rows(FORWARD_LONG)
    reverse_rows = load_rows(REVERSE_LONG)

    best_by_sample: dict[str, dict[str, str]] = {}
    for row in forward_rows:
        if row["ani_pct"] == "NA":
            continue
        sample_id = row["query_id"]
        current = best_by_sample.get(sample_id)
        row_key = (numeric(row["ani_pct"]), numeric(row["alignment_fraction"]))
        current_key = (
            numeric(current["ani_pct"]),
            numeric(current["alignment_fraction"]),
        ) if current else (-1.0, -1.0)
        if row_key > current_key:
            best_by_sample[sample_id] = row

    reverse_lookup = {
        (row["query_id"], row["reference_id"]): row
        for row in reverse_rows
        if row["ani_pct"] != "NA"
    }

    output_rows: list[dict[str, str]] = []
    for sample_id in sorted(best_by_sample):
        forward = best_by_sample[sample_id]
        reference_id = forward["reference_id"]
        reverse = reverse_lookup.get((reference_id, sample_id))
        if reverse is None:
            reverse_ani = "NA"
            reverse_af = "NA"
            reciprocal_af_min = "NA"
            interpretation = "missing reciprocal reference-to-SRA ANI cell"
        else:
            reverse_ani = reverse["ani_pct"]
            reverse_af = reverse["alignment_fraction"]
            reciprocal_af_min = f"{min(float(forward['alignment_fraction']), float(reverse_af)):.4f}"
            if float(forward["ani_pct"]) >= 95.0 and float(reciprocal_af_min) >= 0.50:
                interpretation = "species-level ANI supported with reciprocal AF >= 0.50"
            elif float(forward["ani_pct"]) >= 95.0:
                interpretation = "high ANI but reciprocal AF below 0.50"
            else:
                interpretation = "ANI below species-level threshold"

        output_rows.append(
            {
                "sample_id": sample_id,
                "candidate_species": forward["reference_species"],
                "best_reference_id": reference_id,
                "sra_to_reference_ani": forward["ani_pct"],
                "sra_to_reference_af": forward["alignment_fraction"],
                "reference_to_sra_ani": reverse_ani,
                "reference_to_sra_af": reverse_af,
                "reciprocal_af_min": reciprocal_af_min,
                "interpretation": interpretation,
            }
        )

    OUTPUT_TSV.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "sample_id",
        "candidate_species",
        "best_reference_id",
        "sra_to_reference_ani",
        "sra_to_reference_af",
        "reference_to_sra_ani",
        "reference_to_sra_af",
        "reciprocal_af_min",
        "interpretation",
    ]
    with OUTPUT_TSV.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(output_rows)

    with OUTPUT_MD.open("w", encoding="utf-8") as handle:
        handle.write("# SRA Reciprocal ANI/AF Summary\n\n")
        handle.write("| Sample | Candidate species | Best reference | SRA->ref ANI | SRA->ref AF | Ref->SRA ANI | Ref->SRA AF | Min reciprocal AF | Interpretation |\n")
        handle.write("|---|---|---|---:|---:|---:|---:|---:|---|\n")
        for row in output_rows:
            handle.write(
                f"| {row['sample_id']} | {row['candidate_species']} | {row['best_reference_id']} | "
                f"{row['sra_to_reference_ani']} | {row['sra_to_reference_af']} | "
                f"{row['reference_to_sra_ani']} | {row['reference_to_sra_af']} | "
                f"{row['reciprocal_af_min']} | {row['interpretation']} |\n"
            )

    print(f"Wrote reciprocal ANI/AF summary: {OUTPUT_TSV.relative_to(PROJECT_DIR)}")
    print(f"Wrote reciprocal ANI/AF report: {OUTPUT_MD.relative_to(PROJECT_DIR)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
