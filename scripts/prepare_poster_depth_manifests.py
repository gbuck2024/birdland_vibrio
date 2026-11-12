#!/usr/bin/env python3
"""Prepare six-isolate 25/50/100x paired-read and assembly manifests, without replacing files."""
import argparse
import csv
from pathlib import Path

DEPTHS = (25, 50, 100)
GENOME_BP = 5_200_000
ASSUMED_READ_BP = 149
SEED = 20261111
STAGE = Path("ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111")


def write_new(path, header, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", default="configs/assembly_manifest.tsv")
    parser.add_argument("--out-prefix", default="configs/abrcms_poster_depth_20261111")
    args = parser.parse_args()
    with open(args.input, newline="") as handle:
        samples = list(csv.DictReader(handle, delimiter="\t"))
    if len(samples) != 6 or len({r["sample_id"] for r in samples}) != 6:
        raise SystemExit("Expected six distinct Buck sample IDs")
    outputs = [Path(args.out_prefix + suffix) for suffix in ("_subsample.tsv", "_assembly.tsv", "_blob.tsv")]
    if any(path.exists() for path in outputs):
        raise SystemExit("Refusing to replace an existing manifest: " + ", ".join(str(p) for p in outputs if p.exists()))
    subsample, assembly, blob = [], [], []
    for sample in samples:
        sample_id = sample["sample_id"]
        isolate = sample_id.split("_WKDL", 1)[0].removeprefix("Buck_")
        for depth in DEPTHS:
            run_id = f"{sample_id}_{depth}x"
            short_id = f"{isolate}_{depth}x"
            read_dir = STAGE / "subsampled_reads" / run_id
            r1 = str(read_dir / f"{run_id}_1_paired.fq.gz")
            r2 = str(read_dir / f"{run_id}_2_paired.fq.gz")
            pairs = round(depth * GENOME_BP / (2 * ASSUMED_READ_BP))
            subsample.append((sample_id, run_id, f"{depth}x", GENOME_BP, ASSUMED_READ_BP, pairs, SEED,
                              sample["read1"], sample["read2"], r1, r2,
                              str(STAGE / "metrics" / f"{run_id}.subsampling_metrics.tsv")))
            assembly.append((run_id, r1, r2))
            blob.append((short_id, run_id, r1, r2, str(STAGE / "assembly" / "assemblies" / run_id / "contigs.fasta")))
    write_new(outputs[0], ("sample_id", "subsample_id", "target_coverage", "genome_size_assumption", "read_length_assumption", "target_read_pairs", "seed", "read1", "read2", "out_read1", "out_read2", "metrics_out"), subsample)
    write_new(outputs[1], ("sample_id", "read1", "read2"), assembly)
    write_new(outputs[2], ("short_id", "sample_id", "trimmed_r1", "trimmed_r2", "spades_contigs"), blob)
    for path in outputs:
        print(path)


if __name__ == "__main__":
    main()
