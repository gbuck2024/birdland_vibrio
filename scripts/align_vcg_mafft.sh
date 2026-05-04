#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

INPUT_FASTA="vcg_mining/extracted_sequences/all_vcg_sequences.fasta"
MAFFT_SIF="containers/mafft_7.525.sif"
OUTPUT_DIR="vcg_mining/alignment"
LOG_DIR="vcg_mining/logs"
OUTPUT_FASTA="${OUTPUT_DIR}/all_vcg_sequences.aligned.fasta"
LOG_FILE="${LOG_DIR}/mafft_vcg.err"

mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"

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

require_nonempty_file "${INPUT_FASTA}" "Input FASTA"
require_nonempty_file "${MAFFT_SIF}" "MAFFT Singularity image"

if ! command -v singularity >/dev/null 2>&1; then
  echo "ERROR: singularity is not available in PATH." >&2
  exit 1
fi

: > "${LOG_FILE}"
log "Testing MAFFT container: ${MAFFT_SIF}" | tee -a "${LOG_FILE}"

if ! singularity exec "${MAFFT_SIF}" mafft --version >> "${LOG_FILE}" 2>&1; then
  echo "ERROR: MAFFT test failed. Log follows:" >&2
  cat "${LOG_FILE}" >&2
  exit 1
fi

tmp_output="${OUTPUT_FASTA}.tmp"
rm -f "${tmp_output}"

log "Running MAFFT alignment on ${INPUT_FASTA}" | tee -a "${LOG_FILE}"

if ! singularity exec "${MAFFT_SIF}" \
  mafft --localpair --maxiterate 1000 "${INPUT_FASTA}" \
  > "${tmp_output}" 2>> "${LOG_FILE}"; then
  echo "ERROR: MAFFT alignment failed. Log follows:" >&2
  cat "${LOG_FILE}" >&2
  rm -f "${tmp_output}"
  exit 1
fi

if [ ! -s "${tmp_output}" ]; then
  echo "ERROR: MAFFT produced an empty alignment output. Log follows:" >&2
  cat "${LOG_FILE}" >&2
  rm -f "${tmp_output}"
  exit 1
fi

mv "${tmp_output}" "${OUTPUT_FASTA}"

printf 'Output FASTA: %s\n' "${OUTPUT_FASTA}"
printf 'File size (bytes): %s\n' "$(stat -c '%s' "${OUTPUT_FASTA}")"
printf 'FASTA headers:\n'
awk '/^>/ {print}' "${OUTPUT_FASTA}"
printf 'Aligned sequence lengths:\n'
awk '
  /^>/ {
    if (header != "") {
      print header "\t" length(sequence)
    }
    header = substr($0, 2)
    sequence = ""
    next
  }
  {
    sequence = sequence $0
  }
  END {
    if (header != "") {
      print header "\t" length(sequence)
    }
  }
' "${OUTPUT_FASTA}"
