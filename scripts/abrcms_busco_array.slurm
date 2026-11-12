#!/usr/bin/env bash
# Independent bacterial single-copy marker check for 18 depth + 6 full-read assemblies.
# sbatch --array=0-23%4 scripts/abrcms_busco_array.slurm
#SBATCH -J abrcms_busco
#SBATCH -p normal
#SBATCH -t 08:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=32G
#SBATCH -o ani/abrcms_poster/ani/exact_depth_validation_20261112/logs/slurm/busco_%A_%a.out
#SBATCH -e ani/abrcms_poster/ani/exact_depth_validation_20261112/logs/slurm/busco_%A_%a.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?Submit from the project root}"
test -s PROJECT_BRIEF.md
stage=ani/abrcms_poster/ani/exact_depth_validation_20261112
manifest="$stage/reference_coverage_manifest.tsv"
image="$stage/busco_v6.1.0_cv3.sif"
download="$stage/busco_downloads"
test -s "$stage/BUSCO_PREPARE_COMPLETE"
test -s "$manifest"
test -s "$image"
test -s "$download/lineages/bacteria_odb12.2/dataset.cfg"
test -d "$stage/busco"
mapfile -t rows < <(tail -n +2 "$manifest")
test "${#rows[@]}" -eq 24
index="${SLURM_ARRAY_TASK_ID:?Submit as array 0-23}"
(( index >= 0 && index < 24 )) || { echo "Invalid task index $index" >&2; exit 1; }
IFS=$'\t' read -r condition isolate assembly_id assembly_fasta _ <<< "${rows[$index]}"
[[ "$assembly_id" =~ ^Buck_[A-Za-z0-9_-]+$ ]] || { echo "Invalid assembly ID" >&2; exit 1; }
test -s "$assembly_fasta"
out="$stage/busco/$assembly_id"
test ! -e "$out"
mkdir "$out.lock" || { echo "BUSCO already attempted for $assembly_id" >&2; exit 1; }
printf 'condition\t%s\nassembly_id\t%s\nlineage\tbacteria_odb12.2\n' "$condition" "$assembly_id" > "$out.lock/parameters.tsv"
sha256sum "$assembly_fasta" > "$out.lock/assembly_sha256.txt"
singularity exec --cleanenv --bind "$PWD:$PWD" "$image" busco \
  --in "$PWD/$assembly_fasta" \
  --lineage_dataset "$PWD/$download/lineages/bacteria_odb12.2" \
  --out "$assembly_id" --out_path "$PWD/$stage/busco" \
  --mode genome --cpu "${SLURM_CPUS_PER_TASK:-8}" \
  --download_path "$PWD/$download" --offline
test -d "$out"
compgen -G "$out/short_summary*.json" >/dev/null || { echo "Missing BUSCO JSON summary for $assembly_id" >&2; exit 1; }
printf 'PASS\t%s\n' "${SLURM_JOB_ID:-unknown}" > "$out.lock/COMPLETE"
