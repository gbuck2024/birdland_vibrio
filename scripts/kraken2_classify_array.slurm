#!/bin/bash
# Run paired-end Kraken2 classification for the trimmed read pairs listed in the
# stage manifest. Submit this with SLURM; do not run classification on a login node.
#
# How to run:
# 1. Classify all 6 paired-end samples as an array job:
#    sbatch --array=0-5 scripts/kraken2_classify_array.slurm
# 2. After the array job completes, submit the summary step:
#    sbatch --export=ALL,KRAKEN2_CLASSIFICATION_MODE=summary scripts/kraken2_classify_array.slurm

#SBATCH -J kraken2_classify
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -o kraken2_classification/logs/slurm/kraken2_classify_%A_%a.out
#SBATCH -e kraken2_classification/logs/slurm/kraken2_classify_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MODE="${KRAKEN2_CLASSIFICATION_MODE:-classify}"
MANIFEST_FILE="configs/kraken2_classification_manifest.tsv"
STAGE_DIR="kraken2_classification"
OUTPUT_DIR="${STAGE_DIR}/outputs"
REPORT_DIR="${STAGE_DIR}/reports"
METRICS_DIR="${STAGE_DIR}/metrics"
LOG_DIR="${STAGE_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
DB_DIR="kraken2_db/db"
SUMMARY_SCRIPT="scripts/summarize_kraken2_classification.py"

SINGULARITY_BIN="${SINGULARITY_BIN:-singularity}"
KRAKEN2_THREADS="${SLURM_CPUS_PER_TASK:-8}"
KRAKEN2_MEMORY_MAPPING="${KRAKEN2_MEMORY_MAPPING:-1}"
KRAKEN2_EXTRA_ARGS="${KRAKEN2_EXTRA_ARGS:-}"

if [ -n "${KRAKEN2_SIF:-}" ]; then
  CONTAINER_IMAGE="${KRAKEN2_SIF}"
elif [ -s "${PROJECT_DIR}/containers/kraken2.sif" ]; then
  CONTAINER_IMAGE="${PROJECT_DIR}/containers/kraken2.sif"
else
  CONTAINER_IMAGE="${PROJECT_DIR}/kraken2.sif"
fi

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

run_in_container() {
  local command_text="$1"

  "${SINGULARITY_BIN}" exec \
    --cleanenv \
    --bind "${PROJECT_DIR}:${PROJECT_DIR}" \
    "${CONTAINER_IMAGE}" \
    bash -lc "${command_text}"
}

mkdir -p "${OUTPUT_DIR}" "${REPORT_DIR}" "${METRICS_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}"

log "START kraken2_classify_array.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Mode: ${MODE}"
log "Manifest: ${MANIFEST_FILE}"
log "Database directory: ${DB_DIR}"

require_file "${MANIFEST_FILE}" "Kraken2 classification manifest"
require_file "${DB_DIR}/hash.k2d" "Kraken2 database hash"
require_file "${DB_DIR}/opts.k2d" "Kraken2 database options"
require_file "${DB_DIR}/taxo.k2d" "Kraken2 database taxonomy"
require_file "${CONTAINER_IMAGE}" "Kraken2 container image"

if ! command -v "${SINGULARITY_BIN}" >/dev/null 2>&1; then
  log "ERROR: Required command not found in PATH: ${SINGULARITY_BIN}" >&2
  exit 1
fi

run_in_container "command -v kraken2 >/dev/null 2>&1"

if [ "${MODE}" = "summary" ]; then
  require_file "${SUMMARY_SCRIPT}" "Kraken2 summary parser"
  python3 "${SUMMARY_SCRIPT}"
  log "END kraken2_classify_array.slurm"
  exit 0
fi

if [ "${MODE}" != "classify" ]; then
  log "ERROR: Unsupported KRAKEN2_CLASSIFICATION_MODE='${MODE}'. Use 'classify' or 'summary'." >&2
  exit 1
fi

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit classification mode with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")

if [ "${#SAMPLE_ROWS[@]}" -eq 0 ]; then
  log "ERROR: Kraken2 classification manifest contains no sample rows." >&2
  exit 1
fi

if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r sample_id read1 read2 <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"

if [ -z "${sample_id}" ] || [ -z "${read1}" ] || [ -z "${read2}" ]; then
  log "ERROR: Manifest row ${SLURM_ARRAY_TASK_ID} is malformed." >&2
  exit 1
fi

require_file "${read1}" "Forward trimmed read"
require_file "${read2}" "Reverse trimmed read"

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

memory_map_flag=""
if [ "${KRAKEN2_MEMORY_MAPPING}" = "1" ]; then
  memory_map_flag="--memory-mapping"
fi

sample_output="${OUTPUT_DIR}/${sample_id}.kraken2.tsv"
sample_report="${REPORT_DIR}/${sample_id}.kreport.tsv"

log "Sample: ${sample_id}"
log "Reads: ${read1} ${read2}"
log "Output: ${sample_output}"
log "Report: ${sample_report}"

run_in_container \
  "set -euo pipefail; \
   cd '${PROJECT_DIR}'; \
   kraken2 \
     --db '${DB_DIR}' \
     --paired \
     --gzip-compressed \
     --threads '${KRAKEN2_THREADS}' \
     --use-names \
     ${memory_map_flag} \
     --report '${sample_report}' \
     --output '${sample_output}' \
     ${KRAKEN2_EXTRA_ARGS} \
     '${read1}' '${read2}'"

require_file "${sample_output}" "Kraken2 output"
require_file "${sample_report}" "Kraken2 report"

log "Completed Kraken2 classification for ${sample_id}"
log "END kraken2_classify_array.slurm"
