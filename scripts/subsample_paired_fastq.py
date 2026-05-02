#!/usr/bin/env python3
"""Subsample paired FASTQ reads to a target read-pair count."""

from __future__ import annotations

import argparse
import csv
import gzip
import random
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sample-id", required=True)
    parser.add_argument("--subsample-id", required=True)
    parser.add_argument("--target-coverage", required=True)
    parser.add_argument("--genome-size", required=True, type=int)
    parser.add_argument("--read-length", required=True, type=int)
    parser.add_argument("--target-read-pairs", required=True, type=int)
    parser.add_argument("--seed", required=True, type=int)
    parser.add_argument("--read1", required=True, type=Path)
    parser.add_argument("--read2", required=True, type=Path)
    parser.add_argument("--out-read1", required=True, type=Path)
    parser.add_argument("--out-read2", required=True, type=Path)
    parser.add_argument("--metrics-out", required=True, type=Path)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate inputs and planned outputs without scanning or writing FASTQ data.",
    )
    return parser.parse_args()


def require_file(path: Path, label: str) -> None:
    if not path.is_file():
        raise SystemExit(f"ERROR: {label} not found: {path}")
    if path.stat().st_size == 0:
        raise SystemExit(f"ERROR: {label} is empty: {path}")


def validate_fastq_suffix(path: Path, expected_suffix: str, label: str) -> None:
    if not path.name.endswith(expected_suffix):
        raise SystemExit(
            f"ERROR: {label} does not end with expected suffix {expected_suffix}: {path}"
        )


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


def validate_inputs(args: argparse.Namespace) -> None:
    require_file(args.read1, "Forward FASTQ")
    require_file(args.read2, "Reverse FASTQ")
    validate_fastq_suffix(args.read1, "_1_paired.fq.gz", "Forward FASTQ")
    validate_fastq_suffix(args.read2, "_2_paired.fq.gz", "Reverse FASTQ")
    validate_fastq_suffix(args.out_read1, "_1_paired.fq.gz", "Output forward FASTQ")
    validate_fastq_suffix(args.out_read2, "_2_paired.fq.gz", "Output reverse FASTQ")

    if args.target_read_pairs <= 0:
        raise SystemExit("ERROR: --target-read-pairs must be greater than zero.")
    if args.genome_size <= 0:
        raise SystemExit("ERROR: --genome-size must be greater than zero.")
    if args.read_length <= 0:
        raise SystemExit("ERROR: --read-length must be greater than zero.")

    read1_prefix = args.read1.name.removesuffix("_1_paired.fq.gz")
    read2_prefix = args.read2.name.removesuffix("_2_paired.fq.gz")
    out1_prefix = args.out_read1.name.removesuffix("_1_paired.fq.gz")
    out2_prefix = args.out_read2.name.removesuffix("_2_paired.fq.gz")

    if read1_prefix != read2_prefix:
        raise SystemExit(
            f"ERROR: Input read names are not a synchronized R1/R2 pair: {args.read1} {args.read2}"
        )
    if out1_prefix != out2_prefix:
        raise SystemExit(
            f"ERROR: Output read names are not a synchronized R1/R2 pair: {args.out_read1} {args.out_read2}"
        )
    if out1_prefix != args.subsample_id:
        raise SystemExit(
            "ERROR: Output FASTQ prefix must match --subsample-id: "
            f"{out1_prefix} != {args.subsample_id}"
        )


def count_and_validate_pairs(read1_path: Path, read2_path: Path) -> int:
    total_pairs = 0

    with gzip.open(read1_path, "rt", encoding="utf-8") as read1_handle, gzip.open(
        read2_path, "rt", encoding="utf-8"
    ) as read2_handle:
        while True:
            record1 = read_fastq_record(read1_handle)
            record2 = read_fastq_record(read2_handle)

            if record1 is None and record2 is None:
                break
            if record1 is None or record2 is None:
                raise SystemExit("ERROR: Input FASTQ files differ in record count.")

            read_id1 = normalize_fastq_header(record1[0])
            read_id2 = normalize_fastq_header(record2[0])
            if read_id1 != read_id2:
                raise SystemExit(
                    "ERROR: Paired FASTQ records are out of sync: "
                    f"{read_id1} != {read_id2}"
                )

            total_pairs += 1

    return total_pairs


def choose_pair_indexes(total_pairs: int, target_pairs: int, seed: int) -> set[int]:
    if target_pairs > total_pairs:
        raise SystemExit(
            "ERROR: Target read-pair count exceeds available paired reads: "
            f"{target_pairs} > {total_pairs}"
        )

    rng = random.Random(seed)
    return set(rng.sample(range(total_pairs), target_pairs))


def write_subsampled_fastqs(
    read1_path: Path,
    read2_path: Path,
    selected_indexes: set[int],
    output_read1_path: Path,
    output_read2_path: Path,
) -> int:
    output_read1_path.parent.mkdir(parents=True, exist_ok=True)
    output_read2_path.parent.mkdir(parents=True, exist_ok=True)

    written_pairs = 0
    pair_index = 0

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
                raise SystemExit("ERROR: Input FASTQ files differ in record count during write pass.")

            read_id1 = normalize_fastq_header(record1[0])
            read_id2 = normalize_fastq_header(record2[0])
            if read_id1 != read_id2:
                raise SystemExit(
                    "ERROR: Paired FASTQ records are out of sync during write pass: "
                    f"{read_id1} != {read_id2}"
                )

            if pair_index in selected_indexes:
                out1_handle.writelines(record1)
                out2_handle.writelines(record2)
                written_pairs += 1

            pair_index += 1

    return written_pairs


def write_metrics(args: argparse.Namespace, actual_read_pairs: str) -> None:
    args.metrics_out.parent.mkdir(parents=True, exist_ok=True)

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

    row = {
        "sample_id": args.sample_id,
        "subsample_id": args.subsample_id,
        "target_coverage": str(args.target_coverage),
        "genome_size_assumption": str(args.genome_size),
        "read_length_assumption": str(args.read_length),
        "target_read_pairs": str(args.target_read_pairs),
        "actual_read_pairs": str(actual_read_pairs),
        "seed": str(args.seed),
        "input_read1": args.read1.as_posix(),
        "input_read2": args.read2.as_posix(),
        "output_read1": args.out_read1.as_posix(),
        "output_read2": args.out_read2.as_posix(),
    }

    with args.metrics_out.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerow(row)


def main() -> int:
    args = parse_args()
    validate_inputs(args)

    if args.dry_run:
        print(
            "DRY RUN OK\t"
            f"sample_id={args.sample_id}\t"
            f"subsample_id={args.subsample_id}\t"
            f"target_coverage={args.target_coverage}\t"
            f"target_read_pairs={args.target_read_pairs}\t"
            f"seed={args.seed}"
        )
        return 0

    total_pairs = count_and_validate_pairs(args.read1, args.read2)
    selected_indexes = choose_pair_indexes(total_pairs, args.target_read_pairs, args.seed)
    actual_read_pairs = write_subsampled_fastqs(
        args.read1,
        args.read2,
        selected_indexes,
        args.out_read1,
        args.out_read2,
    )

    if actual_read_pairs != args.target_read_pairs:
        raise SystemExit(
            "ERROR: Wrote an unexpected number of read pairs: "
            f"{actual_read_pairs} != {args.target_read_pairs}"
        )

    write_metrics(args, str(actual_read_pairs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
