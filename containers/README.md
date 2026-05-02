# Containers

Local Singularity images used by this project should be kept here rather than at
the repository top level.

Current expected image names

- `containers/fastani_latest.sif`
- `containers/kraken2.sif`
- `containers/spades.sif`

Workflow behavior

- `scripts/fastani_array.slurm` prefers `FASTANI_SIF`, then `containers/fastani_latest.sif`
- `scripts/kraken2_build_bacterial_db.slurm` and `scripts/kraken2_classify_array.slurm` prefer `KRAKEN2_SIF`, then `containers/kraken2.sif`
- `scripts/spades_assembly_array.slurm` prefers `SPADES_SIF`, then `containers/spades.sif`

These images are intentionally untracked by Git.
