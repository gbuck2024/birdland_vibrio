#!/bin/bash
# Reassemble taxon-filtered/downsampled ambiguous isolate reads with SPAdes.
# Submit after downsampling: sbatch --array=0-2 scripts/spades_taxon_filtered_array.slurm

#SBATCH -J spades_taxon_filtered
#SBATCH -p normal
#SBATCH -t 36:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 16
#SBATCH --mem=96G
#SBATCH -o ambiguous_isolate_resolution/taxonomic_filtering/logs/spades_taxon_filtered_%A_%a.out
#SBATCH -e ambiguous_isolate_resolution/taxonomic_filtering/logs/spades_taxon_filtered_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MANIFEST_FILE="${MANIFEST_FILE:-configs/taxon_filter_manifest.tsv}"
STAGE_DIR="ambiguous_isolate_resolution/taxonomic_filtering"
ASSEMBLIES_DIR="${STAGE_DIR}/assemblies"
LOG_DIR="${STAGE_DIR}/logs"
SPADES_BIN="${SPADES_BIN:-spades.py}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-singularity}"
CONTAINER_IMAGE="${SPADES_SIF:-${PROJECT_DIR}/containers/spades.sif}"
SPADES_THREADS="${SLURM_CPUS_PER_TASK:-16}"
SPADES_MEMORY_GB="${SPADES_MEMORY_GB:-90}"
SPADES_EXTRA_ARGS="${SPADES_EXTRA_ARGS:---isolate}"
SPADES_TMP_ROOT="${SPADES_TMP_ROOT:-${TMPDIR:-${PROJECT_DIR}/tmp}}"

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

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log "ERROR: Required command not found in PATH: ${command_name}" >&2
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

resolve_spades() {
  local candidate=""
  for candidate in "${SPADES_BIN}" spades.py spades; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      SPADES_BIN="${candidate}"
      return 0
    fi
  done
  if initialize_modules; then
    module load spades >/dev/null 2>&1 || module load SPAdes >/dev/null 2>&1 || true
  fi
  for candidate in "${SPADES_BIN}" spades.py spades; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      SPADES_BIN="${candidate}"
      return 0
    fi
  done
  return 1
}

run_spades_container() {
  require_command "${CONTAINER_RUNTIME}"
  require_file "${CONTAINER_IMAGE}" "SPAdes container image"
  "${CONTAINER_RUNTIME}" exec \
    --cleanenv \
    --bind "${PROJECT_DIR}:${PROJECT_DIR}" \
    --bind "${SPADES_TMP_ROOT}:${SPADES_TMP_ROOT}" \
    "${CONTAINER_IMAGE}" \
    bash -c "
      set -euo pipefail
      if command -v '${SPADES_BIN}' >/dev/null 2>&1; then
        resolved_spades='${SPADES_BIN}'
      elif command -v spades.py >/dev/null 2>&1; then
        resolved_spades='spades.py'
      elif command -v spades >/dev/null 2>&1; then
        resolved_spades='spades'
      else
        echo 'SPAdes executable not found inside container.' >&2
        exit 1
      fi
      \"\${resolved_spades}\" \
        --pe1-1 '${read1}' \
        --pe1-2 '${read2}' \
        -o '${sample_dir}' \
        -t '${SPADES_THREADS}' \
        -m '${SPADES_MEMORY_GB}' \
        --tmp-dir '${sample_tmp}' \
        ${SPADES_EXTRA_ARGS}
    " 2>&1 | tee "${spades_log}"
}

mkdir -p "${ASSEMBLIES_DIR}" "${LOG_DIR}" "${SPADES_TMP_ROOT}"
require_file "${MANIFEST_FILE}" "Taxon filter manifest"

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")
if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r sample_id r1 r2 kraken_output kraken_report target_taxon_name target_taxid filter_mode downsample_pairs <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"

read1="${STAGE_DIR}/downsampled_reads/${sample_id}.${target_taxon_name}.R1.downsampled.fq.gz"
read2="${STAGE_DIR}/downsampled_reads/${sample_id}.${target_taxon_name}.R2.downsampled.fq.gz"
sample_dir="${ASSEMBLIES_DIR}/${sample_id}_${target_taxon_name}"
sample_tmp="${SPADES_TMP_ROOT%/}/spades_taxon_filtered_${sample_id}_${target_taxon_name}_${SLURM_JOB_ID:-manual}_${SLURM_ARRAY_TASK_ID}"
spades_log="${LOG_DIR}/${sample_id}.${target_taxon_name}.spades.log"

require_file "${read1}" "Downsampled R1"
require_file "${read2}" "Downsampled R2"

mkdir -p "${sample_dir}"

log "Sample: ${sample_id}; target=${target_taxon_name} (${target_taxid})"
log "Assembly directory: ${sample_dir}"
log "SPAdes threads=${SPADES_THREADS}; memory_gb=${SPADES_MEMORY_GB}; args=${SPADES_EXTRA_ARGS}"

if [ -s "${CONTAINER_IMAGE}" ]; then
  log "Using SPAdes Singularity image: ${CONTAINER_IMAGE}"
  run_spades_container
else
  log "SPAdes Singularity image not found at ${CONTAINER_IMAGE}."
  log "If SPAdes is unavailable as a module/command, pull or build a container at containers/spades.sif before submission."
  log "Suggested image source to download/build via wget or apptainer/singularity: docker://staphb/spades:latest"
  if ! resolve_spades; then
    log "ERROR: SPAdes command unavailable and no container image found." >&2
    exit 1
  fi
  "${SPADES_BIN}" \
    --pe1-1 "${read1}" \
    --pe1-2 "${read2}" \
    -o "${sample_dir}" \
    -t "${SPADES_THREADS}" \
    -m "${SPADES_MEMORY_GB}" \
    --tmp-dir "${sample_tmp}" \
    ${SPADES_EXTRA_ARGS} \
    2>&1 | tee "${spades_log}"
fi

require_file "${sample_dir}/contigs.fasta" "SPAdes contigs FASTA"
require_file "${sample_dir}/scaffolds.fasta" "SPAdes scaffolds FASTA"
require_file "${spades_log}" "Stage-level SPAdes log"

rm -rf "${sample_tmp}"
log "Completed SPAdes taxon-filtered assembly for ${sample_id}"
