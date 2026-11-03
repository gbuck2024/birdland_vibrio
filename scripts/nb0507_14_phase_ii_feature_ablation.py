#!/usr/bin/env python3
"""Phase II feature ablation on all downsampled old NB0507-14 contigs.

Input schema and transforms are shared with nb0507_14_phase_ii_kmeans.py.
Candidate IDs are opened only after every unsupervised model and metric is done.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from nb0507_14_phase_ii_kmeans import (
    EXPECTED_N, FEATURES, digest, feature_values, load_rows, write_tsv,
)

MODELS = {
    "full": (0, 1, 2),
    "gc_coverage": (0, 2),
    "gc_length": (0, 1),
    "length_coverage": (1, 2),
}


def validate_candidates(path: Path, id_set: set[str]) -> set[str]:
    candidates = [s.strip() for s in path.read_text().splitlines() if s.strip()]
    if len(candidates) != 41 or len(set(candidates)) != 41 or not set(candidates) <= id_set:
        raise ValueError("Candidate file must contain 41 unique contig IDs present in the master table")
    return set(candidates)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--master", required=True, type=Path)
    parser.add_argument("--original", required=True, type=Path)
    parser.add_argument("--candidate-ids", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=20261102)
    parser.add_argument("--n-init", type=int, default=20)
    parser.add_argument("--silhouette-sample", type=int, default=2000)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    if args.n_init < 2 or not 2 <= args.silhouette_sample <= EXPECTED_N:
        parser.error("n-init must be >=2 and silhouette-sample must be 2..13807")
    for path in (args.master, args.original, args.candidate_ids):
        if not path.is_file() or not path.stat().st_size:
            parser.error(f"Missing or empty input: {path}")
    if args.master.resolve() == args.original.resolve():
        parser.error("Master and original paths must differ")
    if args.output.exists():
        parser.error(f"Output already exists: {args.output}")
    master_hash = digest(args.master)
    if master_hash != digest(args.original):
        parser.error("Master and original self-mapping tables differ by SHA-256")
    rows = load_rows(args.master)
    ids = [row["contig_id"] for row in rows]
    raw_values = feature_values(rows)
    # Check existence and syntax, but defer reading candidate identities until after fitting.
    if args.validate_only:
        validate_candidates(args.candidate_ids, set(ids))
        print(f"PASS: {len(ids)} contigs, matching input SHA-256 {master_hash}, 41 candidate IDs")
        return

    import numpy as np
    import sklearn
    from sklearn.cluster import KMeans
    from sklearn.metrics import adjusted_rand_score, silhouette_score
    from sklearn.preprocessing import StandardScaler

    raw = np.asarray(raw_values, dtype=float)
    args.output.mkdir(parents=True, exist_ok=False)
    write_tsv(args.output / "features_raw.tsv", ("contig_id",) + FEATURES,
              ((cid, *v) for cid, v in zip(ids, raw)))
    scaler_rows, metrics, sizes_rows, centroid_rows, assignment_rows = [], [], [], [], []
    labels_by_key = {}
    for name, columns in MODELS.items():
        selected = tuple(FEATURES[i] for i in columns)
        scaler = StandardScaler()
        z = scaler.fit_transform(raw[:, columns])
        if not np.isfinite(z).all() or np.any(scaler.scale_ == 0):
            raise ValueError(f"{name}: invalid standardized features")
        scaler_rows.extend((name, feature, mean, scale) for feature, mean, scale
                           in zip(selected, scaler.mean_, scaler.scale_))
        for k in range(2, 9):
            model = KMeans(n_clusters=k, random_state=args.seed,
                           n_init=args.n_init, algorithm="lloyd")
            labels = model.fit_predict(z)
            sizes = np.bincount(labels, minlength=k)
            if len(labels) != EXPECTED_N or np.any(sizes == 0) or int(sizes.sum()) != EXPECTED_N:
                raise ValueError(f"{name} k={k}: invalid assignments")
            labels_by_key[name, k] = labels
            score = silhouette_score(z, labels, sample_size=args.silhouette_sample,
                                     random_state=args.seed, metric="euclidean")
            metrics.append((name, len(columns), k, model.inertia_, score,
                            args.silhouette_sample, int(model.n_iter_), args.seed, args.n_init))
            inverse = scaler.inverse_transform(model.cluster_centers_)
            for cluster in range(k):
                sizes_rows.append((name, k, cluster, int(sizes[cluster])))
                for j, feature in enumerate(selected):
                    centroid_rows.append((name, k, cluster, feature,
                                          float(model.cluster_centers_[cluster, j]),
                                          float(inverse[cluster, j])))
            assignment_rows.extend((name, k, cid, int(label))
                                   for cid, label in zip(ids, labels))

    ari_rows = []
    names = list(MODELS)
    for k in range(2, 9):
        for i, left in enumerate(names):
            for right in names[i + 1:]:
                ari_rows.append((k, left, right,
                                 adjusted_rand_score(labels_by_key[left, k],
                                                     labels_by_key[right, k])))

    # Post-fit evaluation: IDs and their prior taxonomic interpretation did not
    # enter feature selection, scaling, fitting, silhouette, or ARI.
    candidates = validate_candidates(args.candidate_ids, set(ids))
    candidate_assignments, candidate_distribution = [], []
    for name in names:
        for k in range(2, 9):
            labels = labels_by_key[name, k]
            counts = [0] * k
            for cid, label in zip(ids, labels):
                if cid in candidates:
                    counts[int(label)] += 1
                    candidate_assignments.append((name, k, cid, int(label)))
            if sum(counts) != 41:
                raise ValueError(f"{name} k={k}: expected 41 candidate assignments")
            sizes = np.bincount(labels, minlength=k)
            candidate_distribution.extend((name, k, cluster, int(sizes[cluster]),
                                           counts[cluster], counts[cluster] / 41,
                                           counts[cluster] / int(sizes[cluster]))
                                          for cluster in range(k))

    write_tsv(args.output / "scaler.tsv", ("model", "feature", "mean", "scale_population_sd"), scaler_rows)
    write_tsv(args.output / "cluster_metrics.tsv",
              ("model", "n_features", "k", "inertia", "silhouette_sampled", "silhouette_n",
               "iterations", "seed", "n_init"), metrics)
    write_tsv(args.output / "cluster_sizes.tsv", ("model", "k", "cluster", "n_contigs"), sizes_rows)
    write_tsv(args.output / "centroids.tsv",
              ("model", "k", "cluster", "feature", "z_centroid", "raw_transformed_centroid"), centroid_rows)
    write_tsv(args.output / "assignments.tsv", ("model", "k", "contig_id", "cluster"), assignment_rows)
    write_tsv(args.output / "adjusted_rand.tsv", ("k", "model_a", "model_b", "adjusted_rand_index"), ari_rows)
    write_tsv(args.output / "candidate_assignments.tsv",
              ("model", "k", "contig_id", "cluster"), candidate_assignments)
    write_tsv(args.output / "candidate_distribution.tsv",
              ("model", "k", "cluster", "cluster_size", "candidate_count",
               "fraction_of_41", "candidate_fraction_of_cluster"), candidate_distribution)
    provenance = {
        "question": "How does removing each of GC, length, or self-mapping coverage change unsupervised contig clusters?",
        "master": str(args.master), "master_sha256": master_hash,
        "original": str(args.original), "original_sha256": digest(args.original),
        "candidate_ids": str(args.candidate_ids), "candidate_ids_sha256": digest(args.candidate_ids),
        "n_contigs": EXPECTED_N, "features": list(FEATURES),
        "models": {key: [FEATURES[i] for i in columns] for key, columns in MODELS.items()},
        "transforms": "GC percent; log10(length bp); log10(self-mapping coverage + 1)",
        "scaling": "StandardScaler, population SD, fit independently on all contigs for each model",
        "clustering": "Euclidean KMeans, Lloyd", "k": list(range(2, 9)),
        "seed": args.seed, "n_init": args.n_init,
        "silhouette": f"Euclidean score on {args.silhouette_sample} contigs sampled with fixed seed; same sample across models",
        "candidate_usage": "41 IDs loaded only after all fits and model metrics; never used for model selection",
        "inertia_warning": "Inertia is not directly comparable across feature dimensions",
        "versions": {"numpy": np.__version__, "sklearn": sklearn.__version__},
        "slurm_job_id": os.environ.get("SLURM_JOB_ID", "not_submitted"),
    }
    (args.output / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    (args.output / "CLUSTERING_COMPLETE").write_text("All four models and k=2..8 passed output checks.\n")
    print(f"Completed clustering and post-fit candidate evaluation: {args.output}")


if __name__ == "__main__":
    main()
