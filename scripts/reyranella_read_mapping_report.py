#!/usr/bin/env python3
"""Validate the mapping inputs and summarize coverage of candidate contigs."""

import argparse
import csv
import subprocess
from collections import Counter, defaultdict
from pathlib import Path


def read_inputs(root, manifest, reference, candidates):
    lengths = {}
    with reference.open() as handle:
        for line in handle:
            if line.startswith(">"):
                name = line[1:].split()[0]
                if name in lengths:
                    raise ValueError(f"duplicate reference ID: {name}")
                lengths[name] = 0
            elif lengths:
                lengths[name] += len(line.strip())
    if not lengths:
        raise ValueError("empty reference FASTA")
    ids = [line.strip() for line in candidates.read_text().splitlines() if line.strip()]
    if len(ids) != 41 or len(set(ids)) != 41:
        raise ValueError(f"expected 41 unique candidate IDs, found {len(ids)}")
    if len(lengths) <= len(ids):
        raise ValueError("reference must be the complete assembly, not the candidate subset")
    missing = set(ids) - lengths.keys()
    if missing:
        raise ValueError(f"candidate IDs absent from full reference: {sorted(missing)}")
    with manifest.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if reader.fieldnames != ["sample_id", "read1", "read2"]:
            raise ValueError("manifest header must be sample_id, read1, read2")
        samples = list(reader)
    if len(samples) != 2 or len({row["sample_id"] for row in samples}) != 2:
        raise ValueError("manifest must contain two distinct samples")
    for row in samples:
        sample = row["sample_id"]
        if not sample or "/" in sample or ".." in sample:
            raise ValueError(f"unsafe sample ID: {sample}")
        if row["read1"] == row["read2"]:
            raise ValueError(f"R1 and R2 are identical for {sample}")
        mate_stems = []
        for mate, suffix in (("read1", "_1_paired.fq.gz"), ("read2", "_2_paired.fq.gz")):
            path = root / row[mate]
            if not path.is_file() or path.stat().st_size == 0:
                raise ValueError(f"missing/empty {mate} for {sample}: {path}")
            if not path.name.endswith(suffix):
                raise ValueError(f"unexpected {mate} name for {sample}: {path.name}")
            mate_stems.append(path.name[: -len(suffix)])
        if mate_stems[0] != mate_stems[1]:
            raise ValueError(f"R1/R2 sample stems differ for {sample}")
    return lengths, ids, samples


