#!/usr/bin/env python3
"""Filter paired FASTQ records using Kraken2 target-taxon evidence."""

from __future__ import annotations

import argparse
import csv
import gzip
import re
import sys
from pathlib import Path
from typing import Iterable, Iterator, TextIO, Tuple


TAXID_RE = re.compile(r"\(taxid\s+(\d+)\)")


def open_text(path: Path, mode: str = "rt") -> TextIO:
    if path.suffix == ".gz":
        return gzip.open(path, mode, encoding="utf-8")
    return path.open(mode, encoding="utf-8")


def normalize_read_id(header_or_id: str) -> str:
    """Return the stable read-pair ID shared by Kraken and paired FASTQs."""
    value = header_or_id.strip()
    if value.startswith("@"):
        value = value[1:]
    value = value.split()[0]
    for suffix in ("/1", "/2"):
        if value.endswith(suffix):
            value = value[: -len(suffix)]
    return value


def kraken_row_matches(fields: list[str], target_taxid: str) -> bool:
    """Match exact assigned taxid or target taxid in the k-mer string."""
    if len(fields) < 5:
        return False

    label = fields[2]
    kmer_taxids = fields[4]

    match = TAXID_RE.search(label)
    if match and match.group(1) == target_taxid:
        return True

    # Kraken2 k-mer field has tokens like 662:71. Match whole taxid tokens only.
    return re.search(rf"(^|[\s|]){re.escape(target_taxid)}:", kmer_taxids) is not None


def read_target_ids(kraken_output: Path, target_taxid: str) -> Tuple[set[str], int, int]:
    target_ids: set[str] = set()
    total_rows = 0
    malformed_rows = 0

    with kraken_output.open("r", encoding="utf-8") as handle:
        for line_number, raw_line in enumerate(handle, start=1):
            line = raw_line.rstrip("\n")
            if not line:
                continue
            total_rows += 1
            fields = line.split("\t")
            if len(fields) < 5:
                malformed_rows += 1
                continue
            if kraken_row_matches(fields, target_taxid):
                target_ids.add(normalize_read_id(fields[1]))

    return target_ids, total_rows, malformed_rows


def iter_fastq(handle: TextIO, path: Path) -> Iterator[Tuple[str, str, str, str]]:
    while True:
        header = handle.readline()
        if not header:
            return
        sequence = handle.readline()
        plus = handle.readline()
        quality = handle.readline()
        if not sequence or not plus or not quality:
            raise ValueError(f"Incomplete FASTQ record in {path}")
        if not header.startswith("@") or not plus.startswith("+"):
            raise ValueError(f"Malformed FASTQ record starting at header: {header.strip()}")
        yield header, sequence, plus, quality


def write_record(handle: TextIO, record: Tuple[str, str, str, str]) -> None:
    handle.write("".join(record))


def filter_fastqs(args: argparse.Namespace, target_ids: set[str]) -> Tuple[int, int]:
    total_pairs = 0
    kept_pairs = 0

    with open_text(args.r1) as r1_handle, open_text(args.r2) as r2_handle, open_text(
        args.out_r1, "wt"
    ) as out_r1_handle, open_text(args.out_r2, "wt") as out_r2_handle, args.read_id_out.open(
        "w", encoding="utf-8"
    ) as id_handle:
        r1_iter = iter_fastq(r1_handle, args.r1)
        r2_iter = iter_fastq(r2_handle, args.r2)

        for r1_record in r1_iter:
            try:
                r2_record = next(r2_iter)
            except StopIteration as exc:
                raise ValueError(f"R2 ended before R1 in pair {total_pairs + 1}") from exc

            total_pairs += 1
            r1_id = normalize_read_id(r1_record[0])
            r2_id = normalize_read_id(r2_record[0])
            if r1_id != r2_id:
                raise ValueError(
                    f"Pair ID mismatch at pair {total_pairs}: R1={r1_id}, R2={r2_id}"
                )

            if r1_id in target_ids or r2_id in target_ids:
                write_record(out_r1_handle, r1_record)
                write_record(out_r2_handle, r2_record)
                id_handle.write(f"{r1_id}\n")
                kept_pairs += 1

        try:
            extra_r2 = next(r2_iter)
        except StopIteration:
            extra_r2 = None
        if extra_r2 is not None:
            raise ValueError(f"R2 has extra records after R1 ended: {extra_r2[0].strip()}")

    return total_pairs, kept_pairs


