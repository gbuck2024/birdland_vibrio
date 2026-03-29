#!/bin/bash
#SBATCH -J trimmomatic_pe
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -o trimmomatic/logs/slurm/trimmomatic_%A_%a.out
#SBATCH -e trimmomatic/logs/slurm/trimmomatic_%A_%a.err

set -euo pipefail

export TMPDIR="/tmp/$USER/trimmomatic_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
mkdir -p "$TMPDIR"

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

STEP_DIR="${PROJECT_DIR}/trimmomatic"
COPY_DIR="${STEP_DIR}/copied_reads"
TRIMMED_DIR="${STEP_DIR}/trimmed_reads"
UNPAIRED_DIR="${STEP_DIR}/unpaired_reads"
LOG_DIR="${STEP_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
METRICS_DIR="${STEP_DIR}/metrics"
MANIFEST_FILE="${METRICS_DIR}/trimmomatic_input_manifest.tsv"

TRIMMOMATIC_JAR="/cm/shared/tamucc/apps/trimmomatic/0.39/dist/jar/trimmomatic-0.39.jar"
ADAPTER_FILE="/cm/shared/tamucc/apps/trimmomatic/0.39/adapters/TruSeq3-PE.fa"

mkdir -p "${TRIMMED_DIR}" "${UNPAIRED_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}" "${METRICS_DIR}"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

cleanup() {
  rm -rf "${TMPDIR}"
}
trap cleanup EXIT

echo "[$(timestamp)] START trimmomatic_array.slurm"
echo "[$(timestamp)] Project directory: ${PROJECT_DIR}"
echo "[$(timestamp)] Manifest: ${MANIFEST_FILE}"
echo "[$(timestamp)] TMPDIR: ${TMPDIR}"

if [ ! -f "${MANIFEST_FILE}" ]; then
  echo "[$(timestamp)] ERROR: Manifest not found. Run prepare_trimmomatic_inputs.sh first." >&2
  exit 1
fi

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  echo "[$(timestamp)] ERROR: Submit this script with sbatch --array=0-N." >&2
  exit 1
fi

module purge
module load trimmomatic/0.39

if [ ! -f "${TRIMMOMATIC_JAR}" ] || [ ! -f "${ADAPTER_FILE}" ]; then
  echo "[$(timestamp)] ERROR: Trimmomatic JAR or adapter FASTA is unavailable." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")

if [ "${#SAMPLE_ROWS[@]}" -eq 0 ]; then
  echo "[$(timestamp)] ERROR: Manifest contains no samples." >&2
  exit 1
fi

if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
  echo "[$(timestamp)] ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r sample_id raw_r1 raw_r2 copy_r1 copy_r2 raw_r1_bytes raw_r2_bytes <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"

echo "[$(timestamp)] Sample: ${sample_id}"
echo "[$(timestamp)] Copied inputs: ${copy_r1} ${copy_r2}"

if [ ! -s "${copy_r1}" ] || [ ! -s "${copy_r2}" ]; then
  echo "[$(timestamp)] ERROR: Copied FASTQ inputs are missing or empty for ${sample_id}." >&2
  exit 1
fi

if [ "$(stat -c '%s' "${copy_r1}")" -ne "${raw_r1_bytes}" ] || [ "$(stat -c '%s' "${copy_r2}")" -ne "${raw_r2_bytes}" ]; then
  echo "[$(timestamp)] ERROR: Copied input sizes no longer match manifest for ${sample_id}." >&2
  exit 1
fi

paired_r1="${TRIMMED_DIR}/${sample_id}_L7_1_paired.fq.gz"
unpaired_r1="${UNPAIRED_DIR}/${sample_id}_L7_1_unpaired.fq.gz"
paired_r2="${TRIMMED_DIR}/${sample_id}_L7_2_paired.fq.gz"
unpaired_r2="${UNPAIRED_DIR}/${sample_id}_L7_2_unpaired.fq.gz"

echo "[$(timestamp)] Trimming with adapter clipping and quality-tail filtering."

java -jar "${TRIMMOMATIC_JAR}" PE \
  -threads "${SLURM_CPUS_PER_TASK:-1}" \
  -phred33 \
  "${copy_r1}" \
  "${copy_r2}" \
  "${paired_r1}" \
  "${unpaired_r1}" \
  "${paired_r2}" \
  "${unpaired_r2}" \
  ILLUMINACLIP:"${ADAPTER_FILE}":2:30:10 \
  LEADING:3 \
  TRAILING:3 \
  SLIDINGWINDOW:4:20 \
  MINLEN:50

for output_file in "${paired_r1}" "${paired_r2}"; do
  if [ ! -s "${output_file}" ]; then
    echo "[$(timestamp)] ERROR: Expected paired output missing or empty: ${output_file}" >&2
    exit 1
  fi
done

for output_file in "${unpaired_r1}" "${unpaired_r2}"; do
  if [ ! -f "${output_file}" ]; then
    echo "[$(timestamp)] ERROR: Expected unpaired output file missing: ${output_file}" >&2
    exit 1
  fi
done

echo "[$(timestamp)] Completed sample ${sample_id}"
echo "[$(timestamp)] Paired outputs: ${paired_r1} ${paired_r2}"
echo "[$(timestamp)] Unpaired outputs: ${unpaired_r1} ${unpaired_r2}"
echo "[$(timestamp)] END trimmomatic_array.slurm"
