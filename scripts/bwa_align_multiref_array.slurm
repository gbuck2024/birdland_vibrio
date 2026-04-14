#!/bin/bash
#SBATCH -J bwa_multiref
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -o multi_reference_alignment/logs/slurm/bwa_multiref_%A_%a.out
#SBATCH -e multi_reference_alignment/logs/slurm/bwa_multiref_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

SAMPLE_MANIFEST="configs/alignment_manifest.tsv"
REFERENCE_MANIFEST="configs/multi_reference_reference_manifest.tsv"
STAGE_DIR="multi_reference_alignment"
BAM_DIR="${STAGE_DIR}/bam"
LOG_DIR="${STAGE_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
METRICS_DIR="${STAGE_DIR}/metrics"

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

validate_reference_indexes() {
  local reference_fasta="$1"

  for ref_sidecar in \
    "${reference_fasta}.amb" \
    "${reference_fasta}.ann" \
    "${reference_fasta}.bwt" \
    "${reference_fasta}.pac" \
    "${reference_fasta}.sa" \
    "${reference_fasta}.fai"; do
    require_file "${ref_sidecar}" "Required reference index"
  done
}

log "START bwa_align_multiref_array.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Sample manifest: ${SAMPLE_MANIFEST}"
log "Reference manifest: ${REFERENCE_MANIFEST}"

mkdir -p "${BAM_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}" "${METRICS_DIR}"

require_file "${SAMPLE_MANIFEST}" "Sample manifest"
require_file "${REFERENCE_MANIFEST}" "Reference manifest"

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit this script with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${SAMPLE_MANIFEST}")
mapfile -t REFERENCE_ROWS < <(tail -n +2 "${REFERENCE_MANIFEST}")

if [ "${#SAMPLE_ROWS[@]}" -eq 0 ]; then
  log "ERROR: Sample manifest contains no sample rows." >&2
  exit 1
fi

if [ "${#REFERENCE_ROWS[@]}" -eq 0 ]; then
  log "ERROR: Reference manifest contains no reference rows." >&2
  exit 1
fi

SAMPLE_COUNT="${#SAMPLE_ROWS[@]}"
REFERENCE_COUNT="${#REFERENCE_ROWS[@]}"
TOTAL_TASKS=$(( SAMPLE_COUNT * REFERENCE_COUNT ))
MAX_TASK_ID=$(( TOTAL_TASKS - 1 ))

if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -gt "${MAX_TASK_ID}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-${MAX_TASK_ID}." >&2
  exit 1
fi

sample_index=$(( SLURM_ARRAY_TASK_ID / REFERENCE_COUNT ))
reference_index=$(( SLURM_ARRAY_TASK_ID % REFERENCE_COUNT ))

IFS=$'\t' read -r sample_id read1 read2 <<< "${SAMPLE_ROWS[${sample_index}]}"
IFS=$'\t' read -r reference_id reference_fasta reference_format reference_notes <<< "${REFERENCE_ROWS[${reference_index}]}"

if [ -z "${sample_id}" ] || [ -z "${read1}" ] || [ -z "${read2}" ]; then
  log "ERROR: Sample manifest row ${sample_index} is malformed." >&2
  exit 1
fi

if [ -z "${reference_id}" ] || [ -z "${reference_fasta}" ] || [ -z "${reference_format}" ]; then
  log "ERROR: Reference manifest row ${reference_index} is malformed." >&2
  exit 1
fi

require_file "${read1}" "Forward trimmed read"
require_file "${read2}" "Reverse trimmed read"
require_file "${reference_fasta}" "Reference FASTA"
validate_reference_indexes "${reference_fasta}"

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
  log "ERROR: Read pairing or sample naming mismatch for sample row ${sample_index}." >&2
  exit 1
fi

reference_contigs="$(awk 'END {print NR+0}' "${reference_fasta}.fai")"
if [ "${reference_contigs}" -lt 1 ]; then
  log "ERROR: ${reference_fasta}.fai reports no contigs." >&2
  exit 1
fi

module purge
module load bwa
module load samtools

output_prefix="${BAM_DIR}/${sample_id}__${reference_id}"
sam_file="${output_prefix}.sam"
bam_file="${output_prefix}.bam"
sorted_bam="${output_prefix}.sorted.bam"
flagstat_file="${METRICS_DIR}/${sample_id}__${reference_id}.flagstat.txt"
idxstats_file="${METRICS_DIR}/${sample_id}__${reference_id}.idxstats.txt"

log "Sample: ${sample_id}"
log "Reference: ${reference_id}"
log "Reference FASTA: ${reference_fasta}"
log "Reference format: ${reference_format}"
log "Reference contigs from .fai: ${reference_contigs}"
log "Reference note: ${reference_notes}"
log "Reads: ${read1} ${read2}"
log "Task ${SLURM_ARRAY_TASK_ID} covers sample index ${sample_index} and reference index ${reference_index}."

log "Running BWA-MEM."
bwa mem -t "${SLURM_CPUS_PER_TASK:-1}" "${reference_fasta}" "${read1}" "${read2}" > "${sam_file}"
require_file "${sam_file}" "SAM output"

log "Converting SAM to BAM."
samtools view -@ "${SLURM_CPUS_PER_TASK:-1}" -bS "${sam_file}" > "${bam_file}"
require_file "${bam_file}" "BAM output"

log "Sorting BAM."
samtools sort -@ "${SLURM_CPUS_PER_TASK:-1}" -o "${sorted_bam}" "${bam_file}"
require_file "${sorted_bam}" "Sorted BAM"

log "Indexing sorted BAM."
samtools index "${sorted_bam}"
require_file "${sorted_bam}.bai" "BAM index"

log "Collecting alignment metrics."
samtools flagstat "${sorted_bam}" > "${flagstat_file}"
samtools idxstats "${sorted_bam}" > "${idxstats_file}"
require_file "${flagstat_file}" "Flagstat report"
require_file "${idxstats_file}" "Idxstats report"

rm -f "${sam_file}" "${bam_file}"

log "Completed sample ${sample_id} against ${reference_id}"
log "Sorted BAM: ${sorted_bam}"
log "Metrics: ${flagstat_file} ${idxstats_file}"
log "END bwa_align_multiref_array.slurm"
