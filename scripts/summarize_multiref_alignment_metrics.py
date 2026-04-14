#!/usr/bin/env python3
"""Summarize multi-reference alignment metrics into long and matrix TSV tables."""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
SAMPLE_MANIFEST = PROJECT_DIR / "configs" / "alignment_manifest.tsv"
REFERENCE_MANIFEST = PROJECT_DIR / "configs" / "multi_reference_reference_manifest.tsv"
METRICS_DIR = PROJECT_DIR / "multi_reference_alignment" / "metrics"
SUMMARY_TSV = METRICS_DIR / "multi_reference_alignment_summary.tsv"
MAPPED_PCT_MATRIX_TSV = METRICS_DIR / "multi_reference_alignment_mapped_pct_matrix.tsv"

FLAGSTAT_PATTERNS = {
    "total_reads": re.compile(r"^(\d+) \+ \d+ in total "),
    "mapped": re.compile(r"^(\d+) \+ \d+ mapped \(([^)]+)\)"),
    "properly_paired": re.compile(r"^(\d+) \+ \d+ properly paired \(([^)]+)\)"),
    "secondary": re.compile(r"^(\d+) \+ \d+ secondary$"),
    "supplementary": re.compile(r"^(\d+) \+ \d+ supplementary$"),
    "singletons": re.compile(r"^(\d+) \+ \d+ singletons \(([^)]+)\)"),
    "mate_diff_chr": re.compile(r"^(\d+) \+ \d+ with mate mapped to a different chr$"),
}


def load_tsv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise SystemExit(f"ERROR: Required TSV not found: {path}")

    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)

    if not rows:
        raise SystemExit(f"ERROR: TSV contains no data rows: {path}")

    return rows


def parse_flagstat(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}

    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            for key, pattern in FLAGSTAT_PATTERNS.items():
                match = pattern.match(line)
                if not match:
                    continue

                values[key] = match.group(1)
                if key in {"mapped", "properly_paired", "singletons"}:
                    values[f"{key}_pct"] = match.group(2).replace("%", "").strip()
                break

    required_keys = {
        "total_reads",
        "mapped",
        "mapped_pct",
        "properly_paired",
        "properly_paired_pct",
        "secondary",
        "supplementary",
        "singletons",
        "singletons_pct",
        "mate_diff_chr",
    }
    missing = sorted(required_keys - set(values))
    if missing:
        raise SystemExit(f"ERROR: Missing expected flagstat fields in {path}: {', '.join(missing)}")

    return values


def parse_idxstats(path: Path) -> dict[str, str]:
    mapped_sum = 0
    unmapped_sum = 0
    contigs_with_mapped_reads = 0
    top_contig = "NA"
    top_contig_mapped_reads = -1

    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            contig, _length, mapped_reads, unmapped_reads = line.rstrip("\n").split("\t")
            mapped_value = int(mapped_reads)
            unmapped_value = int(unmapped_reads)
            mapped_sum += mapped_value
            unmapped_sum += unmapped_value

            if contig != "*" and mapped_value > 0:
                contigs_with_mapped_reads += 1

            if contig != "*" and mapped_value > top_contig_mapped_reads:
                top_contig = contig
                top_contig_mapped_reads = mapped_value

    return {
        "idx_mapped_sum": str(mapped_sum),
        "idx_unmapped_sum": str(unmapped_sum),
        "contigs_with_mapped_reads": str(contigs_with_mapped_reads),
        "top_mapped_contig": top_contig if top_contig_mapped_reads >= 0 else "NA",
        "top_mapped_contig_reads": str(max(top_contig_mapped_reads, 0)),
    }


def reference_stats(reference_fasta: Path) -> tuple[int, int]:
    fai_path = reference_fasta.with_suffix(reference_fasta.suffix + ".fai")
    if not fai_path.is_file():
        raise SystemExit(f"ERROR: Reference FASTA index not found: {fai_path}")

    contig_count = 0
    total_bases = 0
    with fai_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            contig_count += 1
            total_bases += int(fields[1])

    if contig_count == 0:
        raise SystemExit(f"ERROR: Reference FASTA index contains no contigs: {fai_path}")

    return contig_count, total_bases