def write_summary(
    args: argparse.Namespace,
    total_pairs: int,
    kept_pairs: int,
    kraken_rows: int,
    malformed_rows: int,
    target_id_count: int,
) -> None:
    notes = [
        "matched_exact_label_taxid_or_kmer_taxid",
        "include_descendants_conservative_via_observed_kmer_target_taxid",
    ]
    if args.include_descendants:
        notes.append("include_descendants_requested")
    if malformed_rows:
        notes.append(f"malformed_kraken_rows_skipped={malformed_rows}")
    notes.append(f"kraken_rows_seen={kraken_rows}")
    notes.append(f"target_ids_observed={target_id_count}")

    args.summary_out.parent.mkdir(parents=True, exist_ok=True)
    with args.summary_out.open("w", encoding="utf-8", newline="") as handle:
        fieldnames = [
            "sample_id",
            "target_taxid",
            "total_pairs_seen",
            "pairs_kept",
            "percent_pairs_kept",
            "read_ids_written",
            "notes",
        ]
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerow(
            {
                "sample_id": args.sample_id or "",
                "target_taxid": args.target_taxid,
                "total_pairs_seen": total_pairs,
                "pairs_kept": kept_pairs,
                "percent_pairs_kept": f"{(kept_pairs / total_pairs * 100):.4f}"
                if total_pairs
                else "0.0000",
                "read_ids_written": kept_pairs,
                "notes": ";".join(notes),
            }
        )


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Keep paired FASTQ reads with Kraken2 target-taxon evidence."
    )
    parser.add_argument("--r1", required=True, type=Path)
    parser.add_argument("--r2", required=True, type=Path)
    parser.add_argument("--kraken-output", required=True, type=Path)
    parser.add_argument("--target-taxid", required=True)
    parser.add_argument("--out-r1", required=True, type=Path)
    parser.add_argument("--out-r2", required=True, type=Path)
    parser.add_argument("--read-id-out", required=True, type=Path)
    parser.add_argument("--summary-out", required=True, type=Path)
    parser.add_argument("--sample-id", default="")
    parser.add_argument(
        "--include-descendants",
        action="store_true",
        help=(
            "Conservative mode: descendants are included only when the assigned "
            "read also carries the target taxid in Kraken2's observed k-mer field."
        ),
    )
    return parser.parse_args(list(argv))


def main(argv: Iterable[str] = sys.argv[1:]) -> int:
    args = parse_args(argv)

    for label, path in (("R1 FASTQ", args.r1), ("R2 FASTQ", args.r2), ("Kraken output", args.kraken_output)):
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"ERROR: {label} missing or empty: {path}")

    args.out_r1.parent.mkdir(parents=True, exist_ok=True)
    args.out_r2.parent.mkdir(parents=True, exist_ok=True)
    args.read_id_out.parent.mkdir(parents=True, exist_ok=True)

    target_ids, kraken_rows, malformed_rows = read_target_ids(
        args.kraken_output, args.target_taxid
    )
    if not target_ids:
        raise SystemExit(
            f"ERROR: No reads matched target taxid {args.target_taxid} in {args.kraken_output}"
        )

    try:
        total_pairs, kept_pairs = filter_fastqs(args, target_ids)
    except ValueError as exc:
        raise SystemExit(f"ERROR: {exc}") from exc

    write_summary(
        args,
        total_pairs,
        kept_pairs,
        kraken_rows,
        malformed_rows,
        len(target_ids),
    )
    print(
        f"Kept {kept_pairs} of {total_pairs} pairs "
        f"({(kept_pairs / total_pairs * 100) if total_pairs else 0:.4f}%)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
