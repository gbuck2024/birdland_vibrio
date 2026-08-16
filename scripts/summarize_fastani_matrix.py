#!/usr/bin/env python3
"""Summarize rectangular fastANI runs into genome and species ANI matrices."""

from __future__ import annotations

import csv
import os
import re
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
STAGE_DIR = PROJECT_DIR / Path(os.environ.get("STAGE_DIR", "ani/reference_panel_matrix"))
OUTPUT_DIR = STAGE_DIR / "outputs"
METRICS_DIR = STAGE_DIR / "metrics"
QUERY_MANIFEST = PROJECT_DIR / Path(os.environ.get("QUERY_MANIFEST", "configs/reference_sequence_manifest.tsv"))
REFERENCE_MANIFEST = PROJECT_DIR / Path(os.environ.get("REFERENCE_MANIFEST", "configs/reference_sequence_manifest.tsv"))
EXTRA_QUERY_MANIFEST = os.environ.get("EXTRA_QUERY_MANIFEST", "")
EXTRA_REFERENCE_MANIFEST = os.environ.get("EXTRA_REFERENCE_MANIFEST", "")
AF_FILTER_THRESHOLD = float(os.environ.get("AF_FILTER_THRESHOLD", "0.50"))
AF_FILTER_LABEL = f"{AF_FILTER_THRESHOLD:.2f}".replace(".", "_")

UNKNOWN_IDS = {
    value.strip()
    for value in os.environ.get(
        "UNKNOWN_IDS",
        "Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7,"
        "Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7,"
        "Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7,"
        "Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7,"
        "Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7,"
        "Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7",
    ).split(",")
    if value.strip()
}


def parse_species(notes: str, fallback_id: str) -> str:
    match = re.search(r"Vibrio [a-z]+", notes)
    if match:
        return match.group(0)
    if fallback_id.startswith("Buck_"):
        return "unknown"
    return "unknown"


