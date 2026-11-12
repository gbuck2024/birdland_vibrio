#!/usr/bin/env python3
"""Count sequenced bases and validate both mates of each poster depth subset."""
from __future__ import annotations

import argparse
import csv
import gzip
from pathlib import Path


def record(handle, path: Path):
    header = handle.readline()
    if not header:
        return None
    seq, plus, quality = handle.readline(), handle.readline(), handle.readline()
    if not seq or not plus or not quality:
        raise ValueError(f"Truncated FASTQ record in {path}")
    if not header.startswith("@") or not plus.startswith("+") or len(seq.rstrip("\r\n")) != len(quality.rstrip("\r\n")):
        raise ValueError(f"Malformed FASTQ record in {path}: {header.strip()}")
    name = header[1:].split()[0].removesuffix("/1").removesuffix("/2")
    return name, len(seq.rstrip("\r\n"))


def count_pair(r1: Path, r2: Path) -> tuple[int, int, int]:
    count = bases1 = bases2 = 0
    with gzip.open(r1, "rt", encoding="ascii") as h1, gzip.open(r2, "rt", encoding="ascii") as h2:
        while True:
            a, b = record(h1, r1), record(h2, r2)
            if a is None and b is None:
                break
            if a is None or b is None or a[0] != b[0]:
                raise ValueError(f"Paired FASTQs differ in count or read order: {r1}, {r2}")
            count += 1
            bases1 += a[1]
            bases2 += b[1]
    return count, bases1, bases2


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error(f"Refusing to replace output: {args.output}")
    with args.manifest.open(newline="") as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    required = {"sample_id", "subsample_id", "target_coverage", "genome_size_assumption", "target_read_pairs", "out_read1", "out_read2", "metrics_out"}
    if not rows or not required.issubset(rows[0]) or len({r["subsample_id"] for r in rows}) != len(rows):
        parser.error("Manifest is empty, malformed, or has duplicate subsample IDs")
    result = []
    for row in rows:
        r1, r2 = Path(row["out_read1"]), Path(row["out_read2"])
        metrics = Path(row["metrics_out"])
        for path in (r1, r2, metrics):
            if not path.is_file() or path.stat().st_size == 0:
                raise ValueError(f"Missing or empty input: {path}")
        with metrics.open(newline="") as stream:
            metric_rows = list(csv.DictReader(stream, delimiter="\t"))
        if len(metric_rows) != 1 or metric_rows[0]["subsample_id"] != row["subsample_id"]:
            raise ValueError(f"Subsampling metric identity mismatch: {metrics}")
        count, bases1, bases2 = count_pair(r1, r2)
        expected = int(row["target_read_pairs"])
        if count != expected or count != int(metric_rows[0]["actual_read_pairs"]):
            raise ValueError(f"Read-pair count mismatch for {row['subsample_id']}: {count} vs {expected}")
        assumed_genome = int(row["genome_size_assumption"])
        if assumed_genome <= 0:
            raise ValueError("genome_size_assumption must be positive")
        result.append((row["sample_id"], row["subsample_id"], row["target_coverage"], count,
                       bases1, bases2, bases1 + bases2, assumed_genome,
                       f"{(bases1 + bases2) / assumed_genome:.4f}", str(r1), str(r2)))
    with args.output.open("x", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(("sample_id", "subsample_id", "target_coverage", "read_pairs", "r1_bases", "r2_bases", "total_sequenced_bases", "assumed_genome_bp", "sequenced_bases_per_assumed_genome", "read1", "read2"))
        writer.writerows(result)
    print(f"Validated {len(result)} read pairs sets: {args.output}")


if __name__ == "__main__":
    main()
