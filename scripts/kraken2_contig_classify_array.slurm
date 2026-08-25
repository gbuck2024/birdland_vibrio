#!/bin/bash
# Manifest-driven Kraken2 classification of SPAdes contigs.
#
# Submit from the project root:
#   sbatch --array=0-5 scripts/kraken2_contig_classify_array.slurm

#SBATCH -J kraken2_contigs
#SBATCH -p normal
#SBATCH -t 08:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -o ambiguous_isolate_resolution/blobtoolkit/logs/slurm/kraken2_contigs_%A_%a.out
#SBATCH -e ambiguous_isolate_resolution/blobtoolkit/logs/slurm/kraken2_contigs_%A_%a.err

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
DB_DIR="${DB_DIR:-kraken2_db/db}"
CONTAINER_IMAGE="${KRAKEN2_SIF:-containers/kraken2.sif}"
SINGULARITY_BIN="${SINGULARITY_BIN:-singularity}"
KRAKEN2_THREADS="${SLURM_CPUS_PER_TASK:-8}"
KRAKEN2_MEMORY_MAPPING="${KRAKEN2_MEMORY_MAPPING:-1}"
KRAKEN2_EXTRA_ARGS="${KRAKEN2_EXTRA_ARGS:-}"
FORCE_KRAKEN2="${FORCE_KRAKEN2:-0}"

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

run_in_container() {
  local command_text="$1"

  "${SINGULARITY_BIN}" exec \
    --cleanenv \
    --bind "${PROJECT_DIR}:${PROJECT_DIR}" \
    "${CONTAINER_IMAGE}" \
    bash -lc "${command_text}"
}

mkdir -p "${STAGE_ROOT}/logs/slurm"

log "START kraken2_contig_classify_array.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Manifest: ${MANIFEST_FILE}"
log "Database directory: ${DB_DIR}"
log "Kraken2 container: ${CONTAINER_IMAGE}"

require_file "${MANIFEST_FILE}" "BlobToolKit self-mapping manifest"
require_file "${CONTAINER_IMAGE}" "Kraken2 container image"
require_file "${DB_DIR}/hash.k2d" "Kraken2 database hash"
require_file "${DB_DIR}/opts.k2d" "Kraken2 database options"
require_file "${DB_DIR}/taxo.k2d" "Kraken2 database taxonomy"

if ! command -v "${SINGULARITY_BIN}" >/dev/null 2>&1; then
  log "ERROR: Required command not found in PATH: ${SINGULARITY_BIN}" >&2
  exit 1
fi
run_in_container "command -v kraken2 >/dev/null 2>&1"

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
taxonomy_dir="${stage_dir}/taxonomy"
metadata_dir="${stage_dir}/metadata"
sample_log_dir="${stage_dir}/logs/slurm"
output_file="${taxonomy_dir}/${sample_id}.spades_contigs.kraken2.tsv"
report_file="${taxonomy_dir}/${sample_id}.spades_contigs.kreport.tsv"
params_file="${metadata_dir}/${sample_id}.spades_contigs.kraken2.parameters.txt"

mkdir -p "${taxonomy_dir}" "${metadata_dir}" "${sample_log_dir}"

log "Sample: ${sample_id}"
log "Short ID: ${short_id}"
log "Input contigs: ${contigs_fasta}"
log "Output: ${output_file}"
log "Report: ${report_file}"
require_file "${contigs_fasta}" "SPAdes contigs FASTA"

if [ -s "${output_file}" ] && [ -s "${report_file}" ] && [ "${FORCE_KRAKEN2}" != "1" ]; then
  log "Kraken2 outputs already exist; leaving them in place."
  log "END kraken2_contig_classify_array.slurm"
  exit 0
fi

memory_map_flag=""
if [ "${KRAKEN2_MEMORY_MAPPING}" = "1" ]; then
  memory_map_flag="--memory-mapping"
fi

{
  echo "sample_id=${sample_id}"
  echo "short_id=${short_id}"
  echo "manifest_file=${MANIFEST_FILE}"
  echo "contigs_fasta=${contigs_fasta}"
  echo "db_dir=${DB_DIR}"
  echo "container_image=${CONTAINER_IMAGE}"
  echo "threads=${KRAKEN2_THREADS}"
  echo "memory_mapping=${KRAKEN2_MEMORY_MAPPING}"
  echo "extra_args=${KRAKEN2_EXTRA_ARGS}"
  echo "output_file=${output_file}"
  echo "report_file=${report_file}"
  echo "force_kraken2=${FORCE_KRAKEN2}"
} > "${params_file}"

log "Running Kraken2 per-contig classification."
run_in_container \
  "set -euo pipefail; \
   cd '${PROJECT_DIR}'; \
   kraken2 \
     --db '${DB_DIR}' \
     --threads '${KRAKEN2_THREADS}' \
     --use-names \
     ${memory_map_flag} \
     --report '${report_file}' \
     --output '${output_file}' \
     ${KRAKEN2_EXTRA_ARGS} \
     '${contigs_fasta}'"

require_file "${output_file}" "Kraken2 per-contig output"
require_file "${report_file}" "Kraken2 report"

log "Completed Kraken2 classification for ${sample_id} SPAdes contigs."
log "END kraken2_contig_classify_array.slurm"
