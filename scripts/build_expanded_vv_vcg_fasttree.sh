#!/usr/bin/env bash
# Build a nucleotide FastTree from the expanded 46-genome vcg MAFFT alignment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

INPUT_FASTA="${INPUT_FASTA:-phylogeny/expanded_vv_46/vcg_tree/alignment/expanded_vv_46_vcg_mafft.fasta}"
OUTPUT_DIR="phylogeny/expanded_vv_46/vcg_tree/tree"
OUTPUT_TREE="${OUTPUT_DIR}/expanded_vv_46_vcg.fasttree.nwk"
LOG_FILE="${OUTPUT_DIR}/expanded_vv_46_vcg.fasttree.log"
FASTTREE_SIF="${FASTTREE_SIF:-containers/fasttree_2.2.0.sif}"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

log() {
  echo "[$(timestamp)] $*"
}

require_nonempty_file() {
  local path="$1"
  local label="$2"
  if [ ! -s "${path}" ]; then
    echo "ERROR: ${label} is missing or empty: ${path}" >&2
    exit 1
  fi
}

initialize_modules() {
  if command -v module >/dev/null 2>&1; then
    return 0
  fi
  if [ -r /etc/profile.d/modules.sh ]; then
    # shellcheck disable=SC1091
    source /etc/profile.d/modules.sh
  elif [ -r /usr/share/Modules/init/bash ]; then
    # shellcheck disable=SC1091
    source /usr/share/Modules/init/bash
  fi
  command -v module >/dev/null 2>&1
}

resolve_fasttree() {
  if command -v FastTree >/dev/null 2>&1; then
    FASTTREE_CMD=(FastTree)
    return 0
  fi
  if command -v fasttree >/dev/null 2>&1; then
    FASTTREE_CMD=(fasttree)
    return 0
  fi
  if initialize_modules; then
    for module_name in fasttree/2.1.11 fasttree FastTree; do
      if module load "${module_name}" >/dev/null 2>&1; then
        if command -v FastTree >/dev/null 2>&1; then
          FASTTREE_CMD=(FastTree)
          log "Loaded FastTree via environment module '${module_name}'."
          return 0
        fi
        if command -v fasttree >/dev/null 2>&1; then
          FASTTREE_CMD=(fasttree)
          log "Loaded FastTree via environment module '${module_name}'."
          return 0
        fi
      fi
    done
  fi
  if [ -s "${FASTTREE_SIF}" ] && command -v singularity >/dev/null 2>&1; then
    FASTTREE_CMD=(singularity exec "${FASTTREE_SIF}" FastTree)
    return 0
  fi
  return 1
}

mkdir -p "${OUTPUT_DIR}"
require_nonempty_file "${INPUT_FASTA}" "Input VCG alignment"

if ! grep -q '^>' "${INPUT_FASTA}"; then
  echo "ERROR: Input alignment has no FASTA headers: ${INPUT_FASTA}" >&2
  exit 1
fi

if ! resolve_fasttree; then
  echo "ERROR: FastTree is not available as a module/PATH executable, and no usable container was found at ${FASTTREE_SIF}." >&2
  echo "Load a FastTree module, put FastTree on PATH, or provide FASTTREE_SIF=/path/to/fasttree.sif." >&2
  exit 1
fi

: > "${LOG_FILE}"
tmp_tree="${OUTPUT_TREE}.tmp"
rm -f "${tmp_tree}"

log "FastTree command: ${FASTTREE_CMD[*]}" | tee -a "${LOG_FILE}" >&2
log "Input alignment: ${INPUT_FASTA}" | tee -a "${LOG_FILE}" >&2
log "Output tree: ${OUTPUT_TREE}" | tee -a "${LOG_FILE}" >&2

if ! "${FASTTREE_CMD[@]}" -nt -gtr "${INPUT_FASTA}" > "${tmp_tree}" 2>> "${LOG_FILE}"; then
  echo "ERROR: FastTree failed. Log follows:" >&2
  cat "${LOG_FILE}" >&2
  rm -f "${tmp_tree}"
  exit 1
fi

require_nonempty_file "${tmp_tree}" "Temporary FastTree output"
mv "${tmp_tree}" "${OUTPUT_TREE}"

printf 'Output tree: %s\n' "${OUTPUT_TREE}"
printf 'Log file: %s\n' "${LOG_FILE}"
