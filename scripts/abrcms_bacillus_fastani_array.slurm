#!/usr/bin/env bash
# Reciprocal fastANI for BI0607_2 original + three depth assemblies vs Bacillus.
# sbatch --array=0-3 scripts/abrcms_bacillus_fastani_array.slurm
#SBATCH -J abrcms_bacani
#SBATCH -p normal
#SBATCH -t 02:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=24G
#SBATCH -o ani/abrcms_poster/ani/exact_depth_validation_20261112/logs/slurm/bacani_%A_%a.out
#SBATCH -e ani/abrcms_poster/ani/exact_depth_validation_20261112/logs/slurm/bacani_%A_%a.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?Submit from project root}"
test -s PROJECT_BRIEF.md
stage=ani/abrcms_poster/ani/exact_depth_validation_20261112
manifest="$stage/bacillus_comparison_manifest_v2.tsv"
image=containers/fastani_latest.sif
test -s "$manifest"
test -s "$image"
test -d "$stage/bacillus_fastani"
mapfile -t rows < <(tail -n +2 "$manifest")
test "${#rows[@]}" -eq 4
index="${SLURM_ARRAY_TASK_ID:?Submit as array 0-3}"
(( index >= 0 && index < 4 )) || { echo "Invalid array index" >&2; exit 1; }
IFS=$'\t' read -r condition isolate assembly_id assembly_fasta reference_id reference_fasta <<< "${rows[$index]}"
[[ "$assembly_id" =~ ^Buck_BI0607_2_[A-Za-z0-9_-]+$ ]] || { echo "Unexpected assembly ID" >&2; exit 1; }
test -s "$assembly_fasta"
test -s "$reference_fasta"
out="$stage/bacillus_fastani/$assembly_id"
mkdir "$out" || { echo "Output exists or already attempted: $out" >&2; exit 1; }
sha256sum "$assembly_fasta" "$reference_fasta" > "$out/input_sha256.txt"
printf 'condition\t%s\nassembly_id\t%s\nreference_id\t%s\n' "$condition" "$assembly_id" "$reference_id" > "$out/parameters.tsv"
run_fastani() {
  singularity exec --cleanenv --bind "$PWD:$PWD" "$image" fastANI \
    --query "$PWD/$1" --ref "$PWD/$2" --output "$PWD/$3" \
    --threads "${SLURM_CPUS_PER_TASK:-8}" --fragLen 3000 --kmer 16 --minFraction 0.2
}
run_fastani "$assembly_fasta" "$reference_fasta" "$out/forward.tsv"
run_fastani "$reference_fasta" "$assembly_fasta" "$out/reverse.tsv"
test -e "$out/forward.tsv"
test -e "$out/reverse.tsv"
printf 'PASS\t%s\n' "${SLURM_JOB_ID:-unknown}" > "$out/COMPLETE"
