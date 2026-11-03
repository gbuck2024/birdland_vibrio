# Phase II K-means baseline: NB0507-14 downsampled assembly

**Question.** Do GC content, contig length, and old-read self-mapping coverage separate the 13,807 assembly contigs into broad groups, and where do the 41 previously investigated contigs fall after an unsupervised fit?

**Inputs.** The curated `metrics/downsampled_old.master_contig_table.tsv` must be byte-identical (SHA-256) to `downsampled_old_self_mapping/NB0507_14_downsampled/metrics/NB0507_14_downsampled.master_contig_table.tsv`. The 41 IDs are loaded from `reyranella_validation/reyranella_1kb_ids.txt` only for evaluation after fitting. The script validates 13,807 unique IDs, finite feature values, and 41 distinct, matching candidate IDs. Its training data contain only GC percent, log10(length in bp), and log10(self-mapping coverage + 1). Existing `coverage_log10` is not used because its transform may differ.

**Method.** `StandardScaler` fits each feature across all contigs. Euclidean `KMeans` uses k=2 through 8, Lloyd iterations, 20 initializations, and seed 20261102. Inertia is measured on all contigs. Silhouette is the scikit-learn estimate from 2,000 seeded sampled contigs, to bound pairwise distance memory. Cluster labels are arbitrary between k values. No taxonomic or candidate identity enters model training or selection. Each contig, including short fragments, has equal weight.

**Environment and submission.** Provide a Python executable with `numpy`, `scikit-learn`, and `matplotlib` on compute nodes. From the project root:

```bash
mkdir -p comparison_nb0507_14_resequencing/phase_ii_kmeans/logs
sbatch --export=ALL,PYTHON_BIN=/path/to/python scripts/nb0507_14_phase_ii_kmeans.slurm
```

If the active `python3` already provides these packages, `sbatch scripts/nb0507_14_phase_ii_kmeans.slurm` suffices. A new run needs a distinct `RUN_ID` via `--export`; the script refuses to replace an existing run. Logs go to `phase_ii_kmeans/logs/kmeans_%j.{out,err}`. No job has been submitted as part of preparation.

**Outputs.** `baseline_seed20261102/` will contain `features_raw.tsv` and `features_standardized.tsv` (13,807 × 3 plus ID), `scaler.tsv`, `assignments.tsv` (96,649 rows), `centroids.tsv`, `cluster_metrics.tsv`, `candidate_distribution.tsv`, `candidate_assignments.tsv`, 14 `k*_gc_vs_*.png` plots, `provenance.json`, and `COMPLETE`. The plots use log-transformed coverage and length on the vertical axes, as in the training matrix. Verify job exit 0 and `COMPLETE`, then inspect row counts, all cluster sizes summing to 13,807, candidate counts summing to 41 for each k, and input hashes before interpreting.

**Interpretation limits.** These clusters describe contig feature patterns, not taxonomic identity or contamination. Coverage comes from old reads mapped to their own assembly; contig fragmentation, length effects, correlated fragments, uneven coverage, and reference bias can affect separation. Silhouette scores are sampled estimates and should be read alongside cluster sizes and plots. The 41-contig distribution is a post-fit description, not independent biological validation; compare with read-level and k-mer evidence before drawing conclusions.
