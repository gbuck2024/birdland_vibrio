# SRA Reciprocal Reference-to-SRA ANI/AF Stage

This stage supplies the reverse fastANI direction needed to report reciprocal alignment fraction for the six SRA species assignments.

The already completed `ani/sra_vs_reference_panel` matrix provides SRA-to-reference ANI and AF. This reverse stage uses the selected best reference genomes as queries and the six SRA assemblies as references, then `scripts/summarize_sra_reciprocal_ani_af.py` combines both directions.

## Inputs

- Reverse query manifest: `configs/ani_reciprocal_reference_query_manifest_sra.tsv`
- SRA reference manifest: `configs/ani_query_manifest_sra.tsv`
- Forward ANI matrix: `ani/sra_vs_reference_panel/metrics/fastani_matrix_long.tsv`

## Submit Reverse Comparisons

There are five unique best reference genomes, so use array range `0-4`:

```bash
sbatch \
  -o ani/sra_reciprocal_reference_to_sra/logs/slurm/fastani_reciprocal_%A_%a.out \
  -e ani/sra_reciprocal_reference_to_sra/logs/slurm/fastani_reciprocal_%A_%a.err \
  --export=ALL,STAGE_DIR=ani/sra_reciprocal_reference_to_sra,QUERY_MANIFEST=configs/ani_reciprocal_reference_query_manifest_sra.tsv,REFERENCE_MANIFEST=configs/ani_query_manifest_sra.tsv \
  --array=0-4 \
  scripts/fastani_matrix_array.slurm
```

## Summarize Reverse Matrix

```bash
sbatch \
  -o ani/sra_reciprocal_reference_to_sra/logs/slurm/fastani_reciprocal_summary_%j.out \
  -e ani/sra_reciprocal_reference_to_sra/logs/slurm/fastani_reciprocal_summary_%j.err \
  --export=ALL,ANI_MODE=matrix,STAGE_DIR=ani/sra_reciprocal_reference_to_sra,QUERY_MANIFEST=configs/ani_reciprocal_reference_query_manifest_sra.tsv,REFERENCE_MANIFEST=configs/ani_query_manifest_sra.tsv \
  scripts/fastani_matrix_array.slurm
```

## Combine Reciprocal AF

After the reverse matrix summary exists:

```bash
python3 scripts/summarize_sra_reciprocal_ani_af.py
```

Expected combined outputs:

- `ani/sra_vs_reference_panel/metrics/sra_reciprocal_ani_af_summary.tsv`
- `ani/sra_vs_reference_panel/metrics/sra_reciprocal_ani_af_summary.md`
