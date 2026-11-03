#!/usr/bin/env python3
"""Unsupervised contig baseline; candidate identities are used only after fitting.

Input: matching master/self-mapping TSVs with contig_id, length_bp,
gc_percent, coverage; a separate newline-delimited candidate ID list.
Outputs: feature matrices, assignments, centroids, metrics, candidate
distribution, plots, and provenance in a new output directory.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path


EXPECTED_N = 13807
FEATURES = ("gc_percent", "log10_length_bp", "log10_coverage_plus_1")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as stream:
        reader = csv.DictReader(stream, delimiter="\t")
        required = {"contig_id", "length_bp", "gc_percent", "coverage"}
        if not required <= set(reader.fieldnames or []):
            raise ValueError(f"{path}: missing columns {sorted(required - set(reader.fieldnames or []))}")
        rows = list(reader)
    if len(rows) != EXPECTED_N:
        raise ValueError(f"{path}: expected {EXPECTED_N} rows, found {len(rows)}")
    ids = [row["contig_id"] for row in rows]
    if len(set(ids)) != EXPECTED_N or not all(ids):
        raise ValueError(f"{path}: contig IDs are empty or duplicated")
    return rows


def feature_values(rows):
    values = []
    for row in rows:
        try:
            length = int(row["length_bp"])
            gc = float(row["gc_percent"])
            coverage = float(row["coverage"])
        except (ValueError, TypeError) as exc:
            raise ValueError(f"Invalid feature value for {row['contig_id']}") from exc
        if length <= 0 or not 0 <= gc <= 100 or not math.isfinite(gc):
            raise ValueError(f"Invalid length or GC for {row['contig_id']}")
        if not math.isfinite(coverage) or coverage < 0:
            raise ValueError(f"Invalid coverage for {row['contig_id']}")
        values.append((gc, math.log10(length), math.log10(coverage + 1)))
    return values


def write_tsv(path, fields, rows):
    with path.open("x", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(fields)
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--master", type=Path, required=True)
    parser.add_argument("--original", type=Path, required=True)
    parser.add_argument("--candidate-ids", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261102)
    parser.add_argument("--silhouette-sample", type=int, default=2000)
    parser.add_argument("--validate-only", action="store_true", help="Audit inputs without fitting or writing")
    args = parser.parse_args()

    if args.silhouette_sample < 2 or args.silhouette_sample > EXPECTED_N:
        parser.error("--silhouette-sample must be between 2 and 13807")
    for path in (args.master, args.original, args.candidate_ids):
        if not path.is_file() or not path.stat().st_size:
            parser.error(f"Missing or empty input: {path}")
    if args.output.exists():
        parser.error(f"Output already exists; choose a new run directory: {args.output}")
    if args.master.resolve() == args.original.resolve():
        parser.error("Master and original must be separate files")

    # Equality checks all fields, including row order and values, before any fit.
    master_hash, original_hash = digest(args.master), digest(args.original)
    if master_hash != original_hash:
        parser.error("Master table differs from original self-mapping table (SHA-256)")
    rows = load_rows(args.master)
    load_rows(args.original)
    ids = [row["contig_id"] for row in rows]
    id_set = set(ids)
    candidates = [x.strip() for x in args.candidate_ids.read_text().splitlines() if x.strip()]
    if len(candidates) != 41 or len(set(candidates)) != 41 or not set(candidates) <= id_set:
        parser.error("Candidate list must have 41 distinct IDs present in the input table")
    values = feature_values(rows)
    if args.validate_only:
        print(f"PASS: {len(rows)} unique contigs with valid features, matching SHA-256 {master_hash}, 41 candidate IDs")
        return

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.lines import Line2D
    import numpy as np
    import sklearn
    from sklearn.cluster import KMeans
    from sklearn.metrics import silhouette_score
    from sklearn.preprocessing import StandardScaler

    raw = np.asarray(values, dtype=float)
    scaler = StandardScaler()
    z = scaler.fit_transform(raw)
    if not np.isfinite(z).all() or np.any(scaler.scale_ == 0):
        raise ValueError("Feature scaling failed or a feature has zero variance")

    # Run directory is created exclusively. A failed run remains for inspection.
    args.output.mkdir(parents=True, exist_ok=False)
    write_tsv(args.output / "features_raw.tsv", ("contig_id",) + FEATURES,
              ((cid, *v) for cid, v in zip(ids, raw)))
    write_tsv(args.output / "features_standardized.tsv",
              ("contig_id",) + tuple(f"z_{x}" for x in FEATURES),
              ((cid, *v) for cid, v in zip(ids, z)))
    write_tsv(args.output / "scaler.tsv", ("feature", "mean", "scale_population_sd"),
              zip(FEATURES, scaler.mean_, scaler.scale_))

    candidate_set = set(candidates)
    metrics = []
    centroid_rows = []
    assignment_rows = []
    candidate_rows = []
    candidate_assignments = []
    for k in range(2, 9):
        model = KMeans(n_clusters=k, random_state=args.seed, n_init=20, algorithm="lloyd")
        labels = model.fit_predict(z)
        sizes = np.bincount(labels, minlength=k)
        if np.any(sizes == 0):
            raise ValueError(f"k={k}: empty cluster")
        # sklearn selects a reproducible subset; pairwise distance memory stays bounded.
        silhouette = silhouette_score(z, labels, sample_size=args.silhouette_sample,
                                      random_state=args.seed)
        metrics.append((k, model.inertia_, silhouette, args.silhouette_sample,
                        int(model.n_iter_), int(sizes.min()), int(sizes.max())))
        centers_raw = scaler.inverse_transform(model.cluster_centers_)
        for cluster in range(k):
            centroid_rows.append((k, cluster, int(sizes[cluster]),
                                  *model.cluster_centers_[cluster], *centers_raw[cluster]))
            n_candidate = sum(labels[i] == cluster for i, cid in enumerate(ids)
                              if cid in candidate_set)
            candidate_rows.append((k, cluster, int(sizes[cluster]), int(n_candidate),
                                   n_candidate / 41, n_candidate / int(sizes[cluster])))
        assignment_rows.extend((k, cid, int(label)) for cid, label in zip(ids, labels))
        candidate_assignments.extend((k, cid, int(labels[i])) for i, cid in enumerate(ids)
                                     if cid in candidate_set)

        for y_index, y_label, suffix in ((2, "log10(self-mapping coverage + 1)", "gc_vs_coverage"),
                                         (1, "log10(contig length, bp)", "gc_vs_length")):
            fig, ax = plt.subplots(figsize=(8, 6))
            scatter = ax.scatter(raw[:, 0], raw[:, y_index], c=labels, cmap="tab10",
                                 vmin=-0.5, vmax=9.5, s=5, alpha=0.55, rasterized=True)
            ax.set(xlabel="GC (%)", ylabel=y_label, title=f"NB0507-14 downsampled contigs: k={k}")
            handles = [Line2D([], [], marker="o", linestyle="", markersize=5,
                              color=scatter.cmap(scatter.norm(i))) for i in range(k)]
            ax.legend(handles, [f"Cluster {i} (n={sizes[i]})" for i in range(k)],
                      title="K-means", loc="best", fontsize=8)
            fig.tight_layout()
            fig.savefig(args.output / f"k{k}_{suffix}.png", dpi=180)
            plt.close(fig)

    write_tsv(args.output / "cluster_metrics.tsv",
              ("k", "inertia", "silhouette_sampled", "silhouette_n", "iterations",
               "smallest_cluster", "largest_cluster"), metrics)
    write_tsv(args.output / "centroids.tsv",
              ("k", "cluster", "cluster_size") + tuple(f"z_{x}" for x in FEATURES) + FEATURES,
              centroid_rows)
    write_tsv(args.output / "assignments.tsv", ("k", "contig_id", "cluster"), assignment_rows)
    write_tsv(args.output / "candidate_distribution.tsv",
              ("k", "cluster", "cluster_size", "candidate_count", "fraction_of_41",
               "candidate_fraction_of_cluster"), candidate_rows)
    write_tsv(args.output / "candidate_assignments.tsv", ("k", "contig_id", "cluster"),
              candidate_assignments)
    provenance = {
        "master": str(args.master), "master_sha256": master_hash,
        "original": str(args.original), "original_sha256": original_hash,
        "candidate_ids": str(args.candidate_ids),
        "candidate_ids_sha256": digest(args.candidate_ids),
        "input_rows": len(rows), "features": list(FEATURES),
        "training_excludes_candidate_ids_and_taxonomy": True,
        "standardization": "StandardScaler population SD, fit across all 13807 contigs",
        "k": list(range(2, 9)), "seed": args.seed, "n_init": 20,
        "silhouette_sample_size": args.silhouette_sample,
        "silhouette_method": "sklearn.metrics.silhouette_score random sample; Euclidean distance",
        "versions": {"numpy": np.__version__, "sklearn": sklearn.__version__,
                     "matplotlib": matplotlib.__version__},
        "slurm_job_id": os.environ.get("SLURM_JOB_ID", "not_submitted"),
    }
    (args.output / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    (args.output / "COMPLETE").write_text("Validated inputs and generated all k=2..8 outputs.\n")
    print(f"Completed phase II baseline: {args.output}")


if __name__ == "__main__":
    main()