def summarize(stage, lengths, ids, samples):
    columns = ("numreads", "covbases", "coverage", "meandepth", "meanbaseq", "meanmapq")
    by_sample = {}
    support_by_sample = {}
    bed = stage / "metrics" / "candidate_regions.bed"
    with bed.open("w") as handle:
        for contig in ids:
            handle.write(f"{contig}\t0\t{lengths[contig]}\n")
    for row in samples:
        sample = row["sample_id"]
        bam = stage / "bam" / f"{sample}.sorted.bam"
        bai = Path(str(bam) + ".bai")
        coverage = stage / "metrics" / f"{sample}.mapq20_baseq20.coverage.tsv"
        flagstat = stage / "metrics" / f"{sample}.flagstat.txt"
        for path in (bam, bai, coverage, flagstat):
            if not path.is_file() or path.stat().st_size == 0:
                raise ValueError(f"missing/empty output for {sample}: {path}")
        records = {}
        with coverage.open(newline="") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            if reader.fieldnames is None or not set(("#rname", "endpos", *columns)).issubset(reader.fieldnames):
                raise ValueError(f"unexpected coverage columns: {coverage}")
            for item in reader:
                contig = item["#rname"]
                if contig in records:
                    raise ValueError(f"duplicate coverage record: {contig}")
                if contig not in lengths or int(item["endpos"]) != lengths[contig]:
                    raise ValueError(f"coverage/reference mismatch: {contig}")
                records[contig] = item
        if set(records) != set(lengths):
            raise ValueError(f"coverage does not include the complete assembly for {sample}")
        by_sample[sample] = records

        # Count >=5x bases from the same MAPQ/base-quality filters used for
        # coverage. -s prevents overlapping mates from counting twice.
        depth = subprocess.run(
            ["samtools", "depth", "-a", "-s", "-b", str(bed),
             "-q", "20", "-Q", "20", "-G", "0x800", str(bam)],
            check=True, capture_output=True, text=True,
        )
        ge5 = Counter()
        for line in depth.stdout.splitlines():
            contig, position, value = line.split("\t")
            if contig not in ids or not 1 <= int(position) <= lengths[contig]:
                raise ValueError(f"unexpected depth position: {line}")
            if int(value) >= 5:
                ge5[contig] += 1

        # Inspect primary mapped alignments on candidate contigs. MAPQ 0 is
        # ambiguous; >=20 is a high-confidence unique-placement proxy.
        alignments = subprocess.run(
            ["samtools", "view", "-L", str(bed), "-F", "0xF04", str(bam)],
            check=True, capture_output=True, text=True,
        )
        counts = defaultdict(Counter)
        pair_mates = defaultdict(lambda: {1: set(), 2: set()})
        confident_mates = defaultdict(lambda: {1: set(), 2: set()})
        for line in alignments.stdout.splitlines():
            fields = line.split("\t")
            qname, flag, contig, mapq, mate_ref = fields[0], int(fields[1]), fields[2], int(fields[4]), fields[6]
            if contig not in ids:
                raise ValueError(f"unexpected alignment reference: {contig}")
            if mapq == 0:
                counts[contig]["ambiguous_mapq0_reads"] += 1
            elif mapq < 20:
                counts[contig]["intermediate_mapq1_19_reads"] += 1
            else:
                counts[contig]["unique_proxy_mapq_ge20_reads"] += 1
            if flag & 0x2 and mate_ref in ("=", contig):
                mate = 1 if flag & 0x40 else 2 if flag & 0x80 else 0
                if mate:
                    pair_mates[contig][mate].add(qname)
                    if mapq >= 20:
                        confident_mates[contig][mate].add(qname)
        support_by_sample[sample] = {}
        for contig in ids:
            mapped_reads = sum(counts[contig][name] for name in (
                "unique_proxy_mapq_ge20_reads", "ambiguous_mapq0_reads", "intermediate_mapq1_19_reads"))
            support_by_sample[sample][contig] = {
                "bases_ge5": ge5[contig],
                "breadth_ge5_pct": round(100 * ge5[contig] / lengths[contig], 4),
                "proper_pairs": len(pair_mates[contig][1] & pair_mates[contig][2]),
                "proper_pairs_both_mapq_ge20": len(confident_mates[contig][1] & confident_mates[contig][2]),
                **{name: counts[contig][name] for name in (
                    "unique_proxy_mapq_ge20_reads", "ambiguous_mapq0_reads", "intermediate_mapq1_19_reads")},
                "unique_proxy_pct_mapped_reads": round(100 * counts[contig]["unique_proxy_mapq_ge20_reads"] / mapped_reads, 4) if mapped_reads else 0,
                "ambiguous_pct_mapped_reads": round(100 * counts[contig]["ambiguous_mapq0_reads"] / mapped_reads, 4) if mapped_reads else 0,
            }

    output = stage / "reports" / "reyranella_candidate_read_support.tsv"
    output.parent.mkdir(parents=True, exist_ok=True)
    support_columns = ("bases_ge5", "breadth_ge5_pct", "proper_pairs", "proper_pairs_both_mapq_ge20",
                       "unique_proxy_mapq_ge20_reads", "ambiguous_mapq0_reads", "intermediate_mapq1_19_reads",
                       "unique_proxy_pct_mapped_reads", "ambiguous_pct_mapped_reads")
    with output.open("w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["contig_id", "length_bp"] + [f"{row['sample_id']}_{col}" for row in samples for col in (*columns, *support_columns)])
        for contig in ids:
            writer.writerow([contig, lengths[contig]] + [value for row in samples for value in (
                *[by_sample[row["sample_id"]][contig][col] for col in columns],
                *[support_by_sample[row["sample_id"]][contig][col] for col in support_columns],
            )])
    summary = stage / "reports" / "reyranella_mapping_class_summary.tsv"
    class_columns = ("unique_proxy_mapq_ge20_reads", "ambiguous_mapq0_reads", "intermediate_mapq1_19_reads",
                     "proper_pairs", "proper_pairs_both_mapq_ge20")
    with summary.open("w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["sample_id", *class_columns, "unique_proxy_pct_mapped_reads", "ambiguous_pct_mapped_reads"])
        for row in samples:
            sample = row["sample_id"]
            totals = {col: sum(support_by_sample[sample][contig][col] for contig in ids)
                      for col in class_columns}
            mapped = sum(totals[col] for col in class_columns[:3])
            writer.writerow([sample, *[totals[col] for col in class_columns],
                             round(100 * totals["unique_proxy_mapq_ge20_reads"] / mapped, 4) if mapped else 0,
                             round(100 * totals["ambiguous_mapq0_reads"] / mapped, 4) if mapped else 0])
    print(f"Validated {len(lengths)} reference contigs, {len(ids)} candidates, and two BAMs; wrote {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("validate", "summarize"))
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--stage", type=Path, required=True)
    args = parser.parse_args()
    lengths, ids, samples = read_inputs(args.root, args.manifest, args.reference, args.candidates)
    print(f"Validated {len(lengths)} reference contigs, {len(ids)} candidates, and {len(samples)} paired read datasets")
    if args.mode == "summarize":
        summarize(args.stage, lengths, ids, samples)


if __name__ == "__main__":
    main()
