#!/bin/bash
# Downsample taxon-filtered paired reads reproducibly.
# Submit after filtering: sbatch --array=0-2 scripts/downsample_taxon_filtered_reads_array.slurm

#SBATCH -J downsample_taxon_reads
#SBATCH -p normal
#SBATCH -t 6:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=16G
#SBATCH -o ambiguous_isolate_resolution/taxonomic_filtering/logs/downsample_taxon_reads_%A_%a.out
#SBATCH -e ambiguous_isolate_resolution/taxonomic_filtering/logs/downsample_taxon_reads_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MANIFEST_FILE="${MANIFEST_FILE:-configs/taxon_filter_manifest.tsv}"
STAGE_DIR="ambiguous_isolate_resolution/taxonomic_filtering"
FALLBACK_SCRIPT="scripts/downsample_paired_fastq.py"
SEED="${DOWNSAMPLE_SEED:-20260105}"

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

resolve_seqtk() {
  if command -v seqtk >/dev/null 2>&1; then
    return 0
  fi
  if initialize_modules; then
    module load seqtk >/dev/null 2>&1 || true
  fi
  command -v seqtk >/dev/null 2>&1
}

count_pairs_from_gzip() {
  local path="$1"
  gzip -cd "${path}" | awk 'END {print NR / 4}'
}

mkdir -p "${STAGE_DIR}/logs" "${STAGE_DIR}/downsampled_reads"
require_file "${MANIFEST_FILE}" "Taxon filter manifest"

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")
if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r sample_id r1 r2 kraken_output kraken_report target_taxon_name target_taxid filter_mode downsample_pairs <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"

filtered_r1="${STAGE_DIR}/filtered_reads/${sample_id}.${target_taxon_name}.R1.filtered.fq.gz"
filtered_r2="${STAGE_DIR}/filtered_reads/${sample_id}.${target_taxon_name}.R2.filtered.fq.gz"
out_r1="${STAGE_DIR}/downsampled_reads/${sample_id}.${target_taxon_name}.R1.downsampled.fq.gz"
out_r2="${STAGE_DIR}/downsampled_reads/${sample_id}.${target_taxon_name}.R2.downsampled.fq.gz"

require_file "${filtered_r1}" "Filtered R1"
require_file "${filtered_r2}" "Filtered R2"

pair_count="$(count_pairs_from_gzip "${filtered_r1}")"
log "Sample: ${sample_id}; filtered_pairs=${pair_count}; requested_pairs=${downsample_pairs}; seed=${SEED}"

if [ "${pair_count}" -le "${downsample_pairs}" ]; then
  cp -p "${filtered_r1}" "${out_r1}"
  cp -p "${filtered_r2}" "${out_r2}"
  log "Filtered read count is below or equal to target; copied all pairs."
elif resolve_seqtk; then
  fraction="$(awk -v n="${downsample_pairs}" -v total="${pair_count}" 'BEGIN {printf "%.12f", n / total}')"
  seqtk sample -s"${SEED}" "${filtered_r1}" "${fraction}" | gzip -c > "${out_r1}"
  seqtk sample -s"${SEED}" "${filtered_r2}" "${fraction}" | gzip -c > "${out_r2}"
  log "Downsampled with seqtk using fraction ${fraction}."
else
  require_file "${FALLBACK_SCRIPT}" "Python fallback downsampling script"
  python3 "${FALLBACK_SCRIPT}" \
    --r1 "${filtered_r1}" \
    --r2 "${filtered_r2}" \
    --out-r1 "${out_r1}" \
    --out-r2 "${out_r2}" \
    --pairs "${downsample_pairs}" \
    --seed "${SEED}"
fi

require_file "${out_r1}" "Downsampled R1"
require_file "${out_r2}" "Downsampled R2"
log "Completed downsampling for ${sample_id}"
