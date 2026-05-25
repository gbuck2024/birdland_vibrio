#!/usr/bin/env python3
"""Reproducibly downsample paired FASTQ records without breaking pairing."""

from __future__ import annotations

import argparse
import gzip
import random
import sys
from pathlib import Path
from typing import Iterable, Iterator, TextIO, Tuple


def open_text(path: Path, mode: str = "rt") -> TextIO:
    if path.suffix == ".gz":
        return gzip.open(path, mode, encoding="utf-8")
    return path.open(mode, encoding="utf-8")


def normalize_read_id(header: str) -> str:
    value = header.strip()
    if value.startswith("@"):
        value = value[1:]
    value = value.split()[0]
    for suffix in ("/1", "/2"):
        if value.endswith(suffix):
            value = value[: -len(suffix)]
    return value


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
        yield header, sequence, plus, quality


def count_pairs(r1: Path, r2: Path) -> int:
    pairs = 0
    with open_text(r1) as r1_handle, open_text(r2) as r2_handle:
        r2_iter = iter_fastq(r2_handle, r2)
        for r1_record in iter_fastq(r1_handle, r1):
            try:
                r2_record = next(r2_iter)
            except StopIteration as exc:
                raise ValueError("R2 ended before R1 while counting pairs") from exc
            pairs += 1
            if normalize_read_id(r1_record[0]) != normalize_read_id(r2_record[0]):
                raise ValueError(f"Pair ID mismatch while counting at pair {pairs}")
        try:
            next(r2_iter)
        except StopIteration:
            return pairs
        raise ValueError("R2 has more records than R1")


def main(argv: Iterable[str] = sys.argv[1:]) -> int:
    parser = argparse.ArgumentParser(description="Downsample paired FASTQ files.")
    parser.add_argument("--r1", required=True, type=Path)
    parser.add_argument("--r2", required=True, type=Path)
    parser.add_argument("--out-r1", required=True, type=Path)
    parser.add_argument("--out-r2", required=True, type=Path)
    parser.add_argument("--pairs", required=True, type=int)
    parser.add_argument("--seed", default=20260105, type=int)
    args = parser.parse_args(list(argv))

    total_pairs = count_pairs(args.r1, args.r2)
    keep_count = min(args.pairs, total_pairs)
    rng = random.Random(args.seed)
    keep_indices = set(rng.sample(range(total_pairs), keep_count)) if keep_count else set()

    args.out_r1.parent.mkdir(parents=True, exist_ok=True)
    args.out_r2.parent.mkdir(parents=True, exist_ok=True)

    written = 0
    with open_text(args.r1) as r1_handle, open_text(args.r2) as r2_handle, open_text(
        args.out_r1, "wt"
    ) as out_r1_handle, open_text(args.out_r2, "wt") as out_r2_handle:
        r2_iter = iter_fastq(r2_handle, args.r2)
        for index, r1_record in enumerate(iter_fastq(r1_handle, args.r1)):
            r2_record = next(r2_iter)
            if normalize_read_id(r1_record[0]) != normalize_read_id(r2_record[0]):
                raise SystemExit(f"ERROR: Pair ID mismatch at pair {index + 1}")
            if index in keep_indices:
                out_r1_handle.write("".join(r1_record))
                out_r2_handle.write("".join(r2_record))
                written += 1

    print(f"Wrote {written} of {total_pairs} pairs with seed {args.seed}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
