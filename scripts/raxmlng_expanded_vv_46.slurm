#!/bin/bash
# Run RAxML-NG maximum-likelihood tree search and bootstrap support for the
# expanded 46-genome V. vulnificus Parsnp core-SNP alignment.
# Submit from the project root:
#   sbatch scripts/raxmlng_expanded_vv_46.slurm

#SBATCH -J raxmlng_vv46
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 16
#SBATCH --mem=64G
#SBATCH -o phylogeny/expanded_vv_46/logs/raxmlng_expanded_vv_46_%j.out
#SBATCH -e phylogeny/expanded_vv_46/logs/raxmlng_expanded_vv_46_%j.err

set -euo pipefail

if [[ -n "${SLURM_SUBMIT_DIR:-}" && -s "${SLURM_SUBMIT_DIR}/PROJECT_BRIEF.md" ]]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
cd "${PROJECT_DIR}"

ALIGNMENT="${ALIGNMENT:-phylogeny/expanded_vv_46/alignment/parsnp/parsnp.snps.mblocks}"
OUT_DIR="${OUT_DIR:-phylogeny/expanded_vv_46/tree/raxmlng}"
LOG_DIR="${LOG_DIR:-phylogeny/expanded_vv_46/logs}"
RAXML_CONTAINER="${RAXML_CONTAINER:-containers/raxmlng_2.0.0.sif}"
THREADS="${SLURM_CPUS_PER_TASK:-1}"
PREFIX="${OUT_DIR}/expanded_vv_46"
BEST_TREE="${PREFIX}.raxml.bestTree"
FINAL_TREE="${PREFIX}.raxml.support"
BOOTSTRAPS="${PREFIX}.raxml.bootstraps"
RAXML_LOG="${PREFIX}.raxml.log"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*"
}

require_file() {
  local path="$1"
  local label="$2"

  if [[ ! -s "${path}" ]]; then
    log "ERROR: ${label} missing or empty: ${path}" >&2
    exit 1
  fi
}

log "START raxmlng_expanded_vv_46.slurm"
log "Hostname: $(hostname)"
log "Working directory: ${PROJECT_DIR}"

mkdir -p "${OUT_DIR}" "${LOG_DIR}"

require_file "${ALIGNMENT}" "Parsnp SNP alignment"
require_file "${RAXML_CONTAINER}" "RAxML-NG Singularity container"
if ! command -v singularity >/dev/null 2>&1; then
  log "ERROR: singularity is not available on PATH" >&2
  exit 1
fi

if compgen -G "${PREFIX}.raxml.*" >/dev/null; then
  if [[ "${FORCE:-0}" != "1" ]]; then
    log "ERROR: Existing RAxML-NG outputs found for prefix: ${PREFIX}" >&2
    log "Export FORCE=1 to remove and regenerate those outputs." >&2
    exit 1
  fi
  log "FORCE=1 set; removing existing RAxML-NG outputs for prefix: ${PREFIX}"
  rm -f "${PREFIX}".raxml.*
fi

log "RAxML-NG container: ${RAXML_CONTAINER}"
log "RAxML-NG version:"
singularity exec "${RAXML_CONTAINER}" raxml-ng --version || log "WARNING: Could not print RAxML-NG version"

RAXML_CMD=(
  singularity exec "${RAXML_CONTAINER}" raxml-ng
  --all
  --msa "${ALIGNMENT}"
  --model GTR+G
  --threads "${THREADS}"
  --seed 12345
  --bs-trees 100
  --prefix "${PREFIX}"
)

log "Command: ${RAXML_CMD[*]}"
"${RAXML_CMD[@]}"

require_file "${BEST_TREE}" "Expected RAxML-NG best ML tree"
require_file "${FINAL_TREE}" "Expected RAxML-NG support tree"
require_file "${BOOTSTRAPS}" "Expected RAxML-NG bootstrap trees"
require_file "${RAXML_LOG}" "Expected RAxML-NG log"

log "Verified expected RAxML-NG outputs:"
log "  ${BEST_TREE}"
log "  ${FINAL_TREE}"
log "  ${BOOTSTRAPS}"
log "  ${RAXML_LOG}"
log "END raxmlng_expanded_vv_46.slurm"
