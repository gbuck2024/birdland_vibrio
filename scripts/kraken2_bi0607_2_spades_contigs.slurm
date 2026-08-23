#!/bin/bash
# Classify Buck_BI0607_2 SPAdes contigs with Kraken2 for BlobToolKit taxonomy.
# Submit from the project root after review:
#   sbatch scripts/kraken2_bi0607_2_spades_contigs.slurm

#SBATCH -J btk_bi0607_2_tax
#SBATCH -p normal
#SBATCH -t 08:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -o ambiguous_isolate_resolution/blobtoolkit/BI0607_2/logs/slurm/kraken2_contigs_%j.out
#SBATCH -e ambiguous_isolate_resolution/blobtoolkit/BI0607_2/logs/slurm/kraken2_contigs_%j.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

SAMPLE_ID="${SAMPLE_ID:-Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7}"
SHORT_ID="${SHORT_ID:-BI0607_2}"
CONTIGS_FASTA="${CONTIGS_FASTA:-assembly/assemblies/${SAMPLE_ID}/contigs.fasta}"
DB_DIR="${DB_DIR:-kraken2_db/db}"
CONTAINER_IMAGE="${KRAKEN2_SIF:-containers/kraken2.sif}"
STAGE_DIR="${STAGE_DIR:-ambiguous_isolate_resolution/blobtoolkit/${SHORT_ID}}"
TAXONOMY_DIR="${STAGE_DIR}/taxonomy"
LOG_DIR="${STAGE_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
METADATA_DIR="${STAGE_DIR}/metadata"

KRAKEN2_THREADS="${SLURM_CPUS_PER_TASK:-8}"
KRAKEN2_MEMORY_MAPPING="${KRAKEN2_MEMORY_MAPPING:-1}"
KRAKEN2_EXTRA_ARGS="${KRAKEN2_EXTRA_ARGS:-}"
SINGULARITY_BIN="${SINGULARITY_BIN:-singularity}"

OUTPUT_FILE="${TAXONOMY_DIR}/${SAMPLE_ID}.spades_contigs.kraken2.tsv"
REPORT_FILE="${TAXONOMY_DIR}/${SAMPLE_ID}.spades_contigs.kreport.tsv"
PARAMS_FILE="${METADATA_DIR}/${SAMPLE_ID}.spades_contigs.kraken2.parameters.txt"

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

require_absent() {
  local path="$1"
  local label="$2"

  if [ -e "${path}" ]; then
    log "ERROR: Refusing to overwrite existing ${label}: ${path}" >&2
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

mkdir -p "${TAXONOMY_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}" "${METADATA_DIR}"

log "START kraken2_bi0607_2_spades_contigs.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Sample: ${SAMPLE_ID}"
log "Input contigs: ${CONTIGS_FASTA}"
log "Kraken2 database: ${DB_DIR}"
log "Kraken2 container: ${CONTAINER_IMAGE}"
log "Taxonomy output directory: ${TAXONOMY_DIR}"

# Validate all required inputs before starting classification.
require_file "${CONTIGS_FASTA}" "SPAdes contigs FASTA"
require_file "${CONTAINER_IMAGE}" "Kraken2 container image"
require_file "${DB_DIR}/hash.k2d" "Kraken2 database hash"
require_file "${DB_DIR}/opts.k2d" "Kraken2 database options"
require_file "${DB_DIR}/taxo.k2d" "Kraken2 database taxonomy"

require_absent "${OUTPUT_FILE}" "Kraken2 per-contig output"
require_absent "${REPORT_FILE}" "Kraken2 report"
require_absent "${PARAMS_FILE}" "Kraken2 parameter record"

if ! command -v "${SINGULARITY_BIN}" >/dev/null 2>&1; then
  log "ERROR: Required command not found in PATH: ${SINGULARITY_BIN}" >&2
  exit 1
fi

run_in_container "command -v kraken2 >/dev/null 2>&1"

memory_map_flag=""
if [ "${KRAKEN2_MEMORY_MAPPING}" = "1" ]; then
  memory_map_flag="--memory-mapping"
fi

{
  echo "sample_id=${SAMPLE_ID}"
  echo "short_id=${SHORT_ID}"
  echo "contigs_fasta=${CONTIGS_FASTA}"
  echo "db_dir=${DB_DIR}"
  echo "container_image=${CONTAINER_IMAGE}"
  echo "threads=${KRAKEN2_THREADS}"
  echo "memory_mapping=${KRAKEN2_MEMORY_MAPPING}"
  echo "extra_args=${KRAKEN2_EXTRA_ARGS}"
  echo "output_file=${OUTPUT_FILE}"
  echo "report_file=${REPORT_FILE}"
} > "${PARAMS_FILE}"

log "Running Kraken2 per-contig classification."
run_in_container \
  "set -euo pipefail; \
   cd '${PROJECT_DIR}'; \
   kraken2 \
     --db '${DB_DIR}' \
     --threads '${KRAKEN2_THREADS}' \
     --use-names \
     ${memory_map_flag} \
     --report '${REPORT_FILE}' \
     --output '${OUTPUT_FILE}' \
     ${KRAKEN2_EXTRA_ARGS} \
     '${CONTIGS_FASTA}'"

require_file "${OUTPUT_FILE}" "Kraken2 per-contig output"
require_file "${REPORT_FILE}" "Kraken2 report"
require_file "${PARAMS_FILE}" "Kraken2 parameter record"

log "Completed Kraken2 classification for ${SAMPLE_ID} SPAdes contigs."
log "END kraken2_bi0607_2_spades_contigs.slurm"
