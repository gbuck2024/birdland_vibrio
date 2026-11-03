#!/usr/bin/env python3
"""Audit paired gzipped FASTQs before a depth-matched mapping job."""

import argparse
import csv
import gzip
import hashlib
from itertools import zip_longest
from pathlib import Path

from reyranella_read_mapping_report import read_inputs


def fastq_records(handle, path):
    """Yield normalized read IDs while checking every FASTQ record."""
    count = 0
    while True:
        header = handle.readline()
        if not header:
            return
        sequence = handle.readline()
        plus = handle.readline()
        quality = handle.readline()
        count += 1
        if not header.startswith("@") or not plus.startswith("+") or not sequence or not quality:
            raise ValueError(f"malformed FASTQ record {count}: {path}")
        if len(sequence.rstrip("\r\n")) != len(quality.rstrip("\r\n")):
            raise ValueError(f"sequence/quality length mismatch at record {count}: {path}")
        name = header[1:].split()[0]
        yield name[:-2] if name.endswith(("/1", "/2")) else name


def audit_pair(read1, read2, expected_pairs):
    # Reading to EOF checks the gzip trailer/CRC as well as record structure.
    with gzip.open(read1, "rt", encoding="ascii") as r1, gzip.open(read2, "rt", encoding="ascii") as r2:
        count = 0
        for id1, id2 in zip_longest(fastq_records(r1, read1), fastq_records(r2, read2)):
            count += 1
            if id1 is None or id2 is None or id1 != id2:
                raise ValueError(f"out-of-sync mate IDs at pair {count}: {id1} != {id2}")
    if count != expected_pairs:
        raise ValueError(f"expected {expected_pairs} pairs, found {count}: {read1}, {read2}")
    return count


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--expected-pairs", type=int, required=True)
    parser.add_argument("--expected-contigs", type=int, required=True)
    parser.add_argument("--expected-reference-sha256", required=True)
    parser.add_argument("--expected-candidates-sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    lengths, ids, samples = read_inputs(root, root / args.manifest, root / args.reference, root / args.candidates)
    if len(lengths) != args.expected_contigs:
        raise ValueError(f"expected {args.expected_contigs} reference contigs, found {len(lengths)}")
    if sha256(root / args.reference) != args.expected_reference_sha256:
        raise ValueError("reference checksum differs from the completed full-old-read run")
    if sha256(root / args.candidates) != args.expected_candidates_sha256:
        raise ValueError("candidate-list checksum differs from the completed full-old-read run")
    if args.expected_pairs < 1:
        raise ValueError("expected pair count must be positive")
    rows = []
    for row in samples:
        read1, read2 = (root / row[mate] for mate in ("read1", "read2"))
        count = audit_pair(read1, read2, args.expected_pairs)
        rows.append([row["sample_id"], row["read1"], row["read2"], count,
                     sha256(read1), sha256(read2)])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["sample_id", "read1", "read2", "read_pairs", "read1_sha256", "read2_sha256"])
        writer.writerows(rows)
    print(f"Validated gzip integrity and synchronized FASTQ records: {len(samples)} pairs of files, "
          f"{args.expected_pairs} pairs per sample, {len(lengths)} reference contigs, {len(ids)} candidates")


if __name__ == "__main__":
    main()
