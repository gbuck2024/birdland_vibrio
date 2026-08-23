#!/bin/bash
# Map Buck_BI0607_2 trimmed paired reads back to its own SPAdes contigs for
# BlobToolKit coverage analysis. Submit through SLURM; do not run on a login node.
#
# Submit from the project root:
#   sbatch scripts/blobtoolkit_bi0607_2_self_mapping.slurm

#SBATCH -J btk_bi0607_2_cov
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -o ambiguous_isolate_resolution/blobtoolkit/BI0607_2/logs/slurm/btk_bi0607_2_self_mapping_%j.out
#SBATCH -e ambiguous_isolate_resolution/blobtoolkit/BI0607_2/logs/slurm/btk_bi0607_2_self_mapping_%j.err

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
CONDA_ENV_PATH="${CONDA_ENV_PATH:-/home/glametrie1/.conda/envs/blobtoolkit}"
READ1="${READ1:-trimmomatic/trimmed_reads/${SAMPLE_ID}_1_paired.fq.gz}"
READ2="${READ2:-trimmomatic/trimmed_reads/${SAMPLE_ID}_2_paired.fq.gz}"
REFERENCE_FASTA="${REFERENCE_FASTA:-assembly/assemblies/${SAMPLE_ID}/contigs.fasta}"
STAGE_DIR="${STAGE_DIR:-ambiguous_isolate_resolution/blobtoolkit/${SHORT_ID}}"

BAM_DIR="${STAGE_DIR}/bam"
INDEX_DIR="${STAGE_DIR}/index"
METRICS_DIR="${STAGE_DIR}/metrics"
LOG_DIR="${STAGE_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
METADATA_DIR="${STAGE_DIR}/metadata"

BWA_INDEX_PREFIX="${INDEX_DIR}/${SHORT_ID}.spades_contigs"
MAPPED_BAM="${BAM_DIR}/${SAMPLE_ID}.self_contigs.mapped.bam"
SORTED_BAM="${BAM_DIR}/${SAMPLE_ID}.self_contigs.sorted.bam"
FLAGSTAT_FILE="${METRICS_DIR}/${SAMPLE_ID}.self_contigs.sorted.flagstat.txt"
IDXSTATS_FILE="${METRICS_DIR}/${SAMPLE_ID}.self_contigs.sorted.idxstats.txt"
QUICKCHECK_FILE="${METRICS_DIR}/${SAMPLE_ID}.self_contigs.quickcheck.txt"
REFNAME_DIFF="${METRICS_DIR}/${SAMPLE_ID}.self_contigs.reference_name_diff.txt"
REFNAME_CHECK="${METRICS_DIR}/${SAMPLE_ID}.self_contigs.reference_name_check.txt"
PARAMS_FILE="${METADATA_DIR}/${SAMPLE_ID}.self_contigs.parameters.txt"
SPADES_CONTIG_NAMES="${METADATA_DIR}/${SAMPLE_ID}.spades_contig_names.txt"
BAM_REFERENCE_NAMES="${METADATA_DIR}/${SAMPLE_ID}.bam_reference_names.txt"

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

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log "ERROR: Required command not found in PATH: ${command_name}" >&2
    exit 1
  fi
}

mkdir -p \
  "${BAM_DIR}" \
  "${INDEX_DIR}" \
  "${METRICS_DIR}" \
  "${LOG_DIR}" \
  "${SLURM_LOG_DIR}" \
  "${METADATA_DIR}"

log "START blobtoolkit_bi0607_2_self_mapping.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Sample: ${SAMPLE_ID}"
log "Read 1: ${READ1}"
log "Read 2: ${READ2}"
log "SPAdes contigs: ${REFERENCE_FASTA}"
log "Stage directory: ${STAGE_DIR}"

require_file "${READ1}" "trimmed R1 paired reads"
require_file "${READ2}" "trimmed R2 paired reads"
require_file "${REFERENCE_FASTA}" "SPAdes contigs FASTA"

read1_base="$(basename "${READ1}")"
read2_base="$(basename "${READ2}")"
if [[ "${read1_base}" != "${SAMPLE_ID}_1_paired.fq.gz" ]]; then
  log "ERROR: R1 filename does not match the expected paired-read pattern for ${SAMPLE_ID}: ${READ1}" >&2
  exit 1
fi
if [[ "${read2_base}" != "${SAMPLE_ID}_2_paired.fq.gz" ]]; then
  log "ERROR: R2 filename does not match the expected paired-read pattern for ${SAMPLE_ID}: ${READ2}" >&2
  exit 1
fi

initialize_conda
if ! command -v blobtools >/dev/null 2>&1; then
  log "ERROR: BlobToolKit environment is active, but blobtools is not available." >&2
  exit 1
