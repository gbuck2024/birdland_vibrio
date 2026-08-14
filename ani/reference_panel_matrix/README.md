# ANI Reference Panel Matrix Workflow

This stage adds rectangular FastANI matrix workflows for the current reference panel and the six Buck assemblies. It is separate from the older `ani/` stages so previous ANI outputs remain untouched.

## Inputs

- Reference panel: `configs/reference_sequence_manifest.tsv`
- Unknown assemblies: `configs/ani_unknown_query_manifest.tsv` with all 6 Buck assemblies.
- Runner: `scripts/fastani_matrix_array.slurm`
- Summarizer: `scripts/summarize_fastani_matrix.py`
- Heatmap renderer: `scripts/plot_fastani_matrix_heatmap.R`

The runner accepts complete chromosomes, plasmid-containing complete genomes, scaffold assemblies, contig assemblies, and gzipped FASTA files. It validates only that each listed FASTA exists and is non-empty before running FastANI.

## Full Panel Plus Unknowns

This compares all current reference panel genomes and the six Buck assemblies against the same combined set, then writes genome-level and species-level matrices.

```bash
sbatch \
  --export=ALL,STAGE_DIR=ani/reference_panel_plus_unknown_matrix,QUERY_MANIFEST=configs/reference_sequence_manifest.tsv,REFERENCE_MANIFEST=configs/reference_sequence_manifest.tsv,EXTRA_QUERY_MANIFEST=configs/ani_unknown_query_manifest.tsv,EXTRA_REFERENCE_MANIFEST=configs/ani_unknown_query_manifest.tsv \
  --array=0-81 \
  scripts/fastani_matrix_array.slurm

sbatch \
  --export=ALL,ANI_MODE=matrix,STAGE_DIR=ani/reference_panel_plus_unknown_matrix,QUERY_MANIFEST=configs/reference_sequence_manifest.tsv,REFERENCE_MANIFEST=configs/reference_sequence_manifest.tsv,EXTRA_QUERY_MANIFEST=configs/ani_unknown_query_manifest.tsv,EXTRA_REFERENCE_MANIFEST=configs/ani_unknown_query_manifest.tsv \
  scripts/fastani_matrix_array.slurm
```

After the matrix job completes, render the heatmaps:

```bash
module load R/gcc11/4.4.0
STAGE_DIR=ani/reference_panel_plus_unknown_matrix \
HEATMAP_PREFIX=reference_panel_plus_unknown \
Rscript scripts/plot_fastani_matrix_heatmap.R
```

Expected interpreted outputs:

- `ani/reference_panel_plus_unknown_matrix/metrics/fastani_matrix_long.tsv`
- `ani/reference_panel_plus_unknown_matrix/metrics/fastani_genome_matrix.tsv`
- `ani/reference_panel_plus_unknown_matrix/metrics/fastani_species_max_matrix.tsv`
- `ani/reference_panel_plus_unknown_matrix/metrics/fastani_species_mean_matrix.tsv`
- `ani/reference_panel_plus_unknown_matrix/figures/reference_panel_plus_unknown_genome_heatmap.pdf`
- `ani/reference_panel_plus_unknown_matrix/figures/reference_panel_plus_unknown_species_max_heatmap.pdf`

## Unknowns Versus Reference Panel

This compares only the six Buck assemblies against the current reference panel, including Mullis et al. and the newly downloaded references.

```bash
sbatch \
  --export=ALL,STAGE_DIR=ani/unknown_vs_reference_panel,QUERY_MANIFEST=configs/ani_unknown_query_manifest.tsv,REFERENCE_MANIFEST=configs/reference_sequence_manifest.tsv \
  --array=0-5 \
  scripts/fastani_matrix_array.slurm

sbatch \
  --export=ALL,ANI_MODE=matrix,STAGE_DIR=ani/unknown_vs_reference_panel,QUERY_MANIFEST=configs/ani_unknown_query_manifest.tsv,REFERENCE_MANIFEST=configs/reference_sequence_manifest.tsv \
  scripts/fastani_matrix_array.slurm
```

After the matrix job completes, render the focused heatmap:

```bash
module load R/gcc11/4.4.0
STAGE_DIR=ani/unknown_vs_reference_panel \
HEATMAP_PREFIX=unknown_vs_reference_panel \
Rscript scripts/plot_fastani_matrix_heatmap.R
```

Expected interpreted outputs:

- `ani/unknown_vs_reference_panel/metrics/fastani_matrix_long.tsv`
- `ani/unknown_vs_reference_panel/metrics/fastani_genome_matrix.tsv`
- `ani/unknown_vs_reference_panel/figures/unknown_vs_reference_panel_genome_heatmap.pdf`

## Notes

- Blue represents `0` or no FastANI hit, and red represents `100%` identity.
- The six Buck assemblies are highlighted with black outlines and bold labels.
- Run FastANI only through SLURM or an appropriate compute allocation.
