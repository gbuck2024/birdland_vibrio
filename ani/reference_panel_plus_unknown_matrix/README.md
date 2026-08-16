# Reference Panel Plus Unknown ANI Matrix

This stage combines the saved reference panel with the six Buck unknown assemblies and summarizes all pairwise fastANI outputs into matrix tables and heatmap figures.

## Inputs

- Query manifest: `configs/reference_sequence_manifest.tsv` plus `configs/ani_unknown_query_manifest.tsv`
- Reference manifest: `configs/reference_sequence_manifest.tsv` plus `configs/ani_unknown_query_manifest.tsv`
- Raw fastANI outputs: `ani/reference_panel_plus_unknown_matrix/outputs/*.fastani.tsv`

## Current Outputs

- `metrics/fastani_matrix_long.tsv`: long-form pairwise ANI table with alignment fraction (`fragment_mappings / query_fragments`)
- `metrics/fastani_genome_matrix.tsv`: genome-by-genome ANI matrix
- `metrics/fastani_alignment_fraction_matrix.tsv`: genome-by-genome alignment fraction matrix
- `metrics/fastani_genome_matrix_af_ge_0_50.tsv`: ANI matrix retaining only cells with `AF >= 0.50`; lower-AF cells are written as `NA`
- `metrics/fastani_species_max_matrix.tsv`: species-level max ANI matrix
- `metrics/fastani_species_mean_matrix.tsv`: species-level mean ANI matrix
- `figures/reference_panel_plus_unknown_matrix_genome_heatmap.pdf`
- `figures/reference_panel_plus_unknown_matrix_genome_heatmap.png`
- `figures/reference_panel_plus_unknown_matrix_species_max_heatmap.pdf`
- `figures/reference_panel_plus_unknown_matrix_species_max_heatmap.png`

## Regenerate Matrices

The summary pass is lightweight and was run through SLURM as job `1465438`:

```bash
sbatch --export=ALL,ANI_MODE=matrix,STAGE_DIR=ani/reference_panel_plus_unknown_matrix,QUERY_MANIFEST=configs/reference_sequence_manifest.tsv,REFERENCE_MANIFEST=configs/reference_sequence_manifest.tsv,EXTRA_QUERY_MANIFEST=configs/ani_unknown_query_manifest.tsv,EXTRA_REFERENCE_MANIFEST=configs/ani_unknown_query_manifest.tsv scripts/fastani_matrix_array.slurm
```

## Regenerate Figures

The plotting step is lightweight and can be run from the project root. By default, cells with `AF < 0.50` are grayed out in the genome heatmap:

```bash
module load R/gcc11/4.4.0
Rscript scripts/plot_fastani_matrix_heatmap.R
```

The R script uses `ani/reference_panel_plus_unknown_matrix` by default. Override `STAGE_DIR`, `ANI_MATRIX_FILE`, `AF_MATRIX_FILE`, `AF_THRESHOLD`, `QUERY_METADATA_FILE`, `REFERENCE_METADATA_FILE`, or `HEATMAP_PREFIX` only when plotting a different compatible matrix stage or threshold.
