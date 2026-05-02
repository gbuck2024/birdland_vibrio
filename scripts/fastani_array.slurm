#!/bin/bash
# Run ANI comparisons for assembled query genomes against the saved reference set.
# Submit as a SLURM array job; do not run ANI searches on a login node.
#
# How to run:
# 1. Submit one ANI task per assembled sample:
#    sbatch --array=0-N scripts/fastani_array.slurm
# 2. After the array job completes, generate the curated ANI summaries:
#    sbatch --export=ALL,ANI_MODE=summary scripts/fastani_array.slurm

#SBATCH -J fastani
#SBATCH -p normal
#SBATCH -t 08:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=32G
#SBATCH -o ani/logs/slurm/fastani_%A_%a.out
#SBATCH -e ani/logs/slurm/fastani_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MODE="${ANI_MODE:-compare}"
QUERY_MANIFEST="${QUERY_MANIFEST:-configs/ani_query_manifest.tsv}"
REFERENCE_MANIFEST_DEFAULT="${REFERENCE_MANIFEST:-configs/ani_reference_manifest.tsv}"
REFERENCE_MANIFEST_FALLBACK="configs/multi_reference_reference_manifest.tsv"
STAGE_DIR="${STAGE_DIR:-ani}"
OUTPUT_DIR="${STAGE_DIR}/outputs"
METRICS_DIR="${STAGE_DIR}/metrics"
LOG_DIR="${STAGE_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
SUMMARY_SCRIPT="${SUMMARY_SCRIPT:-scripts/summarize_fastani.py}"

FASTANI_BIN="${FASTANI_BIN:-fastANI}"
FASTANI_THREADS="${SLURM_CPUS_PER_TASK:-8}"
FASTANI_FRAGLEN="${FASTANI_FRAGLEN:-3000}"
FASTANI_KMER="${FASTANI_KMER:-16}"
FASTANI_MIN_FRACTION="${FASTANI_MIN_FRACTION:-0.2}"
FASTANI_EXTRA_ARGS="${FASTANI_EXTRA_ARGS:-}"

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

require_path_exists() {
  local path="$1"
  local label="$2"

  if [ ! -e "${path}" ]; then
    log "ERROR: ${label} not found: ${path}" >&2
    exit 1
  fi
}

resolve_reference_manifest() {
  if [ -s "${REFERENCE_MANIFEST_DEFAULT}" ]; then
    printf '%s\n' "${REFERENCE_MANIFEST_DEFAULT}"
    return 0
  fi

  if [ -s "${REFERENCE_MANIFEST_FALLBACK}" ]; then
    printf '%s\n' "${REFERENCE_MANIFEST_FALLBACK}"
    return 0
  fi

  local autodetect_manifest
  autodetect_manifest="${METRICS_DIR}/ani_reference_manifest_autodetected.tsv"
  printf 'reference_id\treference_fasta\treference_format\tnotes\n' > "${autodetect_manifest}"

  local found=0
  while IFS= read -r fasta_path; do
    found=1
    fasta_rel="${fasta_path#./}"
    fasta_base="$(basename "${fasta_rel}")"
    reference_id="${fasta_base%_ref.fasta}"
    reference_id="${reference_id%.fasta}"
    printf '%s\t%s\t%s\t%s\n' \
      "${reference_id}" \
      "${fasta_rel}" \
      "autodetected_reference" \
      "Autodetected from the reference directory because no ANI reference manifest was found." \
      >> "${autodetect_manifest}"
  done < <(find . -maxdepth 2 -path './reference/*.fasta' -type f | sort)

  if [ "${found}" -eq 0 ]; then
    rm -f "${autodetect_manifest}"
    log "ERROR: No reference FASTA files found under reference/ and no ANI reference manifest is available." >&2
    exit 1
  fi

  printf '%s\n' "${autodetect_manifest}"
}

mkdir -p "${OUTPUT_DIR}" "${METRICS_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}"

REFERENCE_MANIFEST="$(resolve_reference_manifest)"

