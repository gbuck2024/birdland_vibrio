#!/usr/bin/env bash
# Align expanded 46-genome vcg sequences with the local MAFFT container.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

INPUT_FASTA="${INPUT_FASTA:-phylogeny/expanded_vv_46/vcg_tree/extracted_sequences/expanded_vv_46_vcg_sequences.fasta}"
MAFFT_SIF="${MAFFT_SIF:-containers/mafft_7.525.sif}"
OUTPUT_DIR="phylogeny/expanded_vv_46/vcg_tree/alignment"
LOG_DIR="phylogeny/expanded_vv_46/vcg_tree/logs"
OUTPUT_FASTA="${OUTPUT_DIR}/expanded_vv_46_vcg_mafft.fasta"
LOG_FILE="${LOG_DIR}/expanded_vv_46_vcg_mafft.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*"
}

require_nonempty_file() {
  local path="$1"
  local label="$2"
  if [ ! -s "${path}" ]; then
    echo "ERROR: ${label} is missing or empty: ${path}" >&2
    exit 1
  fi
}

mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"
require_nonempty_file "${INPUT_FASTA}" "Input VCG FASTA"

if [ ! -s "${MAFFT_SIF}" ]; then
  echo "ERROR: MAFFT container is missing or empty: ${MAFFT_SIF}" >&2
  echo "Provide containers/mafft_7.525.sif or rerun with MAFFT_SIF=/path/to/mafft.sif." >&2
  exit 1
fi

if ! command -v singularity >/dev/null 2>&1; then
  echo "ERROR: singularity is not available in PATH; required to run ${MAFFT_SIF}." >&2
  exit 1
fi

: > "${LOG_FILE}"
tmp_output="${OUTPUT_FASTA}.tmp"
rm -f "${tmp_output}"

log "Testing MAFFT container: ${MAFFT_SIF}" | tee -a "${LOG_FILE}"
if ! singularity exec "${MAFFT_SIF}" mafft --version >> "${LOG_FILE}" 2>&1; then
  echo "ERROR: MAFFT container test failed. Log follows:" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

log "Running MAFFT alignment on ${INPUT_FASTA}" | tee -a "${LOG_FILE}"
if ! singularity exec "${MAFFT_SIF}" \
  mafft --localpair --maxiterate 1000 "${INPUT_FASTA}" \
  > "${tmp_output}" 2>> "${LOG_FILE}"; then
  echo "ERROR: MAFFT alignment failed. Log follows:" >&2
  cat "${LOG_FILE}" >&2
  rm -f "${tmp_output}"
  exit 1
fi

require_nonempty_file "${tmp_output}" "Temporary MAFFT output"
mv "${tmp_output}" "${OUTPUT_FASTA}"

printf 'Output alignment: %s\n' "${OUTPUT_FASTA}"
printf 'Log file: %s\n' "${LOG_FILE}"
printf 'Aligned sequence count: %s\n' "$(grep -c '^>' "${OUTPUT_FASTA}")"
