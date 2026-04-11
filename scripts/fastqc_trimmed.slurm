#!/bin/bash
#SBATCH -J fastqc_trimmed
#SBATCH -p normal
#SBATCH -t 04:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=32G
#SBATCH -o trimmomatic/logs/slurm/fastqc_trimmed_%j.out
#SBATCH -e trimmomatic/logs/slurm/fastqc_trimmed_%j.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
elif script_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null)"; then
  SCRIPT_DIR="$(cd "$(dirname "${script_path}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

STEP_DIR="${PROJECT_DIR}/trimmomatic/fastqc_trimmed"
TRIMMED_DIR="${PROJECT_DIR}/trimmomatic/trimmed_reads"
REPORT_DIR="${STEP_DIR}/reports"
LOG_DIR="${STEP_DIR}/logs"
METRICS_DIR="${STEP_DIR}/metrics"
SLURM_LOG_DIR="${PROJECT_DIR}/trimmomatic/logs/slurm"
LOG_FILE="${LOG_DIR}/fastqc_trimmed.log"
MANIFEST_FILE="${METRICS_DIR}/fastqc_trimmed_manifest.tsv"

cd "$PROJECT_DIR"

mkdir -p "${REPORT_DIR}" "${LOG_DIR}" "${METRICS_DIR}" "${SLURM_LOG_DIR}"
touch "${LOG_FILE}"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

log() {
  echo "[$(timestamp)] $*" | tee -a "${LOG_FILE}"
}

module purge
module load fastqc/0.12.1

shopt -s nullglob
R1_FILES=("${TRIMMED_DIR}"/*_L7_1_paired.fq.gz)

log "START fastqc_trimmed.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Trimmed read directory: ${TRIMMED_DIR}"
log "Report directory: ${REPORT_DIR}"
log "Manifest path: ${MANIFEST_FILE}"

if [ "${#R1_FILES[@]}" -eq 0 ]; then
  log "ERROR: No forward trimmed reads matching *_L7_1_paired.fq.gz were found."
  exit 1
fi

TMP_MANIFEST="$(mktemp "${METRICS_DIR}/fastqc_trimmed_manifest.tmp.XXXXXX")"
printf "sample_id\ttrimmed_r1\ttrimmed_r2\tsample_report_dir\n" > "${TMP_MANIFEST}"

PAIR_COUNT=0

for trimmed_r1 in "${R1_FILES[@]}"; do
  sample_id="$(basename "${trimmed_r1}" "_L7_1_paired.fq.gz")"
  trimmed_r2="${TRIMMED_DIR}/${sample_id}_L7_2_paired.fq.gz"
  sample_report_dir="${REPORT_DIR}/${sample_id}"

  if [ ! -s "${trimmed_r1}" ]; then
    log "ERROR: Forward trimmed read is missing or empty for ${sample_id}: ${trimmed_r1}"
    rm -f "${TMP_MANIFEST}"
    exit 1
  fi

  if [ ! -s "${trimmed_r2}" ]; then
    log "ERROR: Reverse trimmed read is missing or empty for ${sample_id}: ${trimmed_r2}"
    rm -f "${TMP_MANIFEST}"
    exit 1
  fi

  printf "%s\t%s\t%s\t%s\n" \
    "${sample_id}" \
    "${trimmed_r1}" \
    "${trimmed_r2}" \
    "${sample_report_dir}" >> "${TMP_MANIFEST}"

  PAIR_COUNT=$((PAIR_COUNT + 1))
done

mv "${TMP_MANIFEST}" "${MANIFEST_FILE}"
log "Validated ${PAIR_COUNT} trimmed read pairs."

run_fastqc_for_sample() {
  local sample_id="$1"
  local trimmed_r1="$2"
  local trimmed_r2="$3"
  local sample_report_dir="$4"
  local r1_prefix
  local r2_prefix

  mkdir -p "${sample_report_dir}"

  log "Running FastQC for ${sample_id}"
  fastqc -t "${SLURM_CPUS_PER_TASK:-1}" -o "${sample_report_dir}" "${trimmed_r1}" "${trimmed_r2}"

  r1_prefix="$(basename "${trimmed_r1}" ".fq.gz")_fastqc"
  r2_prefix="$(basename "${trimmed_r2}" ".fq.gz")_fastqc"

  for output_file in \
    "${sample_report_dir}/${r1_prefix}.html" \
    "${sample_report_dir}/${r1_prefix}.zip" \
    "${sample_report_dir}/${r2_prefix}.html" \
    "${sample_report_dir}/${r2_prefix}.zip"; do
    if [ ! -s "${output_file}" ]; then
      log "ERROR: Expected FastQC output missing or empty: ${output_file}"
      exit 1
    fi
  done

  log "Completed FastQC for ${sample_id}"
}

if [ -n "${SLURM_ARRAY_TASK_ID:-}" ]; then
  mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")

  if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
    log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))."
    exit 1
  fi

  IFS=$'\t' read -r sample_id trimmed_r1 trimmed_r2 sample_report_dir <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"
  log "Array task ${SLURM_ARRAY_TASK_ID} processing ${sample_id}"
  run_fastqc_for_sample "${sample_id}" "${trimmed_r1}" "${trimmed_r2}" "${sample_report_dir}"
else
  log "No SLURM array index detected; processing all samples in one job."

  while IFS=$'\t' read -r sample_id trimmed_r1 trimmed_r2 sample_report_dir; do
    if [ "${sample_id}" = "sample_id" ]; then
      continue
    fi

    run_fastqc_for_sample "${sample_id}" "${trimmed_r1}" "${trimmed_r2}" "${sample_report_dir}"
  done < "${MANIFEST_FILE}"
fi

log "END fastqc_trimmed.slurm"
