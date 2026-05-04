#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

INPUT_FASTA="vcg_mining/alignment/all_vcg_sequences.aligned.fasta"
OUTPUT_DIR="vcg_mining/tree"
OUTPUT_TREE="${OUTPUT_DIR}/all_vcg_sequences.fasttree.nwk"
LOG_FILE="${OUTPUT_DIR}/all_vcg_sequences.fasttree.log"

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

load_module_if_available() {
  if ! type module >/dev/null 2>&1; then
    if [ -s /etc/profile.d/modules.sh ]; then
      # Some non-interactive shells need the module function initialized.
      # shellcheck disable=SC1091
      source /etc/profile.d/modules.sh
    fi
  fi

  if type module >/dev/null 2>&1; then
    module load fasttree/2.1.11 >/dev/null 2>&1 || module load fasttree >/dev/null 2>&1 || true
  fi
}

resolve_fasttree() {
  if command -v FastTree >/dev/null 2>&1; then
    command -v FastTree
    return 0
  fi

  if command -v fasttree >/dev/null 2>&1; then
    command -v fasttree
    return 0
  fi

  load_module_if_available

  if command -v FastTree >/dev/null 2>&1; then
    command -v FastTree
    return 0
  fi

  if command -v fasttree >/dev/null 2>&1; then
    command -v fasttree
    return 0
  fi

  return 1
}

mkdir -p "${OUTPUT_DIR}"
require_nonempty_file "${INPUT_FASTA}" "Input alignment"

if ! FASTTREE_BIN="$(resolve_fasttree)"; then
  echo "ERROR: FastTree is not available on PATH and could not be loaded from a module." >&2
  exit 1
fi

: > "${LOG_FILE}"
tmp_tree="${OUTPUT_TREE}.tmp"
rm -f "${tmp_tree}"

log "FastTree executable: ${FASTTREE_BIN}" | tee -a "${LOG_FILE}" >&2
log "Input alignment: ${INPUT_FASTA}" | tee -a "${LOG_FILE}" >&2
log "Output tree: ${OUTPUT_TREE}" | tee -a "${LOG_FILE}" >&2

if ! "${FASTTREE_BIN}" -nt "${INPUT_FASTA}" > "${tmp_tree}" 2>> "${LOG_FILE}"; then
  echo "ERROR: FastTree failed. Log follows:" >&2
  cat "${LOG_FILE}" >&2
  rm -f "${tmp_tree}"
  exit 1
fi

if [ ! -s "${tmp_tree}" ]; then
  echo "ERROR: FastTree produced an empty tree. Log follows:" >&2
  cat "${LOG_FILE}" >&2
  rm -f "${tmp_tree}"
  exit 1
fi

mv "${tmp_tree}" "${OUTPUT_TREE}"
require_nonempty_file "${OUTPUT_TREE}" "Output tree"

printf 'Output tree: %s\n' "${OUTPUT_TREE}"
printf 'Log file: %s\n' "${LOG_FILE}"
printf 'Tree size (bytes): %s\n' "$(stat -c '%s' "${OUTPUT_TREE}")"