def main() -> int:
    samples = load_tsv(SAMPLE_MANIFEST)
    references = load_tsv(REFERENCE_MANIFEST)
    METRICS_DIR.mkdir(parents=True, exist_ok=True)

    missing_files: list[str] = []
    summary_rows: list[dict[str, str]] = []

    for sample in samples:
        sample_id = sample["sample_id"]
        read1 = sample["read1"]
        read2 = sample["read2"]

        for reference in references:
            reference_id = reference["reference_id"]
            reference_fasta = reference["reference_fasta"]
            reference_format = reference["reference_format"]
            reference_notes = reference["notes"]

            flagstat_path = METRICS_DIR / f"{sample_id}__{reference_id}.flagstat.txt"
            idxstats_path = METRICS_DIR / f"{sample_id}__{reference_id}.idxstats.txt"

            if not flagstat_path.is_file():
                missing_files.append(str(flagstat_path.relative_to(PROJECT_DIR)))
                continue
            if not idxstats_path.is_file():
                missing_files.append(str(idxstats_path.relative_to(PROJECT_DIR)))
                continue

            flagstat = parse_flagstat(flagstat_path)
            idxstats = parse_idxstats(idxstats_path)
            contig_count, total_bases = reference_stats(PROJECT_DIR / reference_fasta)

            summary_rows.append(
                {
                    "sample_id": sample_id,
                    "reference_id": reference_id,
                    "reference_fasta": reference_fasta,
                    "reference_format": reference_format,
                    "reference_notes": reference_notes,
                    "reference_contigs": str(contig_count),
                    "reference_total_bases": str(total_bases),
                    "read1": read1,
                    "read2": read2,
                    "total_reads": flagstat["total_reads"],
                    "mapped_reads": flagstat["mapped"],
                    "mapped_pct": flagstat["mapped_pct"],
                    "properly_paired": flagstat["properly_paired"],
                    "properly_paired_pct": flagstat["properly_paired_pct"],
                    "secondary": flagstat["secondary"],
                    "supplementary": flagstat["supplementary"],
                    "singletons": flagstat["singletons"],
                    "singletons_pct": flagstat["singletons_pct"],
                    "mate_diff_chr": flagstat["mate_diff_chr"],
                    "idx_mapped_sum": idxstats["idx_mapped_sum"],
                    "idx_unmapped_sum": idxstats["idx_unmapped_sum"],
                    "contigs_with_mapped_reads": idxstats["contigs_with_mapped_reads"],
                    "top_mapped_contig": idxstats["top_mapped_contig"],
                    "top_mapped_contig_reads": idxstats["top_mapped_contig_reads"],
                }
            )

    if missing_files:
        joined = "\n".join(f"- {path}" for path in sorted(missing_files))
        raise SystemExit(
            "ERROR: Missing expected metric files. Run the multi-reference alignment jobs first or finish incomplete tasks:\n"
            f"{joined}"
        )

    summary_rows.sort(key=lambda row: (row["sample_id"], row["reference_id"]))

    summary_fieldnames = [
        "sample_id",
        "reference_id",
        "reference_fasta",
        "reference_format",
        "reference_notes",
        "reference_contigs",
        "reference_total_bases",
        "read1",
        "read2",
        "total_reads",
        "mapped_reads",
        "mapped_pct",
        "properly_paired",
        "properly_paired_pct",
        "secondary",
        "supplementary",
        "singletons",
        "singletons_pct",
        "mate_diff_chr",
        "idx_mapped_sum",
        "idx_unmapped_sum",
        "contigs_with_mapped_reads",
        "top_mapped_contig",
        "top_mapped_contig_reads",
    ]

    with SUMMARY_TSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=summary_fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(summary_rows)

    reference_ids = [reference["reference_id"] for reference in references]
    sample_ids = [sample["sample_id"] for sample in samples]
    mapped_pct_lookup = {
        (row["sample_id"], row["reference_id"]): row["mapped_pct"]
        for row in summary_rows
    }

    with MAPPED_PCT_MATRIX_TSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["sample_id", *reference_ids])
        for sample_id in sample_ids:
            writer.writerow([sample_id, *[mapped_pct_lookup[(sample_id, reference_id)] for reference_id in reference_ids]])

    print(f"Wrote summary table: {SUMMARY_TSV.relative_to(PROJECT_DIR)}")
    print(f"Wrote mapped percentage matrix: {MAPPED_PCT_MATRIX_TSV.relative_to(PROJECT_DIR)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
