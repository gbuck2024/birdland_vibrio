#!/bin/bash
# Retain Kraken2-classified Vibrio paired reads for the strongest V. vulnificus
# candidates. Submit this as a SLURM array job; do not run large FASTQ filtering
# on a login node.
#
# How to run:
# 1. Filter the 3 candidate samples:
#    sbatch --array=0-2 scripts/kraken2_vibrio_filter_array.slurm
# 2. After the array completes, generate the combined summary:
#    sbatch --export=ALL,KRAKEN2_VIBRIO_FILTER_MODE=summary scripts/kraken2_vibrio_filter_array.slurm

#SBATCH -J kraken2_vibrio_filter
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem=32G
#SBATCH -o kraken2_vibrio_read_filtering/logs/slurm/kraken2_vibrio_filter_%A_%a.out
#SBATCH -e kraken2_vibrio_read_filtering/logs/slurm/kraken2_vibrio_filter_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MODE="${KRAKEN2_VIBRIO_FILTER_MODE:-filter}"
MANIFEST_FILE="${MANIFEST_FILE:-configs/kraken2_vibrio_filter_manifest.tsv}"
STAGE_DIR="${STAGE_DIR:-kraken2_vibrio_read_filtering}"
FILTERED_READS_DIR="${STAGE_DIR}/filtered_reads"
METRICS_DIR="${STAGE_DIR}/metrics"
LOG_DIR="${STAGE_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
FILTER_SCRIPT="scripts/filter_kraken2_vibrio_reads.py"
SUMMARY_SCRIPT="scripts/summarize_kraken2_vibrio_filtering.py"
VIBRIO_GENUS_TAXID="${VIBRIO_GENUS_TAXID:-662}"

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

mkdir -p "${FILTERED_READS_DIR}" "${METRICS_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}"

log "START kraken2_vibrio_filter_array.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Mode: ${MODE}"
log "Manifest: ${MANIFEST_FILE}"
log "Stage directory: ${STAGE_DIR}"
log "Vibrio genus taxid: ${VIBRIO_GENUS_TAXID}"

require_file "${MANIFEST_FILE}" "Kraken2 Vibrio filtering manifest"
require_file "${FILTER_SCRIPT}" "Kraken2 Vibrio filtering Python script"

if [ "${MODE}" = "summary" ]; then
  require_file "${SUMMARY_SCRIPT}" "Kraken2 Vibrio summary script"
  python3 "${SUMMARY_SCRIPT}"
  log "END kraken2_vibrio_filter_array.slurm"
  exit 0
fi

if [ "${MODE}" != "filter" ]; then
  log "ERROR: Unsupported KRAKEN2_VIBRIO_FILTER_MODE='${MODE}'. Use 'filter' or 'summary'." >&2
  exit 1
fi

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit filter mode with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")

if [ "${#SAMPLE_ROWS[@]}" -eq 0 ]; then
  log "ERROR: Filtering manifest contains no sample rows." >&2
  exit 1
fi

if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r sample_id read1 read2 kraken_output kraken_report <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"

if [ -z "${sample_id}" ] || [ -z "${read1}" ] || [ -z "${read2}" ] || [ -z "${kraken_output}" ] || [ -z "${kraken_report}" ]; then
  log "ERROR: Manifest row ${SLURM_ARRAY_TASK_ID} is malformed." >&2
  exit 1
fi

require_file "${read1}" "Forward trimmed read"
require_file "${read2}" "Reverse trimmed read"
require_file "${kraken_output}" "Kraken2 output"
require_file "${kraken_report}" "Kraken2 report"

read1_base="$(basename "${read1}")"
read2_base="$(basename "${read2}")"

if [[ "${read1_base}" != *_1_paired.fq.gz ]]; then
  log "ERROR: R1 file does not match expected _1_paired.fq.gz suffix: ${read1}" >&2
  exit 1
fi

if [[ "${read2_base}" != *_2_paired.fq.gz ]]; then
  log "ERROR: R2 file does not match expected _2_paired.fq.gz suffix: ${read2}" >&2
  exit 1
fi

read1_prefix="${read1_base%_1_paired.fq.gz}"
read2_prefix="${read2_base%_2_paired.fq.gz}"

if [ "${read1_prefix}" != "${read2_prefix}" ] || [ "${sample_id}" != "${read1_prefix}" ]; then
  log "ERROR: Read pairing or sample naming mismatch for manifest row ${SLURM_ARRAY_TASK_ID}." >&2
  exit 1
fi

filtered_read1="${FILTERED_READS_DIR}/${sample_id}_1_paired.fq.gz"
filtered_read2="${FILTERED_READS_DIR}/${sample_id}_2_paired.fq.gz"
metrics_out="${METRICS_DIR}/${sample_id}.filtering_metrics.tsv"

log "Sample: ${sample_id}"
log "Input reads: ${read1} ${read2}"
log "Kraken2 files: ${kraken_output} ${kraken_report}"
log "Filtered reads: ${filtered_read1} ${filtered_read2}"
log "Metrics: ${metrics_out}"

python3 "${FILTER_SCRIPT}" \
  --sample-id "${sample_id}" \
  --read1 "${read1}" \
  --read2 "${read2}" \
  --kraken-output "${kraken_output}" \
  --kraken-report "${kraken_report}" \
  --out-read1 "${filtered_read1}" \
  --out-read2 "${filtered_read2}" \
  --metrics-out "${metrics_out}" \
  --vibrio-genus-taxid "${VIBRIO_GENUS_TAXID}"

require_file "${filtered_read1}" "Filtered forward read output"
require_file "${filtered_read2}" "Filtered reverse read output"
require_file "${metrics_out}" "Per-sample filtering metrics"

log "Completed Kraken2-guided Vibrio read filtering for ${sample_id}"
log "END kraken2_vibrio_filter_array.slurm"