def load_manifest(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise SystemExit(f"ERROR: Manifest not found: {path}")
    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows:
        raise SystemExit(f"ERROR: Manifest has no data rows: {path}")

    normalized: list[dict[str, str]] = []
    for row in rows:
        genome_id = row.get("genome_id") or row.get("reference_id") or row.get("sample_id")
        genome_fasta = row.get("genome_fasta") or row.get("reference_fasta") or row.get("query_fasta")
        if not genome_id or not genome_fasta:
            raise SystemExit(f"ERROR: Manifest row lacks usable ID/path columns in {path}: {row}")
        notes = row.get("notes", "")
        species = row.get("species") or parse_species(notes, genome_id)
        genome_type = row.get("genome_type") or row.get("reference_format") or row.get("query_format") or "query_genome"
        normalized.append(
            {
                "genome_id": genome_id,
                "genome_fasta": genome_fasta,
                "species": species,
                "genome_type": genome_type,
                "is_unknown": "yes" if genome_id in UNKNOWN_IDS else row.get("is_unknown", "no"),
                "notes": notes,
            }
        )
    return normalized


def load_manifest_set(primary: Path, extra: str) -> list[dict[str, str]]:
    rows = load_manifest(primary)
    if extra:
        rows.extend(load_manifest(PROJECT_DIR / Path(extra)))
    seen: set[str] = set()
    deduped: list[dict[str, str]] = []
    for row in rows:
        if row["genome_id"] in seen:
            raise SystemExit(f"ERROR: Duplicate genome_id in matrix manifests: {row['genome_id']}")
        seen.add(row["genome_id"])
        deduped.append(row)
    return deduped


def parse_fastani_output(path: Path) -> dict[str, dict[str, str]]:
    results: dict[str, dict[str, str]] = {}
    if not path.is_file():
        return results
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            query_path, reference_path, ani_value, fragment_mappings, total_fragments = line.split("\t")
            results[reference_path] = {
                "query_path": query_path,
                "reference_path": reference_path,
                "ani_pct": f"{float(ani_value):.4f}",
                "fragment_mappings": fragment_mappings,
                "query_fragments": total_fragments,
            }
    return results


def write_normalized_manifest(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["genome_id", "genome_fasta", "species", "genome_type", "is_unknown", "notes"],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(rows)


def write_matrix(path: Path, row_ids: list[str], col_ids: list[str], values: dict[tuple[str, str], str], row_label: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow([row_label, *col_ids])
        for row_id in row_ids:
            writer.writerow([row_id, *[values.get((row_id, col_id), "NA") for col_id in col_ids]])


def calculate_alignment_fraction(fragment_mappings: str, query_fragments: str) -> str:
    try:
        mappings = float(fragment_mappings)
        fragments = float(query_fragments)
    except ValueError:
        return "NA"
    if fragments <= 0:
        return "NA"
    return f"{mappings / fragments:.4f}"


def main() -> int:
    queries = load_manifest_set(QUERY_MANIFEST, EXTRA_QUERY_MANIFEST)
    references = load_manifest_set(REFERENCE_MANIFEST, EXTRA_REFERENCE_MANIFEST)
    METRICS_DIR.mkdir(parents=True, exist_ok=True)

    write_normalized_manifest(METRICS_DIR / "query_manifest.normalized.tsv", queries)
    write_normalized_manifest(METRICS_DIR / "reference_manifest.normalized.tsv", references)

    reference_by_path = {row["genome_fasta"]: row for row in references}
    long_rows: list[dict[str, str]] = []
    matrix_values: dict[tuple[str, str], str] = {}
    af_values: dict[tuple[str, str], str] = {}
    af_filtered_matrix_values: dict[tuple[str, str], str] = {}
    missing_outputs: list[str] = []

    for query in queries:
        output_path = OUTPUT_DIR / f"{query['genome_id']}.fastani.tsv"
        if not output_path.is_file():
            missing_outputs.append(str(output_path.relative_to(PROJECT_DIR)))
            continue
        raw_results = parse_fastani_output(output_path)
        for reference in references:
            result = raw_results.get(reference["genome_fasta"])
            ani_pct = result["ani_pct"] if result else "NA"
            fragment_mappings = result["fragment_mappings"] if result else "0"
            query_fragments = result["query_fragments"] if result else "0"
            alignment_fraction = calculate_alignment_fraction(fragment_mappings, query_fragments)
            matrix_values[(query["genome_id"], reference["genome_id"])] = ani_pct
            af_values[(query["genome_id"], reference["genome_id"])] = alignment_fraction
            if alignment_fraction != "NA" and float(alignment_fraction) >= AF_FILTER_THRESHOLD:
                af_filtered_matrix_values[(query["genome_id"], reference["genome_id"])] = ani_pct
            long_rows.append(
                {
                    "query_id": query["genome_id"],
                    "query_fasta": query["genome_fasta"],
                    "query_species": query["species"],
                    "query_type": query["genome_type"],
                    "query_is_unknown": query["is_unknown"],
                    "reference_id": reference["genome_id"],
                    "reference_fasta": reference["genome_fasta"],
                    "reference_species": reference["species"],
                    "reference_type": reference["genome_type"],
                    "reference_is_unknown": reference["is_unknown"],
                    "ani_pct": ani_pct,
                    "fragment_mappings": fragment_mappings,
                    "query_fragments": query_fragments,
                    "alignment_fraction": alignment_fraction,
                }
            )

    if missing_outputs:
        joined = "\n".join(f"- {path}" for path in sorted(missing_outputs))
        raise SystemExit(f"ERROR: Missing fastANI output files:\n{joined}")

    long_tsv = METRICS_DIR / "fastani_matrix_long.tsv"
    with long_tsv.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "query_id",
                "query_fasta",
                "query_species",
                "query_type",
                "query_is_unknown",
                "reference_id",
                "reference_fasta",
                "reference_species",
                "reference_type",
                "reference_is_unknown",
                "ani_pct",
                "fragment_mappings",
                "query_fragments",
                "alignment_fraction",
            ],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(long_rows)

    write_matrix(
        METRICS_DIR / "fastani_genome_matrix.tsv",
        [row["genome_id"] for row in queries],
        [row["genome_id"] for row in references],
        matrix_values,
        "query_id",
    )
    write_matrix(
        METRICS_DIR / "fastani_alignment_fraction_matrix.tsv",
        [row["genome_id"] for row in queries],
        [row["genome_id"] for row in references],
        af_values,
        "query_id",
    )
    af_filtered_matrix_tsv = METRICS_DIR / f"fastani_genome_matrix_af_ge_{AF_FILTER_LABEL}.tsv"
    write_matrix(
        af_filtered_matrix_tsv,
        [row["genome_id"] for row in queries],
        [row["genome_id"] for row in references],
        af_filtered_matrix_values,
        "query_id",
    )

    species_pairs: dict[tuple[str, str], list[float]] = {}
    for row in long_rows:
        if row["ani_pct"] == "NA":
            continue
        key = (row["query_species"], row["reference_species"])
        species_pairs.setdefault(key, []).append(float(row["ani_pct"]))

    query_species = sorted({row["species"] for row in queries})
    reference_species = sorted({row["species"] for row in references})
    max_values: dict[tuple[str, str], str] = {}
    mean_values: dict[tuple[str, str], str] = {}
    for key, vals in species_pairs.items():
        max_values[key] = f"{max(vals):.4f}"
        mean_values[key] = f"{sum(vals) / len(vals):.4f}"

    write_matrix(METRICS_DIR / "fastani_species_max_matrix.tsv", query_species, reference_species, max_values, "query_species")
    write_matrix(METRICS_DIR / "fastani_species_mean_matrix.tsv", query_species, reference_species, mean_values, "query_species")

    print(f"Wrote long ANI table: {long_tsv.relative_to(PROJECT_DIR)}")
    print(f"Wrote genome ANI matrix: {(METRICS_DIR / 'fastani_genome_matrix.tsv').relative_to(PROJECT_DIR)}")
    print(f"Wrote alignment fraction matrix: {(METRICS_DIR / 'fastani_alignment_fraction_matrix.tsv').relative_to(PROJECT_DIR)}")
    print(f"Wrote AF-filtered genome ANI matrix: {af_filtered_matrix_tsv.relative_to(PROJECT_DIR)}")
    print(f"Wrote species max ANI matrix: {(METRICS_DIR / 'fastani_species_max_matrix.tsv').relative_to(PROJECT_DIR)}")
    print(f"Wrote species mean ANI matrix: {(METRICS_DIR / 'fastani_species_mean_matrix.tsv').relative_to(PROJECT_DIR)}")
    print(f"Reference path lookup entries: {len(reference_by_path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
