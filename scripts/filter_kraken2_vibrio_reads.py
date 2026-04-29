#!/usr/bin/env python3
"""Retain paired reads classified by Kraken2 as Vibrio genus or below."""

from __future__ import annotations

import argparse
import csv
import gzip
import re
from pathlib import Path


TAXID_PATTERN = re.compile(r"\(taxid\s+(\d+)\)$")
FILTERING_RULE_TEMPLATE = (
    "retain paired fragments whose Kraken2 assigned taxid is Vibrio genus "
    "(taxid {taxid}) or a descendant taxid under that genus in the sample "
    "Kraken2 report; exclude unclassified and above-genus assignments"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__,
    )
    parser.add_argument("--sample-id", required=True)
    parser.add_argument("--read1", required=True, type=Path)
    parser.add_argument("--read2", required=True, type=Path)
    parser.add_argument("--kraken-output", required=True, type=Path)
    parser.add_argument("--kraken-report", required=True, type=Path)
    parser.add_argument("--out-read1", required=True, type=Path)
    parser.add_argument("--out-read2", required=True, type=Path)
    parser.add_argument("--metrics-out", required=True, type=Path)
    parser.add_argument("--vibrio-genus-taxid", default="662")
    return parser.parse_args()


def require_file(path: Path, label: str) -> None:
    if not path.is_file():
        raise SystemExit(f"ERROR: {label} not found: {path}")
    if path.stat().st_size == 0:
        raise SystemExit(f"ERROR: {label} is empty: {path}")


def normalize_fastq_header(header_line: str) -> str:
    if not header_line.startswith("@"):
        raise SystemExit(f"ERROR: FASTQ header does not start with '@': {header_line.rstrip()}")

    token = header_line[1:].strip().split()[0]
    if token.endswith("/1") or token.endswith("/2"):
        token = token[:-2]
    return token


def read_fastq_record(handle) -> list[str] | None:
    header = handle.readline()
    if not header:
        return None

    sequence = handle.readline()
    plus = handle.readline()
    quality = handle.readline()

    if not sequence or not plus or not quality:
        raise SystemExit("ERROR: Encountered truncated FASTQ record.")

    return [header, sequence, plus, quality]


def collect_vibrio_taxids(report_path: Path, vibrio_taxid: str) -> set[str]:
    retain_taxids: set[str] = set()
    in_vibrio_subtree = False
    vibrio_indent = -1

    with report_path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\n")
            if not line:
                continue

            fields = line.split("\t")
            if len(fields) < 6:
                raise SystemExit(f"ERROR: Malformed Kraken2 report line in {report_path}: {line}")

            rank_code = fields[3].strip()
            taxid = fields[4].strip()
            name_field = fields[5]
            indent = len(name_field) - len(name_field.lstrip(" "))

            if not in_vibrio_subtree:
                if taxid == vibrio_taxid and rank_code.startswith("G"):
                    in_vibrio_subtree = True
                    vibrio_indent = indent
                    retain_taxids.add(taxid)
                continue

            if indent <= vibrio_indent:
                break

            retain_taxids.add(taxid)

    if not retain_taxids:
        raise SystemExit(
            f"ERROR: Could not find Vibrio genus taxid {vibrio_taxid} in report {report_path}"
        )

    return retain_taxids


def collect_retained_read_ids(kraken_output_path: Path, retain_taxids: set[str]) -> set[str]:
    retained_ids: set[str] = set()

    with kraken_output_path.open("r", encoding="utf-8") as handle:
        for line_number, raw_line in enumerate(handle, start=1):
            line = raw_line.rstrip("\n")
            if not line:
                continue

            fields = line.split("\t")
            if len(fields) < 3:
                raise SystemExit(
                    f"ERROR: Malformed Kraken2 output line {line_number} in {kraken_output_path}: {line}"
                )

            status = fields[0].strip()
            read_id = fields[1].strip()
            assignment = fields[2].strip()

            if status != "C":
                continue

            match = TAXID_PATTERN.search(assignment)
            if match is None:
                raise SystemExit(
                    f"ERROR: Could not parse taxid from Kraken2 assignment on line {line_number}: {assignment}"
                )

            if match.group(1) in retain_taxids:
                retained_ids.add(read_id)

    return retained_ids


