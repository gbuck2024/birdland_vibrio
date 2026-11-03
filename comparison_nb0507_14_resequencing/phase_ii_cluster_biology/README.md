# Frozen Phase II cluster biology

**Question:** What provisional taxonomic and feature composition does each k=2 and k=5 cluster have across the four Phase II models?

The input is the completed baseline and ablation assignment tables, the original 13,807-contig downsampled old master table, and the 41 candidate IDs. The script validates input hashes and exact ID sets, and confirms that the baseline full-model partition agrees with the ablation full-model partition at both k values. It never fits or changes a model. The observation unit is an assembly contig.

The separate run `biology_20261102/` contains a full contig join, per-cluster Kraken2 broad-class contig and bp counts, GC/length/self-mapping coverage five-number distributions, length-matched candidate enrichment, two comparative SVGs, a Markdown report, and provenance hashes. Its Kraken2 classifications are provisional. Length matching uses all noncandidate contigs in each candidate-occupied log2 length band: 40 candidates in [1000,2000) bp and one in [2000,4000) bp. Expected count is the sum of each candidate-band count multiplied by the noncandidate cluster proportion in that band. The candidate set is Kraken2-derived, so its taxonomic composition is not independent evidence.

To validate without writing, run `python3 scripts/nb0507_14_phase_ii_cluster_biology.py` with the arguments in the SLURM script plus `--validate-only` and a fresh `--output` path. To create a new run from the project root, choose an unused `RUN_ID` and submit:

```bash
sbatch --export=ALL,RUN_ID=biology_YYYYMMDD_v2 scripts/nb0507_14_phase_ii_cluster_biology.slurm
```

The `logs/` directory exists. Confirm SLURM exit 0, the output `COMPLETE` marker, 28 cluster rows, 140 taxon rows, 110,456 joined rows, and both figures. Existing `biology_20261102/`, clustering outputs, and assignments must remain untouched.
