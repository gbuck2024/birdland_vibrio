#!/bin/bash
# Run Parsnp core-genome alignment for the expanded 46-genome V. vulnificus panel.
# Submit from the project root after input staging:
#   bash scripts/prepare_expanded_vv_parsnp_inputs.sh
#   sbatch scripts/parsnp_expanded_vv_46.slurm

#SBATCH -J parsnp_vv46
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 16
#SBATCH --mem=64G
#SBATCH -o phylogeny/expanded_vv_46/logs/slurm/parsnp_expanded_vv_46_%j.out
#SBATCH -e phylogeny/expanded_vv_46/logs/slurm/parsnp_expanded_vv_46_%j.err

set -euo pipefail

if [[ -n "${SLURM_SUBMIT_DIR:-}" && -s "${SLURM_SUBMIT_DIR}/PROJECT_BRIEF.md" ]]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
cd "${PROJECT_DIR}"

STAGE_DIR="${STAGE_DIR:-phylogeny/expanded_vv_46}"
MANIFEST="${MANIFEST:-configs/expanded_vv_46_genome_manifest.tsv}"
GENOME_DIR="${STAGE_DIR}/genomes"
ALIGNMENT_DIR="${STAGE_DIR}/alignment"
PARSNP_OUT="${ALIGNMENT_DIR}/parsnp"
LOG_DIR="${STAGE_DIR}/logs"
METADATA_DIR="${STAGE_DIR}/metadata"
REFERENCE_RECORD="${METADATA_DIR}/parsnp_reference.txt"
PARSNP_PARAMS="${METADATA_DIR}/parsnp_parameters.tsv"
PARSNP_THREADS="${SLURM_CPUS_PER_TASK:-16}"
PARSNP_CONTAINER="${PARSNP_CONTAINER:-containers/parsnp_2.1.5.sif}"

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

require_dir() {
  local path="$1"
  local label="$2"

  if [[ ! -d "${path}" ]]; then
    log "ERROR: ${label} missing: ${path}" >&2
    exit 1
  fi
}

log "START parsnp_expanded_vv_46.slurm"
log "Project directory: ${PROJECT_DIR}"

mkdir -p "${LOG_DIR}/slurm" "${METADATA_DIR}" "${ALIGNMENT_DIR}"

require_file "${MANIFEST}" "Expanded V. vulnificus manifest"
require_file "${PARSNP_CONTAINER}" "Parsnp Singularity container"
if ! command -v singularity >/dev/null 2>&1; then
  log "ERROR: singularity is not available on PATH" >&2
  exit 1
fi

bash scripts/prepare_expanded_vv_parsnp_inputs.sh

require_dir "${GENOME_DIR}" "Staged genome directory"
require_file "${REFERENCE_RECORD}" "Parsnp reference record"

staged_count="$(find "${GENOME_DIR}" -maxdepth 1 \( -type f -o -type l \) -name '*.fna' | wc -l)"
if [[ "${staged_count}" -ne 46 ]]; then
  log "ERROR: expected 46 staged FASTA files in ${GENOME_DIR}; found ${staged_count}" >&2
  exit 1
fi

reference_rel="$(tail -n +2 "${REFERENCE_RECORD}" | cut -f2)"
PARSNP_REFERENCE="${reference_rel}"
require_file "${PARSNP_REFERENCE}" "ATCC 27562 Parsnp reference FASTA"

if [[ -d "${PARSNP_OUT}" ]] && [[ -n "$(find "${PARSNP_OUT}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  log "ERROR: Parsnp output directory is not empty: ${PARSNP_OUT}" >&2
  log "Move or archive existing outputs before rerunning to avoid mixing results." >&2
  exit 1
fi
if [[ -d "${PARSNP_OUT}" ]]; then
  log "Removing empty Parsnp output directory so Parsnp can create it: ${PARSNP_OUT}"
  rmdir "${PARSNP_OUT}"
fi

{
  printf 'parameter\tvalue\n'
  printf 'project_dir\t%s\n' "${PROJECT_DIR}"
  printf 'manifest\t%s\n' "${MANIFEST}"
  printf 'container\t%s\n' "${PARSNP_CONTAINER}"
  printf 'parsnp_reference\t%s\n' "${PARSNP_REFERENCE}"
  printf 'genome_dir\t%s\n' "${GENOME_DIR}"
  printf 'output_dir\t%s\n' "${PARSNP_OUT}"
  printf 'threads\t%s\n' "${PARSNP_THREADS}"
  printf 'parsnp_args\t-r ${PARSNP_REFERENCE} -d ${GENOME_DIR} -o ${PARSNP_OUT} -p ${PARSNP_THREADS} -c\n'
} > "${PARSNP_PARAMS}"

log "Parsnp container: ${PARSNP_CONTAINER}"
log "Parsnp reference: ${PARSNP_REFERENCE}"
log "Parsnp output: ${PARSNP_OUT}"
log "Running Parsnp"

singularity exec "${PARSNP_CONTAINER}" parsnp \
  -r "${PARSNP_REFERENCE}" \
  -d "${GENOME_DIR}" \
  -o "${PARSNP_OUT}" \
  -p "${PARSNP_THREADS}" \
  -c

for expected in parsnp.xmfa parsnp.tree parsnp.snps.mblocks parsnp.ggr; do
  require_file "${PARSNP_OUT}/${expected}" "Expected Parsnp output ${expected}"
done

log "Verified expected Parsnp outputs:"
log "  ${PARSNP_OUT}/parsnp.xmfa"
log "  ${PARSNP_OUT}/parsnp.tree"
log "  ${PARSNP_OUT}/parsnp.snps.mblocks"
log "  ${PARSNP_OUT}/parsnp.ggr"
log "Downstream tree placeholders are saved in ${METADATA_DIR}/downstream_tree_commands.sh"
log "Do not run IQ-TREE or RAxML until the Parsnp alignment has been reviewed and converted/prepared for tree building."
log "END parsnp_expanded_vv_46.slurm"