def filter_paired_fastq(
    read1_path: Path,
    read2_path: Path,
    retained_ids: set[str],
    output_read1_path: Path,
    output_read2_path: Path,
) -> tuple[int, int]:
    output_read1_path.parent.mkdir(parents=True, exist_ok=True)
    output_read2_path.parent.mkdir(parents=True, exist_ok=True)

    original_pairs = 0
    retained_pairs = 0
    observed_retained_ids: set[str] = set()

    with gzip.open(read1_path, "rt", encoding="utf-8") as read1_handle, gzip.open(
        read2_path, "rt", encoding="utf-8"
    ) as read2_handle, gzip.open(output_read1_path, "wt", encoding="utf-8") as out1_handle, gzip.open(
        output_read2_path, "wt", encoding="utf-8"
    ) as out2_handle:
        while True:
            record1 = read_fastq_record(read1_handle)
            record2 = read_fastq_record(read2_handle)

            if record1 is None and record2 is None:
                break
            if record1 is None or record2 is None:
                raise SystemExit("ERROR: Read1/read2 FASTQ lengths differ.")

            original_pairs += 1

            read_id1 = normalize_fastq_header(record1[0])
            read_id2 = normalize_fastq_header(record2[0])
            if read_id1 != read_id2:
                raise SystemExit(
                    "ERROR: Paired FASTQ records are out of sync: "
                    f"{read_id1} != {read_id2}"
                )

            if read_id1 in retained_ids:
                out1_handle.writelines(record1)
                out2_handle.writelines(record2)
                retained_pairs += 1
                observed_retained_ids.add(read_id1)

    missing_ids = retained_ids - observed_retained_ids
    if missing_ids:
        preview = ", ".join(sorted(list(missing_ids))[:5])
        raise SystemExit(
            "ERROR: Kraken2 retained read ids were not found in the paired FASTQ inputs. "
            f"Examples: {preview}"
        )

    return original_pairs, retained_pairs


def write_metrics(
    metrics_path: Path,
    sample_id: str,
    read1_path: Path,
    read2_path: Path,
    kraken_output_path: Path,
    kraken_report_path: Path,
    output_read1_path: Path,
    output_read2_path: Path,
    original_pairs: int,
    retained_pairs: int,
    filtering_rule: str,
    vibrio_genus_taxid: str,
    retain_taxids: set[str],
) -> None:
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    retained_pct = (retained_pairs / original_pairs * 100.0) if original_pairs else 0.0

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

    row = {
        "sample_id": sample_id,
        "read1": read1_path.as_posix(),
        "read2": read2_path.as_posix(),
        "kraken_output": kraken_output_path.as_posix(),
        "kraken_report": kraken_report_path.as_posix(),
        "filtered_read1": output_read1_path.as_posix(),
        "filtered_read2": output_read2_path.as_posix(),
        "original_paired_reads": str(original_pairs),
        "retained_read_pairs": str(retained_pairs),
        "retained_pct": f"{retained_pct:.2f}",
        "filtering_rule": filtering_rule,
        "vibrio_genus_taxid": vibrio_genus_taxid,
        "vibrio_subtree_taxids_detected": str(len(retain_taxids)),
    }

    with metrics_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerow(row)


def main() -> int:
    args = parse_args()

    require_file(args.read1, "Forward trimmed reads")
    require_file(args.read2, "Reverse trimmed reads")
    require_file(args.kraken_output, "Kraken2 output")
    require_file(args.kraken_report, "Kraken2 report")

    filtering_rule = FILTERING_RULE_TEMPLATE.format(taxid=args.vibrio_genus_taxid)
    retain_taxids = collect_vibrio_taxids(args.kraken_report, args.vibrio_genus_taxid)
    retained_ids = collect_retained_read_ids(args.kraken_output, retain_taxids)
    original_pairs, retained_pairs = filter_paired_fastq(
        read1_path=args.read1,
        read2_path=args.read2,
        retained_ids=retained_ids,
        output_read1_path=args.out_read1,
        output_read2_path=args.out_read2,
    )

    write_metrics(
        metrics_path=args.metrics_out,
        sample_id=args.sample_id,
        read1_path=args.read1,
        read2_path=args.read2,
        kraken_output_path=args.kraken_output,
        kraken_report_path=args.kraken_report,
        output_read1_path=args.out_read1,
        output_read2_path=args.out_read2,
        original_pairs=original_pairs,
        retained_pairs=retained_pairs,
        filtering_rule=filtering_rule,
        vibrio_genus_taxid=args.vibrio_genus_taxid,
        retain_taxids=retain_taxids,
    )

    print(
        f"{args.sample_id}: retained {retained_pairs} of {original_pairs} paired reads "
        f"({(retained_pairs / original_pairs * 100.0) if original_pairs else 0.0:.2f}%)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
