#!/usr/bin/env python3
"""Combine per-run subsampling metrics into one summary table."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        default="configs/kraken2_vibrio_subsample_manifest.tsv",
        type=Path,
    )
    parser.add_argument(
        "--summary-out",
        default="kraken2_vibrio_subsampled_reads/metrics/subsampling_summary.tsv",
        type=Path,
    )
    return parser.parse_args()


def require_file(path: Path, label: str) -> None:
    if not path.is_file():
        raise SystemExit(f"ERROR: {label} not found: {path}")
    if path.stat().st_size == 0:
        raise SystemExit(f"ERROR: {label} is empty: {path}")


def read_manifest_rows(manifest_path: Path) -> list[dict[str, str]]:
    require_file(manifest_path, "Subsampling manifest")
    with manifest_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)
    if not rows:
        raise SystemExit(f"ERROR: Manifest contains no sample rows: {manifest_path}")
    return rows


def read_metrics_row(metrics_path: Path) -> dict[str, str]:
    require_file(metrics_path, "Subsampling metrics file")
    with metrics_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)
    if len(rows) != 1:
        raise SystemExit(f"ERROR: Expected exactly one row in metrics file: {metrics_path}")
    return rows[0]


def main() -> int:
    args = parse_args()
    manifest_rows = read_manifest_rows(args.manifest)

    summary_rows: list[dict[str, str]] = []
    for manifest_row in manifest_rows:
        metrics_path = Path(manifest_row["metrics_out"])
        summary_rows.append(read_metrics_row(metrics_path))

    fieldnames = [
        "sample_id",
        "subsample_id",
        "target_coverage",
        "genome_size_assumption",
        "read_length_assumption",
        "target_read_pairs",
        "actual_read_pairs",
        "seed",
        "input_read1",
        "input_read2",
        "output_read1",
        "output_read2",
    ]

    args.summary_out.parent.mkdir(parents=True, exist_ok=True)
    with args.summary_out.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(summary_rows)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
