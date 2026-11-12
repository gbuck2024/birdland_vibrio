#!/bin/bash
# Downsample original trimmed Buck read pairs into a fresh ABRCMS poster stage.
# Submit from project root with --array=0-17 after creating the logs/slurm dir.
#SBATCH -J abrcms_depth
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=16G
#SBATCH -o ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111/logs/slurm/downsample_%A_%a.out
#SBATCH -e ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111/logs/slurm/downsample_%A_%a.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?Submit from project root}"
test -s PROJECT_BRIEF.md
manifest=configs/abrcms_poster_depth_20261111_subsample.tsv
test -s "$manifest"
test -n "${SLURM_ARRAY_TASK_ID:-}"
mapfile -t rows < <(tail -n +2 "$manifest")
(( SLURM_ARRAY_TASK_ID >= 0 && SLURM_ARRAY_TASK_ID < ${#rows[@]} ))
IFS=$'\t' read -r sample_id run_id depth genome_bp read_bp pairs seed r1 r2 out1 out2 metrics <<< "${rows[$SLURM_ARRAY_TASK_ID]}"
test -s "$r1"
test -s "$r2"
test ! -e "$out1"
test ! -e "$out2"
test ! -e "$metrics"
read_dir=$(dirname "$out1")
test "$(dirname "$out2")" = "$read_dir"
mkdir "$read_dir" # exclusive run lock; a rerun fails before writing FASTQs
python3 scripts/subsample_paired_fastq.py \
  --sample-id "$sample_id" --subsample-id "$run_id" \
  --target-coverage "$depth" --genome-size "$genome_bp" \
  --read-length "$read_bp" --target-read-pairs "$pairs" --seed "$seed" \
  --read1 "$r1" --read2 "$r2" --out-read1 "$out1" --out-read2 "$out2" \
  --metrics-out "$metrics"
test -s "$out1"
test -s "$out2"
test -s "$metrics"
