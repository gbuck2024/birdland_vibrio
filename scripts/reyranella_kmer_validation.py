#!/usr/bin/env python3
"""Count exact canonical 31-mers from full-assembly candidate contigs in paired reads.

The observation unit is a candidate contig by sequencing dataset. A marker is
exclusive only if it occurs in one candidate and nowhere else in the assembly.
Shared markers are reported separately and never treated as specific evidence.
"""

import argparse
import csv
import gzip
import hashlib
import re
import sys
from collections import Counter, defaultdict
from itertools import zip_longest
from pathlib import Path

from reyranella_read_mapping_report import read_inputs

K = 31
MASK = (1 << (2 * K)) - 1
BASE = {ord("A"): 0, ord("C"): 1, ord("G"): 2, ord("T"): 3,
        ord("a"): 0, ord("c"): 1, ord("g"): 2, ord("t"): 3}
EXPECTED = {
    "Buck_NB0507_14_depth_matched": ("b2dcb79581d8c5d6c3c5a3ac3b3aa943eee1463afd080cae86706ed53da48e16", "bdff4fd46e65c02f65a8ba7a84aeb4ef4057c3595eba18b704a8cf36912dd417"),
    "SRR37852095_L7_depth_matched": ("b3e71352517afcf362c5a6a7bd520904c881151310aadb4661333279388b8001", "2e4ecc02c535319d14612567b7fdf4b3b525caa1081c5c8866e3c60724879251"),
}
REFERENCE_SHA = "08d26c889f01226f068f3d0882f91716248e2629a25f9575ceae2e5c6eddae6e"
CANDIDATES_SHA = "10810a094313b52958c0904ae74f684b4bab5177b53df204b53628a59c487984"
MANIFEST_SHA = "513804a168d732963a7621e48645b82aee63b22db9b37adabf710b62062da772"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def kmers(sequence):
    """Yield canonical two-bit k-mers; ambiguous bases break the run."""
    forward = reverse = valid = 0
    for base in sequence:
        code = BASE.get(base)
        if code is None:
            forward = reverse = valid = 0
            continue
        forward = ((forward << 2) | code) & MASK
        reverse = (reverse >> 2) | ((3 - code) << (2 * (K - 1)))
        valid += 1
        if valid >= K:
            yield min(forward, reverse)


def fasta(path):
    name, parts = None, []
    with path.open("rt", encoding="ascii") as stream:
        for line in stream:
            if line.startswith(">"):
                if name is not None:
                    yield name, b"".join(parts)
                name, parts = line[1:].split()[0], []
            elif name is None:
                raise ValueError("FASTA sequence precedes header")
            else:
                parts.append(line.strip().encode("ascii"))
        if name is not None:
            yield name, b"".join(parts)


def build_markers(reference, candidate_ids):
    candidate_set = set(candidate_ids)
    candidate_markers = {}
    owners = {}  # canonical k-mer -> candidate index, or -1 for multiple candidates
    for name, seq in fasta(reference):
        if name in candidate_set:
            index = candidate_ids.index(name)
            markers = set(kmers(seq))
            candidate_markers[name] = markers
            for marker in markers:
                previous = owners.setdefault(marker, index)
                if previous != index:
                    owners[marker] = -1
    if not owners:
        raise ValueError("no usable candidate markers")
    shared_other = set()
    for name, seq in fasta(reference):
        if name not in candidate_set:
            shared_other.update(marker for marker in kmers(seq) if marker in owners)
    exclusive = {marker: owner for marker, owner in owners.items()
                 if owner >= 0 and marker not in shared_other}
    catalog = Counter()
    for name, markers in candidate_markers.items():
        for marker in markers:
            if marker in exclusive:
                catalog[(name, "exclusive")] += 1
            if owners[marker] == -1:
                catalog[(name, "shared_candidates")] += 1
            if marker in shared_other:
                catalog[(name, "shared_other")] += 1
    catalog[("ALL", "shared_candidates_distinct")] = sum(owner == -1 for owner in owners.values())
    return exclusive, owners, shared_other, catalog


def records(path):
    with gzip.open(path, "rb") as stream:
        number = 0
        while header := stream.readline():
            number += 1
            seq, plus, qual = stream.readline(), stream.readline(), stream.readline()
            if not header.startswith(b"@") or not plus.startswith(b"+") or not seq or not qual:
                raise ValueError(f"malformed FASTQ record {number}: {path}")
            seq, qual = seq.rstrip(b"\r\n"), qual.rstrip(b"\r\n")
            if not seq or len(seq) != len(qual):
                raise ValueError(f"sequence/quality length mismatch at record {number}: {path}")
            name = header[1:].split()[0]
            if name.endswith((b"/1", b"/2")):
                name = name[:-2]
            yield name, seq


