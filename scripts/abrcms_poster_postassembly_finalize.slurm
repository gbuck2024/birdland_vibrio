#!/usr/bin/env bash
# Build the assembly/read QC and master tables after all 18 postassembly tasks.
#SBATCH -J abrcms_postqc
#SBATCH -p normal
#SBATCH -t 08:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=16G
#SBATCH -o ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111/postassembly/logs/slurm/finalize_%j.out
#SBATCH -e ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111/postassembly/logs/slurm/finalize_%j.err
set -euo pipefail

cd "${SLURM_SUBMIT_DIR:?Submit from the project root}"
test -s PROJECT_BRIEF.md
stage=ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111
post="$stage/postassembly"
manifest=configs/abrcms_poster_depth_20261111_blob.tsv
test -s "$manifest"
mapfile -t rows < <(tail -n +2 "$manifest")
test "${#rows[@]}" -eq 18
for row in "${rows[@]}"; do
  IFS=$'\t' read -r short_id sample_id _ <<< "$row"
  test -s "$post/$short_id/COMPLETE"
done

out="$stage/metrics"
test ! -e "$out/assembly_summary.tsv"
test ! -e "$out/read_bases_and_depth.tsv"
test ! -e "$out/all_conditions.master_contig_table.tsv"
test ! -e "$post/FINALIZE_STARTED"
printf 'job_id\t%s\n' "${SLURM_JOB_ID:-unknown}" > "$post/FINALIZE_STARTED"

MANIFEST_FILE=configs/abrcms_poster_depth_20261111_assembly.tsv \
STAGE_DIR="$stage/assembly" \
SUMMARY_PATH="$out/assembly_summary.tsv" \
python3 scripts/summarize_spades_assemblies.py
python3 scripts/abrcms_poster_read_bases.py \
  --manifest configs/abrcms_poster_depth_20261111_subsample.tsv \
  --output "$out/read_bases_and_depth.tsv"
python3 scripts/build_blobtoolkit_master_contig_tables.py \
  --manifest "$manifest" --stage-root "$post" \
  --combined-output "$out/all_conditions.master_contig_table.tsv"

test -s "$out/assembly_summary.tsv"
test -s "$out/read_bases_and_depth.tsv"
test -s "$out/all_conditions.master_contig_table.tsv"
printf 'PASS\t%s\n' "${SLURM_JOB_ID:-unknown}" > "$post/FINALIZE_COMPLETE"
