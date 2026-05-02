#!/bin/bash
# Subsample Kraken2-filtered Vibrio paired reads to fixed depth targets.
#
# How to run:
# 1. Submit one array task per planned sample-depth subset:
#    sbatch --array=0-8 scripts/subsample_vibrio_reads_array.slurm
# 2. After the array completes, combine runtime metrics:
#    sbatch --export=ALL,SUBSAMPLE_MODE=summary scripts/subsample_vibrio_reads_array.slurm

#SBATCH -J vibrio_subsample
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=8G
#SBATCH -o kraken2_vibrio_subsampled_reads/logs/slurm/vibrio_subsample_%A_%a.out
#SBATCH -e kraken2_vibrio_subsampled_reads/logs/slurm/vibrio_subsample_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MODE="${SUBSAMPLE_MODE:-subsample}"
MANIFEST_FILE="${MANIFEST_FILE:-configs/kraken2_vibrio_subsample_manifest.tsv}"
STAGE_DIR="${STAGE_DIR:-kraken2_vibrio_subsampled_reads}"
METRICS_DIR="${STAGE_DIR}/metrics"
LOG_DIR="${STAGE_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
SUBSAMPLE_SCRIPT="scripts/subsample_paired_fastq.py"
SUMMARY_SCRIPT="scripts/summarize_subsampled_reads.py"

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

mkdir -p "${METRICS_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}"

log "START subsample_vibrio_reads_array.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Mode: ${MODE}"
log "Manifest: ${MANIFEST_FILE}"
log "Stage directory: ${STAGE_DIR}"

require_file "${MANIFEST_FILE}" "Subsampling manifest"
require_file "${SUBSAMPLE_SCRIPT}" "Subsampling script"

if [ "${MODE}" = "summary" ]; then
  require_file "${SUMMARY_SCRIPT}" "Subsampling summary script"
  python3 "${SUMMARY_SCRIPT}" --manifest "${MANIFEST_FILE}" --summary-out "${METRICS_DIR}/subsampling_summary.tsv"
  log "END subsample_vibrio_reads_array.slurm"
  exit 0
fi

if [ "${MODE}" != "subsample" ]; then
  log "ERROR: Unsupported SUBSAMPLE_MODE='${MODE}'. Use 'subsample' or 'summary'." >&2
  exit 1
fi

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit subsample mode with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")

if [ "${#SAMPLE_ROWS[@]}" -eq 0 ]; then
  log "ERROR: Subsampling manifest contains no sample rows." >&2
  exit 1
fi

if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r sample_id subsample_id target_coverage genome_size_assumption read_length_assumption target_read_pairs seed read1 read2 out_read1 out_read2 metrics_out <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"

if [ -z "${sample_id}" ] || [ -z "${subsample_id}" ] || [ -z "${target_coverage}" ] || [ -z "${target_read_pairs}" ] || [ -z "${seed}" ] || [ -z "${read1}" ] || [ -z "${read2}" ] || [ -z "${out_read1}" ] || [ -z "${out_read2}" ] || [ -z "${metrics_out}" ]; then
  log "ERROR: Manifest row ${SLURM_ARRAY_TASK_ID} is malformed." >&2
  exit 1
fi

require_file "${read1}" "Forward filtered read"
require_file "${read2}" "Reverse filtered read"

log "Sample: ${sample_id}"
log "Subsample id: ${subsample_id}"
log "Target coverage: ${target_coverage}"
log "Target read pairs: ${target_read_pairs}"
log "Seed: ${seed}"

python3 "${SUBSAMPLE_SCRIPT}" \
  --sample-id "${sample_id}" \
  --subsample-id "${subsample_id}" \
  --target-coverage "${target_coverage}" \
  --genome-size "${genome_size_assumption}" \
  --read-length "${read_length_assumption}" \
  --target-read-pairs "${target_read_pairs}" \
  --seed "${seed}" \
  --read1 "${read1}" \
  --read2 "${read2}" \
  --out-read1 "${out_read1}" \
  --out-read2 "${out_read2}" \
  --metrics-out "${metrics_out}"

log "END subsample_vibrio_reads_array.slurm"
