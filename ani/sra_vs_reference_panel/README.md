# SRA vs Reference Panel ANI Matrix

This stage compares the six SRA SPAdes assemblies against the saved 76-genome `Vibrio` reference panel with `fastANI`.

The immediate goal is species-level confirmation for the SRA isolates after the multi-reference BWA-MEM and Kraken2 results. This is a rectangular matrix: SRA assemblies are queries and the saved reference panel is the reference set.

## Inputs

- Query manifest: `configs/ani_query_manifest_sra.tsv`
- Reference manifest: `configs/reference_sequence_manifest.tsv`
- Query assemblies: `assembly_sra/assemblies/<sample_id>/contigs.fasta`
- Container: `containers/fastani_latest.sif`

## Submit Comparisons

There are six SRA query assemblies, so use array range `0-5`:

```bash
sbatch \
  -o ani/sra_vs_reference_panel/logs/slurm/fastani_matrix_%A_%a.out \
  -e ani/sra_vs_reference_panel/logs/slurm/fastani_matrix_%A_%a.err \
  --export=ALL,STAGE_DIR=ani/sra_vs_reference_panel,QUERY_MANIFEST=configs/ani_query_manifest_sra.tsv,REFERENCE_MANIFEST=configs/reference_sequence_manifest.tsv \
  --array=0-5 \
  scripts/fastani_matrix_array.slurm
```

## Summarize Matrix

After all six comparison tasks complete:

```bash
sbatch \
  -o ani/sra_vs_reference_panel/logs/slurm/fastani_matrix_summary_%j.out \
  -e ani/sra_vs_reference_panel/logs/slurm/fastani_matrix_summary_%j.err \
  --export=ALL,ANI_MODE=matrix,STAGE_DIR=ani/sra_vs_reference_panel,QUERY_MANIFEST=configs/ani_query_manifest_sra.tsv,REFERENCE_MANIFEST=configs/reference_sequence_manifest.tsv \
  scripts/fastani_matrix_array.slurm
```

## Expected Outputs

- `ani/sra_vs_reference_panel/outputs/<sample_id>.fastani.tsv`
- `ani/sra_vs_reference_panel/metrics/fastani_matrix_long.tsv`
- `ani/sra_vs_reference_panel/metrics/fastani_genome_matrix.tsv`
- `ani/sra_vs_reference_panel/metrics/fastani_alignment_fraction_matrix.tsv`
- `ani/sra_vs_reference_panel/metrics/fastani_genome_matrix_af_ge_0_50.tsv`
- `ani/sra_vs_reference_panel/metrics/fastani_species_max_matrix.tsv`
- `ani/sra_vs_reference_panel/metrics/fastani_species_mean_matrix.tsv`

## Optional Heatmap

After the matrix summary exists, generate heatmaps from the project root:

```bash
module load R/gcc11/4.4.0
STAGE_DIR=ani/sra_vs_reference_panel \
UNKNOWN_IDS='SRR37851509_L7,SRR37851510_L7,SRR37852094_L7,SRR37852095_L7,SRR37852096_L7,SRR37852097_L7' \
Rscript scripts/plot_fastani_matrix_heatmap.R
```

## Optional Full Square Matrix

If reciprocal reference-to-SRA ANI/AF cells are needed later, run a separate full reference-panel-plus-SRA stage with `configs/reference_sequence_manifest.tsv` plus `configs/ani_query_manifest_sra.tsv` on both the query and reference sides. That requires `82` array tasks instead of `6`.
