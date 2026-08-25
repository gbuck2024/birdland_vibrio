#!/bin/bash
# Create BlobToolKit blobdirs from SPAdes contigs and add self-mapping coverage.
#
# Submit from the project root after self-mapping finishes:
#   sbatch --array=0-5 scripts/blobtoolkit_add_self_coverage_array.slurm

#SBATCH -J btk_add_cov
#SBATCH -p normal
#SBATCH -t 04:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem=16G
#SBATCH -o ambiguous_isolate_resolution/blobtoolkit/logs/slurm/add_self_coverage_%A_%a.out
#SBATCH -e ambiguous_isolate_resolution/blobtoolkit/logs/slurm/add_self_coverage_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MANIFEST_FILE="${MANIFEST_FILE:-configs/blobtoolkit_self_mapping_manifest.tsv}"
STAGE_ROOT="${STAGE_ROOT:-ambiguous_isolate_resolution/blobtoolkit}"
CONDA_ENV_PATH="${CONDA_ENV_PATH:-/home/glametrie1/.conda/envs/blobtoolkit}"
FORCE_BLOBDIR="${FORCE_BLOBDIR:-0}"
FORCE_COVERAGE="${FORCE_COVERAGE:-0}"

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

initialize_conda() {
  if [ -r /cm/shared/tamucc/apps/miniconda3/24.1.2/etc/profile.d/conda.sh ]; then
    # shellcheck disable=SC1091
    source /cm/shared/tamucc/apps/miniconda3/24.1.2/etc/profile.d/conda.sh
  elif command -v conda >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    source "$(conda info --base)/etc/profile.d/conda.sh"
  else
    log "ERROR: conda command not found; cannot activate BlobToolKit environment." >&2
    exit 1
  fi

  conda activate "${CONDA_ENV_PATH}"
}

mkdir -p "${STAGE_ROOT}/logs/slurm"

log "START blobtoolkit_add_self_coverage_array.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Manifest: ${MANIFEST_FILE}"
require_file "${MANIFEST_FILE}" "BlobToolKit self-mapping manifest"

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit this script with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")
if [ "${#SAMPLE_ROWS[@]}" -eq 0 ]; then
  log "ERROR: Manifest contains no sample rows." >&2
  exit 1
fi

if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r short_id sample_id read1 read2 contigs_fasta <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"
stage_dir="${STAGE_ROOT}/${short_id}"
bam_dir="${stage_dir}/bam"
blobdir="${stage_dir}/blobdir"
metrics_dir="${stage_dir}/metrics"
metadata_dir="${stage_dir}/metadata"
sample_log_dir="${stage_dir}/logs/slurm"
sorted_bam="${bam_dir}/${sample_id}.self_contigs.sorted.bam"
coverage_json="${blobdir}/${sample_id}.self_contigs.sorted_cov.json"
params_file="${metadata_dir}/${sample_id}.blobtools_add_coverage.parameters.txt"

mkdir -p "${metrics_dir}" "${metadata_dir}" "${sample_log_dir}"

log "Sample: ${sample_id}"
log "Short ID: ${short_id}"
log "SPAdes contigs: ${contigs_fasta}"
log "Sorted BAM: ${sorted_bam}"
log "Blobdir: ${blobdir}"

require_file "${contigs_fasta}" "SPAdes contigs FASTA"
require_file "${sorted_bam}" "coordinate-sorted self-mapping BAM"
require_file "${sorted_bam}.bai" "coordinate-sorted BAM BAI index"
require_file "${sorted_bam}.csi" "coordinate-sorted BAM CSI index"

initialize_conda
if ! command -v blobtools >/dev/null 2>&1; then
  log "ERROR: BlobToolKit environment is active, but blobtools is not available." >&2
  exit 1
fi

{
  echo "sample_id=${sample_id}"
  echo "short_id=${short_id}"
  echo "manifest_file=${MANIFEST_FILE}"
  echo "conda_env_path=${CONDA_ENV_PATH}"
  echo "blobtools_version=$(blobtools --version 2>&1 | tail -n 1)"
  echo "contigs_fasta=${contigs_fasta}"
  echo "sorted_bam=${sorted_bam}"
  echo "coverage_json=${coverage_json}"
  echo "force_blobdir=${FORCE_BLOBDIR}"
  echo "force_coverage=${FORCE_COVERAGE}"
} > "${params_file}"

if [ -d "${blobdir}" ] && [ "${FORCE_BLOBDIR}" != "1" ]; then
  require_file "${blobdir}/identifiers.json" "existing BlobToolKit identifiers"
  require_file "${blobdir}/gc.json" "existing BlobToolKit GC values"
  require_file "${blobdir}/length.json" "existing BlobToolKit lengths"
  log "Using existing BlobToolKit blobdir."
else
  if [ -e "${blobdir}" ] && [ "${FORCE_BLOBDIR}" = "1" ]; then
    log "ERROR: FORCE_BLOBDIR=1 requested, but this script will not delete an existing blobdir: ${blobdir}" >&2
    exit 1
  fi
  log "Creating BlobToolKit blobdir from SPAdes contigs."
  blobtools add --create --fasta "${contigs_fasta}" "${blobdir}"
  require_file "${blobdir}/identifiers.json" "BlobToolKit identifiers"
  require_file "${blobdir}/gc.json" "BlobToolKit GC values"
  require_file "${blobdir}/length.json" "BlobToolKit lengths"
fi

if [ -s "${coverage_json}" ] && [ "${FORCE_COVERAGE}" != "1" ]; then
  log "Coverage JSON already exists; leaving it in place: ${coverage_json}"
else
  log "Adding self-mapped coverage to BlobToolKit blobdir."
  blobtools add --cov "${sorted_bam}" "${blobdir}"
  require_file "${coverage_json}" "BlobToolKit coverage JSON"
fi

log "Completed BlobToolKit coverage addition for ${sample_id}"
log "END blobtoolkit_add_self_coverage_array.slurm"
