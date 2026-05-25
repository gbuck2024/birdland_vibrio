#!/bin/bash
# Filter ambiguous isolate read pairs using existing Kraken2 per-read output.
# Submit as: sbatch --array=0-2 scripts/filter_taxon_reads_array.slurm

#SBATCH -J taxon_filter_reads
#SBATCH -p normal
#SBATCH -t 12:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem=32G
#SBATCH -o ambiguous_isolate_resolution/taxonomic_filtering/logs/filter_taxon_reads_%A_%a.out
#SBATCH -e ambiguous_isolate_resolution/taxonomic_filtering/logs/filter_taxon_reads_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MANIFEST_FILE="${MANIFEST_FILE:-configs/taxon_filter_manifest.tsv}"
STAGE_DIR="ambiguous_isolate_resolution/taxonomic_filtering"
SCRIPT="scripts/filter_fastq_by_kraken_taxon.py"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

log() {
  echo "[$(timestamp)] $*"
}

require_file() {
  local path="$1"
  local label="$2"
  if [ ! -s "${path}" ]; then
    log "ERROR: ${label} missing or empty: ${path}" >&2
    exit 1
  fi
}

mkdir -p \
  "${STAGE_DIR}/logs" \
  "${STAGE_DIR}/read_ids" \
  "${STAGE_DIR}/filtered_reads" \
  "${STAGE_DIR}/metrics"

require_file "${MANIFEST_FILE}" "Taxon filter manifest"
require_file "${SCRIPT}" "Taxon filter Python script"

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")
if [ "${#SAMPLE_ROWS[@]}" -eq 0 ]; then
  log "ERROR: Manifest contains no sample rows." >&2
  exit 1
fi
if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r sample_id r1 r2 kraken_output kraken_report target_taxon_name target_taxid filter_mode downsample_pairs <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"

require_file "${r1}" "R1 trimmed read"
require_file "${r2}" "R2 trimmed read"
require_file "${kraken_output}" "Kraken2 per-read output"
require_file "${kraken_report}" "Kraken2 report"

out_r1="${STAGE_DIR}/filtered_reads/${sample_id}.${target_taxon_name}.R1.filtered.fq.gz"
out_r2="${STAGE_DIR}/filtered_reads/${sample_id}.${target_taxon_name}.R2.filtered.fq.gz"
read_ids="${STAGE_DIR}/read_ids/${sample_id}.${target_taxon_name}.read_ids.txt"
summary="${STAGE_DIR}/metrics/${sample_id}.${target_taxon_name}.filter_summary.tsv"

log "Sample: ${sample_id}"
log "Target taxon: ${target_taxon_name} (${target_taxid}); mode=${filter_mode}"
log "Writing filtered reads to: ${out_r1} ${out_r2}"

python3 "${SCRIPT}" \
  --sample-id "${sample_id}" \
  --r1 "${r1}" \
  --r2 "${r2}" \
  --kraken-output "${kraken_output}" \
  --target-taxid "${target_taxid}" \
  --include-descendants \
  --out-r1 "${out_r1}" \
  --out-r2 "${out_r2}" \
  --read-id-out "${read_ids}" \
  --summary-out "${summary}"

require_file "${out_r1}" "Filtered R1 output"
require_file "${out_r2}" "Filtered R2 output"
require_file "${read_ids}" "Target read ID output"
require_file "${summary}" "Filter summary"

log "Completed taxon filtering for ${sample_id}"
