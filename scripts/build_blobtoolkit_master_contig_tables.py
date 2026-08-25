#!/usr/bin/env python3
"""Build per-sample and combined master contig tables for BlobToolKit results."""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
from pathlib import Path


COLUMNS = [
    "short_id",
    "sample_id",
    "contig_id",
    "length_bp",
    "gc_fraction",
    "gc_percent",
    "coverage",
    "coverage_log10",
    "kraken_status",
    "taxon_label",
    "taxid",
    "kraken_length",
    "lca_mapping",
    "broad_taxon",
]


def read_manifest(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        required = {"short_id", "sample_id", "trimmed_r1", "trimmed_r2", "spades_contigs"}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            raise SystemExit(f"Manifest {path} is missing column(s): {', '.join(sorted(missing))}")
        rows = list(reader)
    if not rows:
        raise SystemExit(f"Manifest {path} contains no sample rows.")
    return rows


def read_btk_values(path: Path) -> list:
    with path.open() as handle:
        parsed = json.load(handle)
    if "values" not in parsed:
        raise SystemExit(f"BlobToolKit JSON lacks a values array: {path}")
    return parsed["values"]


def read_kraken(path: Path) -> dict[str, dict[str, str]]:
    classifications: dict[str, dict[str, str]] = {}
    with path.open(newline="") as handle:
        reader = csv.reader(handle, delimiter="\t")
        for line_number, row in enumerate(reader, start=1):
            if len(row) < 5:
                raise SystemExit(f"Malformed Kraken2 row {line_number} in {path}: expected at least 5 columns")
            status, contig_id, taxon_label, kraken_length, lca_mapping = row[:5]
            classifications[contig_id] = {
                "kraken_status": status,
                "taxon_label": taxon_label,
                "kraken_length": kraken_length,
                "lca_mapping": lca_mapping,
            }
    if not classifications:
        raise SystemExit(f"Kraken2 output has no classifications: {path}")
    return classifications


def classify_taxon(taxon_label: str, kraken_status: str) -> str:
    label = taxon_label.lower()
    if kraken_status == "U" or "unclassified" in label or "taxid 0" in label:
        return "Unclassified"
    if re.search(r"\bvibrio\b", label):
        return "Vibrio"
    if re.search(r"\bbacillus\b", label):
        return "Bacillus"
    if re.search(r"\breyranella\b", label):
        return "Reyranella"
    return "Other classified"


def extract_taxid(taxon_label: str) -> str:
    match = re.search(r"\(taxid ([0-9]+)\)", taxon_label)
    return match.group(1) if match else ""


def require_file(path: Path, label: str) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"{label} missing or empty: {path}")


