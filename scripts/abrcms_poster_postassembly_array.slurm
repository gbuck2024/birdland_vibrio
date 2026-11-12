#!/usr/bin/env bash
# Self-map, classify, and add BlobToolKit coverage for one assembled depth condition.
# Submit from the project root with --array=0-17 after all assemblies finish.
#SBATCH -J abrcms_postasm
#SBATCH -p normal
#SBATCH -t 36:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -o ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111/postassembly/logs/slurm/postassembly_%A_%a.out
#SBATCH -e ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111/postassembly/logs/slurm/postassembly_%A_%a.err
set -euo pipefail

cd "${SLURM_SUBMIT_DIR:?Submit from the project root}"
test -s PROJECT_BRIEF.md
stage=ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111
export MANIFEST_FILE=configs/abrcms_poster_depth_20261111_blob.tsv
export STAGE_ROOT="$stage/postassembly"
test -s "$MANIFEST_FILE"
test -s containers/kraken2.sif
test -s kraken2_db/db/hash.k2d
test -d /home/glametrie1/.conda/envs/blobtoolkit
test -n "${SLURM_ARRAY_TASK_ID:-}"
mapfile -t rows < <(tail -n +2 "$MANIFEST_FILE")
test "${#rows[@]}" -eq 18
(( SLURM_ARRAY_TASK_ID >= 0 && SLURM_ARRAY_TASK_ID < 18 ))
IFS=$'\t' read -r short_id sample_id r1 r2 contigs <<< "${rows[$SLURM_ARRAY_TASK_ID]}"
[[ "$short_id" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid short_id: $short_id" >&2; exit 1; }
[[ "$sample_id" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "Invalid sample_id: $sample_id" >&2; exit 1; }
test -s "$r1"
test -s "$r2"
test -s "$contigs"
test "$(basename "$r1")" = "${sample_id}_1_paired.fq.gz"
test "$(basename "$r2")" = "${sample_id}_2_paired.fq.gz"
test "$contigs" = "$stage/assembly/assemblies/$sample_id/contigs.fasta"
test -s "$stage/assembly/assemblies/$sample_id/scaffolds.fasta"
test -s "$stage/metrics/$sample_id.subsampling_metrics.tsv"

mkdir -p "$STAGE_ROOT"
sample_dir="$STAGE_ROOT/$short_id"
mkdir "$sample_dir" # atomic per-condition lock; existing output is never reused
mkdir -p "$sample_dir/metadata"
printf 'sample_id\t%s\nshort_id\t%s\nslurm_job_id\t%s\nmanifest\t%s\n' \
  "$sample_id" "$short_id" "${SLURM_JOB_ID:-unknown}" "$MANIFEST_FILE" \
  > "$sample_dir/metadata/run_parameters.tsv"
sha256sum "$r1" "$r2" "$contigs" > "$sample_dir/metadata/input_checksums.sha256"

bash scripts/blobtoolkit_self_mapping_array.slurm
bash scripts/kraken2_contig_classify_array.slurm
bash scripts/blobtoolkit_add_self_coverage_array.slurm

test -s "$sample_dir/bam/$sample_id.self_contigs.sorted.bam"
test -s "$sample_dir/metrics/$sample_id.self_contigs.reference_name_check.txt"
test -s "$sample_dir/taxonomy/$sample_id.spades_contigs.kraken2.tsv"
test -s "$sample_dir/blobdir/$sample_id.self_contigs.sorted_cov.json"
test ! -e "$sample_dir/COMPLETE"
printf 'PASS\t%s\t%s\n' "$short_id" "$sample_id" > "$sample_dir/COMPLETE"
