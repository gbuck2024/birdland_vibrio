#!/usr/bin/env bash
# Fetch the official BUSCO 6.1.0 container and bacteria_odb12.2 marker dataset.
# sbatch scripts/abrcms_busco_prepare.slurm
#SBATCH -J abrcms_busco_db
#SBATCH -p normal
#SBATCH -t 08:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=16G
#SBATCH -o ani/abrcms_poster/ani/exact_depth_validation_20261112/logs/slurm/busco_prepare_%j.out
#SBATCH -e ani/abrcms_poster/ani/exact_depth_validation_20261112/logs/slurm/busco_prepare_%j.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?Submit from the project root}"
test -s PROJECT_BRIEF.md
stage=ani/abrcms_poster/ani/exact_depth_validation_20261112
image="$stage/busco_v6.1.0_cv3.sif"
download="$stage/busco_downloads"
test -d "$stage/logs/slurm"
test ! -e "$image"
test ! -e "$download"
mkdir "$stage/busco_prepare.lock"
mkdir -p "$stage/singularity_cache" "$stage/singularity_tmp"
export SINGULARITY_CACHEDIR="$PWD/$stage/singularity_cache"
export SINGULARITY_TMPDIR="$PWD/$stage/singularity_tmp"
command -v singularity >/dev/null
singularity pull "$image" docker://ezlabgva/busco:v6.1.0_cv3
test -s "$image"
singularity exec --cleanenv --bind "$PWD:$PWD" "$image" busco --version > "$stage/busco_version.txt"
singularity exec --cleanenv --bind "$PWD:$PWD" "$image" busco --download bacteria_odb12.2 --download_path "$PWD/$download"
test -s "$download/lineages/bacteria_odb12.2/dataset.cfg"
printf 'PASS\t%s\n' "${SLURM_JOB_ID:-unknown}" > "$stage/BUSCO_PREPARE_COMPLETE"
