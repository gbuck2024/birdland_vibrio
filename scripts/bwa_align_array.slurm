#!/bin/bash
#SBATCH -J bwa_mem_align
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -o alignment/logs/slurm/bwa_align_%A_%a.out
#SBATCH -e alignment/logs/slurm/bwa_align_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MANIFEST_FILE="configs/alignment_manifest.tsv"
REFERENCE_FASTA="reference/v_vulnificus_ref.fasta"
ALIGNMENT_DIR="alignment"
BAM_DIR="${ALIGNMENT_DIR}/bam"
LOG_DIR="${ALIGNMENT_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
METRICS_DIR="${ALIGNMENT_DIR}/metrics"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

echo "[$(timestamp)] START bwa_align_array.sh"
echo "[$(timestamp)] Project directory: ${PROJECT_DIR}"
echo "[$(timestamp)] Manifest: ${MANIFEST_FILE}"
echo "[$(timestamp)] Reference: ${REFERENCE_FASTA}"

mkdir -p "${BAM_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}" "${METRICS_DIR}"

if [ ! -f "${MANIFEST_FILE}" ]; then
  echo "[$(timestamp)] ERROR: Alignment manifest not found: ${MANIFEST_FILE}" >&2
  exit 1
fi

if [ ! -s "${REFERENCE_FASTA}" ]; then
  echo "[$(timestamp)] ERROR: Reference FASTA missing or empty: ${REFERENCE_FASTA}" >&2
  exit 1
fi

for ref_sidecar in \
  "${REFERENCE_FASTA}.amb" \
  "${REFERENCE_FASTA}.ann" \
  "${REFERENCE_FASTA}.bwt" \
  "${REFERENCE_FASTA}.pac" \
  "${REFERENCE_FASTA}.sa" \
  "${REFERENCE_FASTA}.fai"; do
  if [ ! -s "${ref_sidecar}" ]; then
    echo "[$(timestamp)] ERROR: Required reference index missing or empty: ${ref_sidecar}" >&2
    exit 1
  fi
done

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  echo "[$(timestamp)] ERROR: Submit this script with sbatch --array=0-N." >&2
  exit 1
fi

module purge
module load bwa
module load samtools

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")

if [ "${#SAMPLE_ROWS[@]}" -eq 0 ]; then
  echo "[$(timestamp)] ERROR: Alignment manifest contains no samples." >&2
  exit 1
fi

if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
  echo "[$(timestamp)] ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r sample_id read1 read2 <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"

if [ -z "${sample_id}" ] || [ -z "${read1}" ] || [ -z "${read2}" ]; then
  echo "[$(timestamp)] ERROR: Manifest row ${SLURM_ARRAY_TASK_ID} is malformed." >&2
  exit 1
fi

echo "[$(timestamp)] Sample: ${sample_id}"
echo "[$(timestamp)] Reads: ${read1} ${read2}"

if [ ! -s "${read1}" ] || [ ! -s "${read2}" ]; then
  echo "[$(timestamp)] ERROR: Paired trimmed reads missing or empty for ${sample_id}." >&2
  exit 1
fi

read1_base="$(basename "${read1}")"
read2_base="$(basename "${read2}")"

if [[ "${read1_base}" != *_1_paired.fq.gz ]]; then
  echo "[$(timestamp)] ERROR: R1 file does not match expected _1_paired.fq.gz suffix: ${read1}" >&2
  exit 1
fi

if [[ "${read2_base}" != *_2_paired.fq.gz ]]; then
  echo "[$(timestamp)] ERROR: R2 file does not match expected _2_paired.fq.gz suffix: ${read2}" >&2
  exit 1
fi

read1_prefix="${read1_base%_1_paired.fq.gz}"
read2_prefix="${read2_base%_2_paired.fq.gz}"

if [ "${read1_prefix}" != "${read2_prefix}" ] || [ "${sample_id}" != "${read1_prefix}" ]; then
  echo "[$(timestamp)] ERROR: Read pairing or sample naming mismatch for manifest row ${SLURM_ARRAY_TASK_ID}." >&2
  exit 1
fi

sam_file="${BAM_DIR}/${sample_id}.sam"
bam_file="${BAM_DIR}/${sample_id}.bam"
sorted_bam="${BAM_DIR}/${sample_id}.sorted.bam"
flagstat_file="${METRICS_DIR}/${sample_id}.flagstat.txt"
idxstats_file="${METRICS_DIR}/${sample_id}.idxstats.txt"

echo "[$(timestamp)] Running BWA-MEM."
bwa mem -t "${SLURM_CPUS_PER_TASK:-1}" "${REFERENCE_FASTA}" "${read1}" "${read2}" > "${sam_file}"

if [ ! -s "${sam_file}" ]; then
  echo "[$(timestamp)] ERROR: SAM output missing or empty for ${sample_id}." >&2
  exit 1
fi

echo "[$(timestamp)] Converting SAM to BAM."
samtools view -@ "${SLURM_CPUS_PER_TASK:-1}" -bS "${sam_file}" > "${bam_file}"

if [ ! -s "${bam_file}" ]; then
  echo "[$(timestamp)] ERROR: BAM output missing or empty for ${sample_id}." >&2
  exit 1
fi

echo "[$(timestamp)] Sorting BAM."
samtools sort -@ "${SLURM_CPUS_PER_TASK:-1}" -o "${sorted_bam}" "${bam_file}"

if [ ! -s "${sorted_bam}" ]; then
  echo "[$(timestamp)] ERROR: Sorted BAM missing or empty for ${sample_id}." >&2
  exit 1
fi

echo "[$(timestamp)] Indexing sorted BAM."
samtools index "${sorted_bam}"

if [ ! -s "${sorted_bam}.bai" ]; then
  echo "[$(timestamp)] ERROR: BAM index missing or empty for ${sample_id}." >&2
  exit 1
fi

echo "[$(timestamp)] Collecting alignment metrics."
samtools flagstat "${sorted_bam}" > "${flagstat_file}"
samtools idxstats "${sorted_bam}" > "${idxstats_file}"

if [ ! -s "${flagstat_file}" ] || [ ! -s "${idxstats_file}" ]; then
  echo "[$(timestamp)] ERROR: Alignment metrics missing or empty for ${sample_id}." >&2
  exit 1
fi

rm -f "${sam_file}" "${bam_file}"

echo "[$(timestamp)] Completed sample ${sample_id}"
echo "[$(timestamp)] Sorted BAM: ${sorted_bam}"
echo "[$(timestamp)] Metrics: ${flagstat_file} ${idxstats_file}"
echo "[$(timestamp)] END bwa_align_array.sh"
