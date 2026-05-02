#!/usr/bin/env python3
"""Summarize fastANI outputs into long and matrix TSV tables."""

from __future__ import annotations

import csv
import os
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
QUERY_MANIFEST = PROJECT_DIR / Path(os.environ.get("QUERY_MANIFEST", "configs/ani_query_manifest.tsv"))
REFERENCE_MANIFEST_DEFAULT = PROJECT_DIR / Path(os.environ.get("REFERENCE_MANIFEST", "configs/ani_reference_manifest.tsv"))
REFERENCE_MANIFEST_FALLBACK = PROJECT_DIR / "configs" / "multi_reference_reference_manifest.tsv"
STAGE_DIR = PROJECT_DIR / Path(os.environ.get("STAGE_DIR", "ani"))
OUTPUT_DIR = STAGE_DIR / "outputs"
METRICS_DIR = STAGE_DIR / "metrics"
SUMMARY_TSV = METRICS_DIR / "ani_summary.tsv"
ANI_MATRIX_TSV = METRICS_DIR / "ani_matrix.tsv"

V_VULNIFICUS_THRESHOLD = 95.0
SPECIES_LEVEL_THRESHOLD = 95.0


def load_tsv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise SystemExit(f"ERROR: Required TSV not found: {path}")

    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))

    if not rows:
        raise SystemExit(f"ERROR: TSV contains no data rows: {path}")

    return rows


def resolve_reference_manifest() -> Path:
    if REFERENCE_MANIFEST_DEFAULT.is_file():
        return REFERENCE_MANIFEST_DEFAULT
    if REFERENCE_MANIFEST_FALLBACK.is_file():
        return REFERENCE_MANIFEST_FALLBACK

    autodetect_rows = []
    for fasta_path in sorted((PROJECT_DIR / "reference").glob("*.fasta")):
        fasta_rel = fasta_path.relative_to(PROJECT_DIR).as_posix()
        fasta_base = fasta_path.name
        reference_id = fasta_base.removesuffix("_ref.fasta").removesuffix(".fasta")
        autodetect_rows.append(
            {
                "reference_id": reference_id,
                "reference_fasta": fasta_rel,
                "reference_format": "autodetected_reference",
                "notes": "Autodetected from the reference directory because no ANI reference manifest was found.",
            }
        )

    if not autodetect_rows:
        raise SystemExit("ERROR: No ANI reference manifest available and no reference FASTA files found under reference/.")

    autodetect_path = METRICS_DIR / "ani_reference_manifest_autodetected.tsv"
    METRICS_DIR.mkdir(parents=True, exist_ok=True)
    with autodetect_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["reference_id", "reference_fasta", "reference_format", "notes"],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(autodetect_rows)
    return autodetect_path


def parse_fastani_output(path: Path) -> dict[str, dict[str, str]]:
    results: dict[str, dict[str, str]] = {}

    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue

            query_path, reference_path, ani_value, fragment_mappings, total_fragments = line.split("\t")
            results[reference_path] = {
                "query_path": query_path,
                "reference_path": reference_path,
                "ani_pct": f"{float(ani_value):.2f}",
                "fragment_mappings": fragment_mappings,
                "query_fragments": total_fragments,
            }

    return results


def interpret_sample(best_reference_id: str, best_ani: float) -> str:
    if best_reference_id == "v_vulnificus" and best_ani >= V_VULNIFICUS_THRESHOLD:
        return "likely Vibrio vulnificus"
    if best_ani >= SPECIES_LEVEL_THRESHOLD:
        return "likely other Vibrio species"
    return "outlier_or_below_species_threshold"


