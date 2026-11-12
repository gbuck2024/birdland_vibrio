#!/usr/bin/env bash
# Align each of 24 exact assembly conditions to its selected external reference.
# Submit after all four ANI panels and the coverage manifest have been validated.
# sbatch --array=0-23%4 scripts/abrcms_reference_coverage_array.slurm
#SBATCH -J abrcms_refcov
#SBATCH -p normal
#SBATCH -t 04:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=24G
#SBATCH -o ani/abrcms_poster/ani/exact_depth_validation_20261112/logs/slurm/refcov_%A_%a.out
#SBATCH -e ani/abrcms_poster/ani/exact_depth_validation_20261112/logs/slurm/refcov_%A_%a.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?Submit from the project root}"
test -s PROJECT_BRIEF.md
stage=ani/abrcms_poster/ani/exact_depth_validation_20261112
manifest="${COVERAGE_MANIFEST:-$stage/reference_coverage_manifest.tsv}"
output_root="${COVERAGE_OUTPUT_ROOT:-$stage/coverage}"
test -s "$manifest"
test -d "$output_root"
mapfile -t rows < <(tail -n +2 "$manifest")
test "${#rows[@]}" -eq 24
index="${SLURM_ARRAY_TASK_ID:?Submit as array 0-23}"
(( index >= 0 && index < 24 )) || { echo "Invalid task index $index" >&2; exit 1; }
IFS=$'\t' read -r condition isolate assembly_id assembly_fasta reference_id reference_fasta _ <<< "${rows[$index]}"
[[ "$assembly_id" =~ ^Buck_[A-Za-z0-9_-]+$ ]] || { echo "Invalid assembly ID" >&2; exit 1; }
test -s "$assembly_fasta"
test -s "$reference_fasta"
module load minimap2/gcc11/2.28
command -v minimap2 >/dev/null
out="$output_root/$assembly_id"
mkdir "$out" || { echo "Output exists or run already attempted: $out" >&2; exit 1; }
minimap2 --version > "$out/minimap2_version.txt"
sha256sum "$assembly_fasta" "$reference_fasta" > "$out/input_sha256.txt"
printf 'condition\t%s\nassembly_id\t%s\nreference_id\t%s\n' "$condition" "$assembly_id" "$reference_id" > "$out/parameters.tsv"
minimap2 -x asm10 -c --secondary=no -t "${SLURM_CPUS_PER_TASK:-8}" "$reference_fasta" "$assembly_fasta" > "$out/primary.paf"
python3 scripts/summarize_abrcms_reference_paf.py --reference "$reference_fasta" --paf "$out/primary.paf" --output "$out/reference_coverage.tsv"
test -s "$out/reference_coverage.tsv"
printf 'PASS\t%s\n' "${SLURM_JOB_ID:-unknown}" > "$out/COMPLETE"