log "START fastani_array.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Mode: ${MODE}"
log "Stage directory: ${STAGE_DIR}"
log "Query manifest: ${QUERY_MANIFEST}"
log "Reference manifest: ${REFERENCE_MANIFEST}"

require_file "${QUERY_MANIFEST}" "ANI query manifest"
require_file "${REFERENCE_MANIFEST}" "ANI reference manifest"

if [ "${MODE}" = "summary" ]; then
  require_file "${SUMMARY_SCRIPT}" "ANI summary script"
  python3 "${SUMMARY_SCRIPT}"
  log "END fastani_array.slurm"
  exit 0
fi

if [ "${MODE}" != "compare" ]; then
  log "ERROR: Unsupported ANI_MODE='${MODE}'. Use 'compare' or 'summary'." >&2
  exit 1
fi

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit ANI compare mode with sbatch --array=0-N." >&2
  exit 1
fi

if ! command -v "${FASTANI_BIN}" >/dev/null 2>&1; then
  if command -v module >/dev/null 2>&1; then
    module purge
    if module load fastani >/dev/null 2>&1 && command -v "${FASTANI_BIN}" >/dev/null 2>&1; then
      log "Loaded fastANI via environment module 'fastani'."
    elif module load FastANI >/dev/null 2>&1 && command -v "${FASTANI_BIN}" >/dev/null 2>&1; then
      log "Loaded fastANI via environment module 'FastANI'."
    else
      log "ERROR: fastANI executable not found. Set FASTANI_BIN or load/install fastANI before submission." >&2
      exit 1
    fi
  else
    log "ERROR: fastANI executable not found. Set FASTANI_BIN or install fastANI before submission." >&2
    exit 1
  fi
fi

mapfile -t QUERY_ROWS < <(tail -n +2 "${QUERY_MANIFEST}")

if [ "${#QUERY_ROWS[@]}" -eq 0 ]; then
  log "ERROR: ANI query manifest contains no sample rows." >&2
  exit 1
fi

if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#QUERY_ROWS[@]}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#QUERY_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r sample_id query_fasta <<< "${QUERY_ROWS[${SLURM_ARRAY_TASK_ID}]}"

if [ -z "${sample_id}" ] || [ -z "${query_fasta}" ]; then
  log "ERROR: Query manifest row ${SLURM_ARRAY_TASK_ID} is malformed." >&2
  exit 1
fi

require_file "${query_fasta}" "ANI query FASTA"

query_base="$(basename "${query_fasta}")"
if [ "${query_base}" != "contigs.fasta" ] && [ "${query_base}" != "scaffolds.fasta" ]; then
  log "ERROR: ANI query FASTA must be an assembly contig or scaffold FASTA: ${query_fasta}" >&2
  exit 1
fi

reference_list_file="${METRICS_DIR}/fastani_reference_list.txt"
awk -F '\t' 'NR > 1 {print $2}' "${REFERENCE_MANIFEST}" > "${reference_list_file}"
require_file "${reference_list_file}" "ANI reference list"

while IFS= read -r reference_fasta; do
  require_file "${reference_fasta}" "Reference FASTA listed for ANI"
done < "${reference_list_file}"

sample_output="${OUTPUT_DIR}/${sample_id}.fastani.tsv"
rm -f "${sample_output}"

log "Sample: ${sample_id}"
log "Query FASTA: ${query_fasta}"
log "Raw output: ${sample_output}"

"${FASTANI_BIN}" \
  --query "${query_fasta}" \
  --rl "${reference_list_file}" \
  --output "${sample_output}" \
  --threads "${FASTANI_THREADS}" \
  --fragLen "${FASTANI_FRAGLEN}" \
  --kmer "${FASTANI_KMER}" \
  --minFraction "${FASTANI_MIN_FRACTION}" \
  ${FASTANI_EXTRA_ARGS}

require_path_exists "${sample_output}" "Raw fastANI output"

log "Completed ANI comparison for ${sample_id}"
log "END fastani_array.slurm"
