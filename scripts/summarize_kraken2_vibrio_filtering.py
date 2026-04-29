#!/usr/bin/env python3
"""Combine per-sample Kraken2 Vibrio filtering metrics into one TSV summary."""

from __future__ import annotations

import csv
import os
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parent.parent
MANIFEST_PATH = PROJECT_DIR / os.environ.get(
    "MANIFEST_FILE", "configs/kraken2_vibrio_filter_manifest.tsv"
)
STAGE_DIR = PROJECT_DIR / os.environ.get("STAGE_DIR", "kraken2_vibrio_read_filtering")
METRICS_DIR = STAGE_DIR / "metrics"
SUMMARY_PATH = METRICS_DIR / "kraken2_vibrio_filtering_summary.tsv"


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def main() -> int:
    if not MANIFEST_PATH.is_file():
        raise SystemExit(f"Filtering manifest not found: {MANIFEST_PATH}")

    samples = read_tsv(MANIFEST_PATH)
    if not samples:
        raise SystemExit(f"Filtering manifest contains no sample rows: {MANIFEST_PATH}")

    METRICS_DIR.mkdir(parents=True, exist_ok=True)

    summary_rows: list[dict[str, str]] = []
    for sample in samples:
        sample_id = sample["sample_id"]
        metrics_path = METRICS_DIR / f"{sample_id}.filtering_metrics.tsv"
        if not metrics_path.is_file():
            raise SystemExit(f"Missing per-sample filtering metrics: {metrics_path}")

        rows = read_tsv(metrics_path)
        if len(rows) != 1:
            raise SystemExit(f"Expected one metrics row in {metrics_path}, found {len(rows)}")

        summary_rows.append(rows[0])

    fieldnames = [
        "sample_id",
        "read1",
        "read2",
        "kraken_output",
        "kraken_report",
        "filtered_read1",
        "filtered_read2",
        "original_paired_reads",
        "retained_read_pairs",
        "retained_pct",
        "filtering_rule",
        "vibrio_genus_taxid",
        "vibrio_subtree_taxids_detected",
    ]

    with SUMMARY_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(summary_rows)

    print(f"Wrote filtering summary: {SUMMARY_PATH.relative_to(PROJECT_DIR)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