def resolve_path(project_dir: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else project_dir / path


def write_table(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def build_rows(project_dir: Path, stage_root: Path, manifest_row: dict[str, str]) -> list[dict[str, object]]:
    short_id = manifest_row["short_id"]
    sample_id = manifest_row["sample_id"]
    stage_dir = stage_root / short_id
    blobdir = stage_dir / "blobdir"
    taxonomy_dir = stage_dir / "taxonomy"

    ids_json = blobdir / "identifiers.json"
    gc_json = blobdir / "gc.json"
    length_json = blobdir / "length.json"
    coverage_json = blobdir / f"{sample_id}.self_contigs.sorted_cov.json"
    kraken_tsv = taxonomy_dir / f"{sample_id}.spades_contigs.kraken2.tsv"
    contigs_fasta = resolve_path(project_dir, manifest_row["spades_contigs"])

    for path, label in [
        (ids_json, "BlobToolKit identifiers"),
        (gc_json, "BlobToolKit GC values"),
        (length_json, "BlobToolKit lengths"),
        (coverage_json, "BlobToolKit self-mapping coverage"),
        (kraken_tsv, "Kraken2 per-contig classification"),
        (contigs_fasta, "SPAdes contigs FASTA"),
    ]:
        require_file(path, label)

    contig_ids = read_btk_values(ids_json)
    gc_fraction = [float(value) for value in read_btk_values(gc_json)]
    lengths = [int(value) for value in read_btk_values(length_json)]
    coverage = [float(value) for value in read_btk_values(coverage_json)]
    kraken = read_kraken(kraken_tsv)

    lengths_seen = {len(contig_ids), len(gc_fraction), len(lengths), len(coverage)}
    if len(lengths_seen) != 1:
        raise SystemExit(
            f"BlobToolKit arrays differ in length for {short_id}: "
            f"ids={len(contig_ids)} gc={len(gc_fraction)} length={len(lengths)} coverage={len(coverage)}"
        )

    missing_kraken = [contig_id for contig_id in contig_ids if contig_id not in kraken]
    if missing_kraken:
        preview = ", ".join(missing_kraken[:5])
        raise SystemExit(f"{len(missing_kraken)} contig(s) from {short_id} are missing Kraken2 rows: {preview}")

    rows: list[dict[str, object]] = []
    for contig_id, gc_value, length_bp, cov_value in zip(contig_ids, gc_fraction, lengths, coverage):
        classification = kraken[contig_id]
        taxon_label = classification["taxon_label"]
        kraken_status = classification["kraken_status"]
        rows.append(
            {
                "short_id": short_id,
                "sample_id": sample_id,
                "contig_id": contig_id,
                "length_bp": length_bp,
                "gc_fraction": gc_value,
                "gc_percent": gc_value * 100,
                "coverage": cov_value,
                "coverage_log10": math.log10(cov_value + 1),
                "kraken_status": kraken_status,
                "taxon_label": taxon_label,
                "taxid": extract_taxid(taxon_label),
                "kraken_length": classification["kraken_length"],
                "lca_mapping": classification["lca_mapping"],
                "broad_taxon": classify_taxon(taxon_label, kraken_status),
            }
        )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        default="configs/blobtoolkit_self_mapping_manifest.tsv",
        help="TSV manifest with short_id, sample_id, trimmed_r1, trimmed_r2, and spades_contigs columns.",
    )
    parser.add_argument(
        "--stage-root",
        default="ambiguous_isolate_resolution/blobtoolkit",
        help="Root directory containing one BlobToolKit stage directory per short_id.",
    )
    parser.add_argument(
        "--combined-output",
        default="ambiguous_isolate_resolution/blobtoolkit/metrics/all_samples.master_contig_table.tsv",
        help="Combined master contig table path.",
    )
    parser.add_argument(
        "--per-sample-output-root",
        default=None,
        help=(
            "Optional output root for per-sample tables. Defaults to --stage-root, "
            "which writes each table under <stage-root>/<short_id>/metrics/."
        ),
    )
    args = parser.parse_args()

    project_dir = Path.cwd().resolve()
    manifest_path = resolve_path(project_dir, args.manifest)
    stage_root = resolve_path(project_dir, args.stage_root)
    per_sample_output_root = (
        resolve_path(project_dir, args.per_sample_output_root)
        if args.per_sample_output_root
        else stage_root
    )
    combined_output = resolve_path(project_dir, args.combined_output)

    require_file(manifest_path, "BlobToolKit self-mapping manifest")
    manifest_rows = read_manifest(manifest_path)

    combined_rows: list[dict[str, object]] = []
    for manifest_row in manifest_rows:
        short_id = manifest_row["short_id"]
        sample_rows = build_rows(project_dir, stage_root, manifest_row)
        per_sample_output = per_sample_output_root / short_id / "metrics" / f"{short_id}.master_contig_table.tsv"
        write_table(per_sample_output, sample_rows)
        combined_rows.extend(sample_rows)
        print(f"Wrote {len(sample_rows)} rows: {per_sample_output}")

    write_table(combined_output, combined_rows)
    print(f"Wrote {len(combined_rows)} combined rows: {combined_output}")


if __name__ == "__main__":
    main()
