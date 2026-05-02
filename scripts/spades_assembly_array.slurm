#!/bin/bash
# Run de novo SPAdes assemblies for the trimmed paired-end reads listed in the
# assembly manifest. Submit as a SLURM array job; do not run SPAdes on a login node.
#
# How to run:
# 1. Submit one assembly task per saved sample pair:
#    sbatch --array=0-5 scripts/spades_assembly_array.slurm
# 2. After the array job completes, generate the curated assembly summary:
#    sbatch --export=ALL,SPADES_MODE=summary scripts/spades_assembly_array.slurm
# 3. To target a subset or rerun into a different stage directory, override
#    MANIFEST_FILE and STAGE_DIR at submission time.

#SBATCH -J spades_assembly
#SBATCH -p normal
#SBATCH -t 48:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 16
#SBATCH --mem=128G
#SBATCH -o assembly/logs/slurm/spades_assembly_%A_%a.out
#SBATCH -e assembly/logs/slurm/spades_assembly_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MODE="${SPADES_MODE:-assemble}"
MANIFEST_FILE="${MANIFEST_FILE:-configs/assembly_manifest.tsv}"
STAGE_DIR="${STAGE_DIR:-assembly}"
ASSEMBLIES_DIR="${STAGE_DIR}/assemblies"
METRICS_DIR="${STAGE_DIR}/metrics"
LOG_DIR="${STAGE_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
SUMMARY_SCRIPT="scripts/summarize_spades_assemblies.py"

SPADES_BIN="${SPADES_BIN:-spades.py}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-singularity}"
SPADES_THREADS="${SLURM_CPUS_PER_TASK:-16}"
SPADES_MEMORY_GB="${SPADES_MEMORY_GB:-120}"
# Default to isolate mode for bacterial isolate assemblies unless the submitter
# explicitly overrides the extra argument list.
SPADES_EXTRA_ARGS="${SPADES_EXTRA_ARGS:---isolate}"
SPADES_TMP_ROOT="${SPADES_TMP_ROOT:-${TMPDIR:-${PROJECT_DIR}/tmp}}"

if [ -n "${SPADES_SIF:-}" ]; then
  CONTAINER_IMAGE="${SPADES_SIF}"
elif [ -s "${PROJECT_DIR}/containers/spades.sif" ]; then
  CONTAINER_IMAGE="${PROJECT_DIR}/containers/spades.sif"
else
  CONTAINER_IMAGE="${PROJECT_DIR}/spades.sif"
fi

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

log() {
  echo "[$(timestamp)] $*"
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
    # Load the environment-modules function in non-interactive batch shells.
    # shellcheck disable=SC1091
    source /etc/profile.d/modules.sh
  elif [ -r /usr/share/Modules/init/bash ]; then
    # Support clusters that install Environment Modules outside /etc/profile.d.
    # shellcheck disable=SC1091
    source /usr/share/Modules/init/bash
  fi

  command -v module >/dev/null 2>&1
}

resolve_spades() {
  local candidate=""
  for candidate in "${SPADES_BIN}" spades.py spades.py.py spades; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      SPADES_BIN="${candidate}"
      log "Using SPAdes executable: ${SPADES_BIN}"
      return 0
    fi
  done

  if initialize_modules; then
    module purge
    for candidate in spades SPAdes; do
      if module load "${candidate}" >/dev/null 2>&1; then
        for executable in "${SPADES_BIN}" spades.py spades.py.py spades; do
          if command -v "${executable}" >/dev/null 2>&1; then
            SPADES_BIN="${executable}"
            log "Loaded SPAdes via environment module '${candidate}'."
            log "Using SPAdes executable: ${SPADES_BIN}"
            return 0
          fi
        done
      fi
      module purge
    done
  fi

  log "ERROR: SPAdes executable not found. Set SPADES_BIN to the cluster command or load a working SPAdes module before submission." >&2
  return 1
}

require_file() {
  local path="$1"
  local label="$2"

  if [ ! -s "${path}" ]; then
    log "ERROR: ${label} missing or empty: ${path}" >&2
    exit 1
  fi
}

run_spades_in_container() {
  require_command "${CONTAINER_RUNTIME}"
  require_file "${CONTAINER_IMAGE}" "SPAdes container image"

  log "Using container runtime: ${CONTAINER_RUNTIME}"
  log "Using container image: ${CONTAINER_IMAGE}"

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

mkdir -p "${ASSEMBLIES_DIR}" "${METRICS_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}"

log "START spades_assembly_array.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Mode: ${MODE}"
log "Manifest: ${MANIFEST_FILE}"
log "Stage directory: ${STAGE_DIR}"
log "Container image candidate: ${CONTAINER_IMAGE}"

require_file "${MANIFEST_FILE}" "Assembly manifest"

if [ "${MODE}" = "summary" ]; then
  require_file "${SUMMARY_SCRIPT}" "Assembly summary script"
  python3 "${SUMMARY_SCRIPT}"
  log "END spades_assembly_array.slurm"
  exit 0
fi

if [ "${MODE}" != "assemble" ]; then
  log "ERROR: Unsupported SPADES_MODE='${MODE}'. Use 'assemble' or 'summary'." >&2
  exit 1
fi

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit assembly mode with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")

if [ "${#SAMPLE_ROWS[@]}" -eq 0 ]; then
  log "ERROR: Assembly manifest contains no sample rows." >&2
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

sample_dir="${ASSEMBLIES_DIR}/${sample_id}"
sample_tmp="${SPADES_TMP_ROOT%/}/spades_${sample_id}"
spades_log="${LOG_DIR}/${sample_id}.spades.log"

mkdir -p "${sample_dir}" "${SPADES_TMP_ROOT}"
rm -rf "${sample_tmp}"

log "Sample: ${sample_id}"
log "Reads: ${read1} ${read2}"
log "Assembly directory: ${sample_dir}"
log "Temporary directory: ${sample_tmp}"
log "SPAdes threads: ${SPADES_THREADS}"
log "SPAdes memory (GB): ${SPADES_MEMORY_GB}"
log "SPAdes extra args: ${SPADES_EXTRA_ARGS}"

if [ -s "${CONTAINER_IMAGE}" ]; then
  run_spades_in_container
else
  resolve_spades
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
require_file "${sample_dir}/assembly_graph.fastg" "SPAdes assembly graph"
require_file "${sample_dir}/params.txt" "SPAdes parameter record"
require_file "${sample_dir}/spades.log" "SPAdes internal log"
require_file "${spades_log}" "Stage-level SPAdes log"

rm -rf "${sample_tmp}"

log "Completed SPAdes assembly for ${sample_id}"
log "END spades_assembly_array.slurm"
