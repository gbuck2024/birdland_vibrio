#!/usr/bin/env python3
"""Summarize saved SPAdes assemblies into a curated TSV table."""

from __future__ import annotations

import csv
import os
from pathlib import Path
from typing import Dict, List


PROJECT_DIR = Path(__file__).resolve().parent.parent
MANIFEST_PATH = PROJECT_DIR / os.environ.get(
    "MANIFEST_FILE", "configs/assembly_manifest.tsv"
)
STAGE_DIR = PROJECT_DIR / os.environ.get("STAGE_DIR", "assembly")
ASSEMBLIES_DIR = STAGE_DIR / "assemblies"
METRICS_DIR = STAGE_DIR / "metrics"
SUMMARY_PATH = Path(
    os.environ.get("SUMMARY_PATH", str(METRICS_DIR / "assembly_summary.tsv"))
)


def parse_fasta_stats(path: Path) -> Dict[str, object]:
    lengths: List[int] = []
    gc_count = 0
    total_bases = 0
    current_length = 0

    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            if line.startswith(">"):
                if current_length:
                    lengths.append(current_length)
                    current_length = 0
                continue

            sequence = line.upper()
            seq_len = len(sequence)
            current_length += seq_len
            total_bases += seq_len
            gc_count += sum(1 for base in sequence if base in {"G", "C"})

    if current_length:
        lengths.append(current_length)

    lengths.sort(reverse=True)

    n50 = 0
    cumulative = 0
    half = total_bases / 2
    for length in lengths:
        cumulative += length
        if cumulative >= half:
            n50 = length
            break

    return {
        "sequences": len(lengths),
        "total_bases": total_bases,
        "longest": lengths[0] if lengths else 0,
        "n50": n50,
        "gc_pct": round((gc_count / total_bases) * 100, 2) if total_bases else 0.0,
        "ge_1000bp": sum(1 for length in lengths if length >= 1000),
    }


def read_manifest(path: Path) -> List[Dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def main() -> int:
    if not MANIFEST_PATH.is_file():
        raise SystemExit(f"Assembly manifest not found: {MANIFEST_PATH}")

    rows = read_manifest(MANIFEST_PATH)
    if not rows:
        raise SystemExit("Assembly manifest contains no sample rows.")

    METRICS_DIR.mkdir(parents=True, exist_ok=True)

    fieldnames = [
        "sample_id",
        "read1",
        "read2",
        "assembly_dir",
        "contigs_sequences",
        "contigs_ge_1000bp",
        "contigs_total_bases",
        "contigs_n50",
        "contigs_longest",
        "contigs_gc_pct",
        "scaffolds_sequences",
        "scaffolds_ge_1000bp",
        "scaffolds_total_bases",
        "scaffolds_n50",
        "scaffolds_longest",
        "scaffolds_gc_pct",
    ]

    summary_rows: List[Dict[str, object]] = []
    for row in rows:
        sample_id = row["sample_id"]
        sample_dir = ASSEMBLIES_DIR / sample_id
        contigs_path = sample_dir / "contigs.fasta"
        scaffolds_path = sample_dir / "scaffolds.fasta"

        if not contigs_path.is_file():
            raise SystemExit(f"Missing contigs FASTA for {sample_id}: {contigs_path}")
        if not scaffolds_path.is_file():
            raise SystemExit(f"Missing scaffolds FASTA for {sample_id}: {scaffolds_path}")

        contig_stats = parse_fasta_stats(contigs_path)
        scaffold_stats = parse_fasta_stats(scaffolds_path)

        summary_rows.append(
            {
                "sample_id": sample_id,
                "read1": row["read1"],
                "read2": row["read2"],
                "assembly_dir": sample_dir.relative_to(PROJECT_DIR).as_posix(),
                "contigs_sequences": contig_stats["sequences"],
                "contigs_ge_1000bp": contig_stats["ge_1000bp"],
                "contigs_total_bases": contig_stats["total_bases"],
                "contigs_n50": contig_stats["n50"],
                "contigs_longest": contig_stats["longest"],
                "contigs_gc_pct": f"{contig_stats['gc_pct']:.2f}",
                "scaffolds_sequences": scaffold_stats["sequences"],
                "scaffolds_ge_1000bp": scaffold_stats["ge_1000bp"],
                "scaffolds_total_bases": scaffold_stats["total_bases"],
                "scaffolds_n50": scaffold_stats["n50"],
                "scaffolds_longest": scaffold_stats["longest"],
                "scaffolds_gc_pct": f"{scaffold_stats['gc_pct']:.2f}",
            }
        )

    with SUMMARY_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(summary_rows)

    print(f"Wrote assembly summary: {SUMMARY_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
