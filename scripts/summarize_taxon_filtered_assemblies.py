#!/usr/bin/env python3
"""Summarize taxon-filtered SPAdes assemblies for ambiguous isolates."""

from __future__ import annotations

import csv
import os
from pathlib import Path
from typing import Dict, List


PROJECT_DIR = Path(__file__).resolve().parent.parent
MANIFEST_PATH = PROJECT_DIR / os.environ.get(
    "MANIFEST_FILE", "configs/taxon_filter_manifest.tsv"
)
STAGE_DIR = PROJECT_DIR / "ambiguous_isolate_resolution/taxonomic_filtering"
ASSEMBLIES_DIR = STAGE_DIR / "assemblies"
METRICS_DIR = STAGE_DIR / "metrics"
SUMMARY_PATH = METRICS_DIR / "taxon_filtered_assembly_summary.tsv"

ORIGINAL_CONTIG_COUNTS = {
    "Buck_BI0607_1": 84400,
    "Buck_BI0607_2": 49312,
    "Buck_NB0507_14": 72565,
}


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
            current_length += len(sequence)
            total_bases += len(sequence)
            gc_count += sum(1 for base in sequence if base in {"G", "C"})

    if current_length:
        lengths.append(current_length)

    lengths.sort(reverse=True)
    half = total_bases / 2
    cumulative = 0
    n50 = 0
    for length in lengths:
        cumulative += length
        if cumulative >= half:
            n50 = length
            break

    return {
        "total_length": total_bases,
        "contig_count": len(lengths),
        "n50": n50,
        "largest_contig": lengths[0] if lengths else 0,
        "gc_percent": round((gc_count / total_bases) * 100, 2) if total_bases else 0.0,
    }


def choose_assembly_fasta(sample_dir: Path) -> Path:
    scaffolds = sample_dir / "scaffolds.fasta"
    contigs = sample_dir / "contigs.fasta"
    if scaffolds.is_file() and scaffolds.stat().st_size > 0:
        return scaffolds
    if contigs.is_file() and contigs.stat().st_size > 0:
        return contigs
    raise FileNotFoundError(f"No scaffolds.fasta or contigs.fasta found in {sample_dir}")


def interpret(sample_id: str, total_length: int, contig_count: int) -> str:
    original_count = ORIGINAL_CONTIG_COUNTS.get(sample_id)
    substantially_lower = original_count is not None and contig_count < (original_count * 0.5)
    if 4_000_000 <= total_length <= 6_500_000 and substantially_lower:
        return "taxon-filtered assembly is near expected bacterial genome size"
    if total_length > 10_000_000 or (
        original_count is not None and contig_count > (original_count * 0.5)
    ):
        return "taxon-filtered assembly remains inflated/fragmented; mixed sample or contamination still likely"
    if total_length < 1_000_000:
        return "too few reads retained or incomplete target recovery"
    return "intermediate result; review taxonomic composition and assembly quality"


def main() -> int:
    if not MANIFEST_PATH.is_file():
        raise SystemExit(f"Manifest not found: {MANIFEST_PATH}")

    with MANIFEST_PATH.open("r", encoding="utf-8", newline="") as handle:
        manifest_rows = list(csv.DictReader(handle, delimiter="\t"))

    if not manifest_rows:
        raise SystemExit("Manifest contains no rows.")

    METRICS_DIR.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "sample_id",
        "target_taxon_name",
        "target_taxid",
        "assembly_fasta",
        "total_length",
        "contig_count",
        "n50",
        "largest_contig",
        "gc_percent",
        "interpretation",
    ]

    summary_rows: List[Dict[str, object]] = []
    for row in manifest_rows:
        sample_id = row["sample_id"]
        target_name = row["target_taxon_name"]
        sample_dir = ASSEMBLIES_DIR / f"{sample_id}_{target_name}"
        try:
            assembly_fasta = choose_assembly_fasta(sample_dir)
        except FileNotFoundError as exc:
            raise SystemExit(str(exc)) from exc

        stats = parse_fasta_stats(assembly_fasta)
        summary_rows.append(
            {
                "sample_id": sample_id,
                "target_taxon_name": target_name,
                "target_taxid": row["target_taxid"],
                "assembly_fasta": assembly_fasta.relative_to(PROJECT_DIR).as_posix(),
                "total_length": stats["total_length"],
                "contig_count": stats["contig_count"],
                "n50": stats["n50"],
                "largest_contig": stats["largest_contig"],
                "gc_percent": f"{stats['gc_percent']:.2f}",
                "interpretation": interpret(
                    sample_id, int(stats["total_length"]), int(stats["contig_count"])
                ),
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