fi

if ! command -v bwa >/dev/null 2>&1; then
  if initialize_modules; then
    module load bwa/0.7.17
  fi
fi

require_command bwa
require_command samtools
require_command blobtools

{
  echo "sample_id=${SAMPLE_ID}"
  echo "short_id=${SHORT_ID}"
  echo "conda_env_path=${CONDA_ENV_PATH}"
  echo "blobtools_version=$(blobtools --version 2>&1 | tail -n 1)"
  echo "bwa_path=$(command -v bwa)"
  echo "samtools_path=$(command -v samtools)"
  echo "read1=${READ1}"
  echo "read2=${READ2}"
  echo "reference_fasta=${REFERENCE_FASTA}"
  echo "bwa_index_prefix=${BWA_INDEX_PREFIX}"
  echo "threads=${SLURM_CPUS_PER_TASK:-1}"
} > "${PARAMS_FILE}"

log "Recording SPAdes contig names."
awk '/^>/ {sub(/^>/, ""); sub(/[ \t].*/, ""); print}' "${REFERENCE_FASTA}" > "${SPADES_CONTIG_NAMES}"
require_file "${SPADES_CONTIG_NAMES}" "SPAdes contig name list"

log "Building BWA index under the BlobToolKit stage directory."
bwa index -p "${BWA_INDEX_PREFIX}" "${REFERENCE_FASTA}"

for bwa_sidecar in \
  "${BWA_INDEX_PREFIX}.amb" \
  "${BWA_INDEX_PREFIX}.ann" \
  "${BWA_INDEX_PREFIX}.bwt" \
  "${BWA_INDEX_PREFIX}.pac" \
  "${BWA_INDEX_PREFIX}.sa"; do
  require_file "${bwa_sidecar}" "BWA index sidecar"
done

log "Mapping trimmed paired reads back to the sample's own SPAdes contigs."
bwa mem -t "${SLURM_CPUS_PER_TASK:-1}" "${BWA_INDEX_PREFIX}" "${READ1}" "${READ2}" \
  | samtools view -@ "${SLURM_CPUS_PER_TASK:-1}" -b -o "${MAPPED_BAM}" -
require_file "${MAPPED_BAM}" "mapped BAM"

log "Coordinate-sorting BAM."
samtools sort -@ "${SLURM_CPUS_PER_TASK:-1}" -o "${SORTED_BAM}" "${MAPPED_BAM}"
require_file "${SORTED_BAM}" "coordinate-sorted BAM"

log "Indexing coordinate-sorted BAM."
samtools index -@ "${SLURM_CPUS_PER_TASK:-1}" "${SORTED_BAM}"
require_file "${SORTED_BAM}.bai" "coordinate-sorted BAM index"

log "Verifying BAM integrity with samtools quickcheck."
samtools quickcheck -v "${MAPPED_BAM}" "${SORTED_BAM}" > "${QUICKCHECK_FILE}" 2>&1
echo "PASS: samtools quickcheck completed for mapped and coordinate-sorted BAMs." >> "${QUICKCHECK_FILE}"

log "Writing samtools flagstat and idxstats for the coordinate-sorted BAM."
samtools flagstat "${SORTED_BAM}" > "${FLAGSTAT_FILE}"
samtools idxstats "${SORTED_BAM}" > "${IDXSTATS_FILE}"
require_file "${FLAGSTAT_FILE}" "flagstat report"
require_file "${IDXSTATS_FILE}" "idxstats report"

log "Verifying BAM reference names match SPAdes contig names."
awk '$1 != "*" {print $1}' "${IDXSTATS_FILE}" > "${BAM_REFERENCE_NAMES}"
if ! diff -u "${SPADES_CONTIG_NAMES}" "${BAM_REFERENCE_NAMES}" > "${REFNAME_DIFF}"; then
  log "ERROR: BAM reference names differ from SPAdes contig names. See ${REFNAME_DIFF}" >&2
  exit 1
fi
echo "PASS: BAM reference names match the SPAdes contig names from ${REFERENCE_FASTA}." > "${REFNAME_CHECK}"

log "Completed self-contig mapping for ${SAMPLE_ID}"
log "Mapped BAM: ${MAPPED_BAM}"
log "Coordinate-sorted BAM: ${SORTED_BAM}"
log "BAM index: ${SORTED_BAM}.bai"
log "Metrics: ${FLAGSTAT_FILE} ${IDXSTATS_FILE} ${QUICKCHECK_FILE}"
log "Reference name check: ${REFNAME_CHECK}"
log "END blobtoolkit_bi0607_2_self_mapping.slurm"