def count_pair_files(read1, read2, exclusive, expected_pairs):
    occurrences = Counter()
    observed = defaultdict(set)
    pair_support = Counter()
    totals = Counter()
    for number, (mate1, mate2) in enumerate(zip_longest(records(read1), records(read2)), 1):
        if mate1 is None or mate2 is None or mate1[0] != mate2[0]:
            raise ValueError(f"mates out of sync at pair {number}: {read1}, {read2}")
        pair_owners = set()
        for _, seq in (mate1, mate2):
            totals["sequenced_bases"] += len(seq)
            totals["usable_bases"] += sum(len(run) for run in re.findall(b"[ACGTacgt]+", seq) if len(run) >= K)
            for marker in kmers(seq):
                totals["usable_windows"] += 1
                owner = exclusive.get(marker)
                if owner is not None:
                    occurrences[owner] += 1
                    observed[owner].add(marker)
                    pair_owners.add(owner)
        pair_support.update(pair_owners)
        totals["read_pairs"] = number
    if totals["read_pairs"] != expected_pairs:
        raise ValueError(f"expected {expected_pairs} pairs; found {totals['read_pairs']}: {read1}")
    return occurrences, observed, pair_support, totals


def write_tsv(path, header, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--prior-audit", type=Path, required=True)
    parser.add_argument("--stage", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    manifest, reference, candidates = (root / p for p in (args.manifest, args.reference, args.candidates))
    lengths, ids, samples = read_inputs(root, manifest, reference, candidates)
    if len(lengths) != 13807 or len(ids) != 41:
        raise ValueError("unexpected full assembly or candidate count")
    for path, expected in ((manifest, MANIFEST_SHA), (reference, REFERENCE_SHA), (candidates, CANDIDATES_SHA)):
        if sha256(path) != expected:
            raise ValueError(f"input checksum changed: {path}")
    with (root / args.prior_audit).open(newline="") as stream:
        audit = {row["sample_id"]: row for row in csv.DictReader(stream, delimiter="\t")}
    if set(audit) != set(EXPECTED) or {row["sample_id"] for row in samples} != set(EXPECTED):
        raise ValueError("manifest/audit sample IDs differ from validated pair")
    for row in samples:
        sample, old = row["sample_id"], audit[row["sample_id"]]
        if old["read1"] != row["read1"] or old["read2"] != row["read2"] or old["read_pairs"] != "914516":
            raise ValueError(f"prior audit mismatch: {sample}")
        for mate, expected in zip(("read1", "read2"), EXPECTED[sample]):
            if old[mate + "_sha256"] != expected or sha256(root / row[mate]) != expected:
                raise ValueError(f"FASTQ checksum differs from validated mapping input: {sample} {mate}")

    exclusive, owners, shared_other, catalog = build_markers(reference, ids)
    stage = root / args.stage
    for output in (stage / "metrics" / "parameters.tsv", stage / "metrics" / "input_audit.tsv",
                   stage / "reports" / "candidate_31mer_support.tsv", stage / "reports" / "marker_classes.tsv"):
        if output.exists():
            raise FileExistsError(f"refusing to replace {output}")
    class_rows = [[name, cls, n] for (name, cls), n in sorted(catalog.items())]
    class_rows.append(["ALL", "candidate_markers_total", len(owners)])
    class_rows.append(["ALL", "shared_with_other_contigs_total", len(shared_other)])
    write_tsv(stage / "reports" / "marker_classes.tsv", ["candidate_id", "class", "distinct_canonical_31mers"], class_rows)
    rows, audit_rows = [], []
    for row in samples:
        sample = row["sample_id"]
        occ, seen, pairs, totals = count_pair_files(root / row["read1"], root / row["read2"], exclusive, 914516)
        audit_rows.append([sample, row["read1"], row["read2"], *EXPECTED[sample],
                           totals["read_pairs"], totals["sequenced_bases"], totals["usable_bases"], totals["usable_windows"]])
        for index, name in enumerate(ids):
            count = catalog[(name, "exclusive")]
            distinct = len(seen[index])
            rows.append([sample, name, lengths[name], count, catalog[(name, "shared_candidates")], catalog[(name, "shared_other")],
                         distinct, occ[index], pairs[index], f"{distinct / count:.6f}" if count else "NA"])
    write_tsv(stage / "metrics" / "input_audit.tsv",
              ["sample_id", "read1", "read2", "read1_sha256", "read2_sha256", "read_pairs", "sequenced_bases", "usable_bases", "usable_31mer_windows"], audit_rows)
    write_tsv(stage / "reports" / "candidate_31mer_support.tsv",
              ["sample_id", "candidate_id", "contig_bp", "exclusive_distinct_markers", "shared_across_candidates_distinct_markers", "shared_with_other_contigs_distinct_markers", "exclusive_observed_distinct_markers", "exclusive_total_occurrences", "exclusive_supporting_read_pairs", "exclusive_marker_fraction_observed"], rows)
    write_tsv(stage / "metrics" / "parameters.tsv", ["parameter", "value"], [
        ["k", K], ["canonical", "min(forward,reverse_complement)"], ["ambiguous_bases", "break 31-mer runs"],
        ["marker_definition", "occurs in one candidate and no other assembly contig"],
        ["pair_count_unit", "distinct synchronized pair; max one per candidate"],
        ["occurrence_unit", "read window including repeats and both mates"],
        ["usable_bases", "bases in unambiguous runs of at least 31"],
        ["reference_sha256", REFERENCE_SHA], ["candidates_sha256", CANDIDATES_SHA],
        ["manifest_sha256", MANIFEST_SHA], ["python_version", sys.version.split()[0]],
        ["expected_pairs_per_sample", 914516], ["filter", "exact sequence only; no base quality threshold"]])
    print(f"Validated {len(samples)} read pairs of files; {len(exclusive)} exclusive candidate markers; wrote {len(rows)} candidate rows")


if __name__ == "__main__":
    main()
