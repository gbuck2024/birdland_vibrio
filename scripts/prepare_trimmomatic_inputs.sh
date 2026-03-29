#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RAW_DIR="${PROJECT_DIR}/fq_raw"
STEP_DIR="${PROJECT_DIR}/trimmomatic"
COPY_DIR="${STEP_DIR}/copied_reads"
LOG_DIR="${STEP_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
METRICS_DIR="${STEP_DIR}/metrics"
LOG_FILE="${LOG_DIR}/prepare_trimmomatic_inputs.log"
MANIFEST_FILE="${METRICS_DIR}/trimmomatic_input_manifest.tsv"

mkdir -p "${COPY_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}" "${METRICS_DIR}"
touch "${LOG_FILE}"

log() {
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "[${timestamp}] $*" | tee -a "${LOG_FILE}"
}

log "START prepare_trimmomatic_inputs.sh"
log "Project directory: ${PROJECT_DIR}"
log "Raw read directory: ${RAW_DIR}"
log "Copy directory: ${COPY_DIR}"
log "Manifest path: ${MANIFEST_FILE}"

shopt -s nullglob
R1_FILES=("${RAW_DIR}"/*_L7_1.fq.gz)

if [ "${#R1_FILES[@]}" -eq 0 ]; then
  log "ERROR: No forward read files matching *_L7_1.fq.gz were found."
  exit 1
fi

TMP_MANIFEST="$(mktemp "${METRICS_DIR}/trimmomatic_input_manifest.tmp.XXXXXX")"
printf "sample_id\traw_r1\traw_r2\tcopy_r1\tcopy_r2\traw_r1_bytes\traw_r2_bytes\n" > "${TMP_MANIFEST}"

PAIR_COUNT=0

for raw_r1 in "${R1_FILES[@]}"; do
  sample_id="$(basename "${raw_r1}" "_L7_1.fq.gz")"
  raw_r2="${RAW_DIR}/${sample_id}_L7_2.fq.gz"

  if [ ! -f "${raw_r2}" ]; then
    log "ERROR: Missing reverse read for sample ${sample_id}: ${raw_r2}"
    rm -f "${TMP_MANIFEST}"
    exit 1
  fi

  copy_r1="${COPY_DIR}/$(basename "${raw_r1}")"
  copy_r2="${COPY_DIR}/$(basename "${raw_r2}")"

  if [ -f "${copy_r1}" ] && [ -f "${copy_r2}" ]; then
    log "Copies already present for ${sample_id}; leaving existing files in place."
  else
    log "Copying paired reads for ${sample_id}"
    cp -an --reflink=auto "${raw_r1}" "${copy_r1}"
    cp -an --reflink=auto "${raw_r2}" "${copy_r2}"
  fi

  if [ ! -s "${copy_r1}" ] || [ ! -s "${copy_r2}" ]; then
    log "ERROR: Copied files are missing or empty for ${sample_id}"
    rm -f "${TMP_MANIFEST}"
    exit 1
  fi

  raw_r1_bytes="$(stat -c '%s' "${raw_r1}")"
  raw_r2_bytes="$(stat -c '%s' "${raw_r2}")"
  copy_r1_bytes="$(stat -c '%s' "${copy_r1}")"
  copy_r2_bytes="$(stat -c '%s' "${copy_r2}")"

  if [ "${raw_r1_bytes}" -ne "${copy_r1_bytes}" ] || [ "${raw_r2_bytes}" -ne "${copy_r2_bytes}" ]; then
    log "ERROR: Byte-size mismatch detected after copy for ${sample_id}"
    rm -f "${TMP_MANIFEST}"
    exit 1
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "${sample_id}" \
    "${raw_r1}" \
    "${raw_r2}" \
    "${copy_r1}" \
    "${copy_r2}" \
    "${raw_r1_bytes}" \
    "${raw_r2_bytes}" >> "${TMP_MANIFEST}"

  PAIR_COUNT=$((PAIR_COUNT + 1))
done

mv "${TMP_MANIFEST}" "${MANIFEST_FILE}"
log "Validated and documented ${PAIR_COUNT} paired-end samples."
log "Array range for trimming job: 0-$((PAIR_COUNT - 1))"
log "END prepare_trimmomatic_inputs.sh"