def main() -> int:
    queries = load_tsv(QUERY_MANIFEST)
    references = load_tsv(resolve_reference_manifest())
    METRICS_DIR.mkdir(parents=True, exist_ok=True)

    reference_lookup = {row["reference_fasta"]: row for row in references}
    summary_rows: list[dict[str, str]] = []
    matrix_lookup: dict[tuple[str, str], str] = {}

    missing_outputs: list[str] = []
    for query in queries:
        sample_id = query["sample_id"]
        query_fasta = query["query_fasta"]
        output_path = OUTPUT_DIR / f"{sample_id}.fastani.tsv"
        if not output_path.is_file():
            missing_outputs.append(str(output_path.relative_to(PROJECT_DIR)))
            continue

        raw_results = parse_fastani_output(output_path)
        best_reference_id = "NA"
        best_ani = -1.0

        for reference in references:
            reference_id = reference["reference_id"]
            reference_fasta = reference["reference_fasta"]
            raw_result = raw_results.get(reference_fasta)

            if raw_result is None:
                ani_pct = "NA"
                fragment_mappings = "0"
                query_fragments = "0"
            else:
                ani_pct = raw_result["ani_pct"]
                fragment_mappings = raw_result["fragment_mappings"]
                query_fragments = raw_result["query_fragments"]
                ani_value = float(ani_pct)
                if ani_value > best_ani:
                    best_ani = ani_value
                    best_reference_id = reference_id

            matrix_lookup[(sample_id, reference_id)] = ani_pct
            summary_rows.append(
                {
                    "sample_id": sample_id,
                    "query_fasta": query_fasta,
                    "reference_id": reference_id,
                    "reference_fasta": reference_fasta,
                    "reference_format": reference["reference_format"],
                    "reference_notes": reference["notes"],
                    "ani_pct": ani_pct,
                    "fragment_mappings": fragment_mappings,
                    "query_fragments": query_fragments,
                    "best_reference_id": "NA",
                    "best_ani_pct": "NA",
                    "species_interpretation": "NA",
                }
            )

        if best_ani >= 0:
            interpretation = interpret_sample(best_reference_id, best_ani)
            best_ani_text = f"{best_ani:.2f}"
        else:
            interpretation = "outlier_or_no_fastani_hit"
            best_ani_text = "NA"

        for row in summary_rows:
            if row["sample_id"] == sample_id:
                row["best_reference_id"] = best_reference_id
                row["best_ani_pct"] = best_ani_text
                row["species_interpretation"] = interpretation

    if missing_outputs:
        joined = "\n".join(f"- {path}" for path in sorted(missing_outputs))
        raise SystemExit(
            "ERROR: Missing expected fastANI outputs. Run the ANI array jobs first or finish incomplete tasks:\n"
            f"{joined}"
        )

    summary_rows.sort(key=lambda row: (row["sample_id"], row["reference_id"]))

    with SUMMARY_TSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "sample_id",
                "query_fasta",
                "reference_id",
                "reference_fasta",
                "reference_format",
                "reference_notes",
                "ani_pct",
                "fragment_mappings",
                "query_fragments",
                "best_reference_id",
                "best_ani_pct",
                "species_interpretation",
            ],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(summary_rows)

    reference_ids = [reference["reference_id"] for reference in references]
    with ANI_MATRIX_TSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["sample_id", *reference_ids, "best_reference_id", "best_ani_pct", "species_interpretation"])

        best_by_sample: dict[str, tuple[str, str, str]] = {}
        for row in summary_rows:
            best_by_sample[row["sample_id"]] = (
                row["best_reference_id"],
                row["best_ani_pct"],
                row["species_interpretation"],
            )

        for query in queries:
            sample_id = query["sample_id"]
            best_reference_id, best_ani_pct, interpretation = best_by_sample[sample_id]
            writer.writerow(
                [
                    sample_id,
                    *[matrix_lookup[(sample_id, reference_id)] for reference_id in reference_ids],
                    best_reference_id,
                    best_ani_pct,
                    interpretation,
                ]
            )

    print(f"Wrote ANI summary table: {SUMMARY_TSV.relative_to(PROJECT_DIR)}")
    print(f"Wrote ANI matrix: {ANI_MATRIX_TSV.relative_to(PROJECT_DIR)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
