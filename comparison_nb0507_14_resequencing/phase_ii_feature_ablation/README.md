# Phase II feature ablation: NB0507-14 downsampled old assembly

**Question.** How does excluding GC percent, contig length, or old-read self-mapping coverage change the contig clusters? The observation unit is one assembly contig; fragments are not independent biological isolates.

**Inputs.** The curated `../metrics/downsampled_old.master_contig_table.tsv` and original self-mapping master table must be byte-identical. The full three-feature model uses GC percent, log10(length bp), and log10(coverage + 1), matching the baseline transforms. Three ablations use GC+coverage, GC+length, and length+coverage. Coverage is from old reads mapped to their own assembly. The 41 IDs in `../reyranella_validation/reyranella_1kb_ids.txt` are read only after all clustering, silhouette scoring, and adjusted Rand calculations.

**Method.** Each model standardizes its selected columns across all 13,807 contigs using population standard deviation. Euclidean K-means uses Lloyd iterations, k=2–8, seed 20261102, and 20 initializations for every model. Inertia and a seeded 2,000-contig silhouette sample are recorded. The same sample is used for all models, but the silhouette distances depend on the included dimensions. There is no automatic k or model selection, and candidate or taxonomic labels are not involved in fitting or selection. Adjusted Rand index (ARI) compares every pair of models at the same k across all 13,807 contigs and is invariant to cluster label renumbering. Inertia is **not directly comparable across feature dimensions**.

**Submission.** From the project root, submit exactly:

```bash
sbatch scripts/nb0507_14_phase_ii_feature_ablation.slurm
```

The batch script loads `ml-pythondeps-py39-cuda11.8-gcc11/4.12.0` (locally verified NumPy 1.22.4, scikit-learn 1.2.2) and `R/gcc11/4.4.0`, then checks imports and versions. The stage `logs/` directory is present. For a rerun, use a new ID: `sbatch --export=ALL,RUN_ID=ablation_seed20261102_v2 scripts/nb0507_14_phase_ii_feature_ablation.slurm`. The script refuses an existing run path; no existing phase II result is changed.

**Outputs.** The default run is `ablation_seed20261102/`. It contains the raw three-feature matrix, per-model scalers, `cluster_metrics.tsv`, `cluster_sizes.tsv`, long-format `centroids.tsv` (standardized and transformed raw units), `assignments.tsv`, all-pairs `adjusted_rand.tsv`, post-fit `candidate_assignments.tsv` and `candidate_distribution.tsv`, `provenance.json`, and eight R PDF figures under `figures/`. Each `cluster_structure_k*.pdf` projects all four label sets onto common GC-versus-coverage axes. Labels are arbitrary across models; use ARI for agreement. `ablation_summary.pdf` shows sampled silhouettes and full-versus-ablation ARI. The pipeline writes `COMPLETE` only after row counts, cluster-size sums, candidate counts, and figure counts pass. Confirm SLURM exit 0 and inspect the provenance and figures before interpretation.

**Limits and next decision.** Clusters can reflect assembly fragmentation, low depth, and self-mapping bias. The 41-contig distribution is descriptive, not independent evidence of taxonomic identity or contamination. Inspect silhouette, cluster sizes, ARI, and common-axis plots to judge stability; then compare any candidate-enriched groups with independent read-mapping and k-mer evidence. No numerical clustering result exists until the job completes.
