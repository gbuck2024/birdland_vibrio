#!/bin/bash
# Run reciprocal FastANI for old NB0507-14 and new SRR37852095_L7 assemblies.

#SBATCH -J nb0507_fastani
#SBATCH -p normal
#SBATCH -t 04:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem=16G
#SBATCH -o comparison_nb0507_14_resequencing/ani/logs/fastani_%j.out
#SBATCH -e comparison_nb0507_14_resequencing/ani/logs/fastani_%j.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

OLD_ID="Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7"
NEW_ID="SRR37852095_L7"
OLD_FASTA="assembly/assemblies/${OLD_ID}/contigs.fasta"
NEW_FASTA="assembly_sra/assemblies/${NEW_ID}/contigs.fasta"
STAGE_DIR="comparison_nb0507_14_resequencing/ani"
OUT_DIR="${STAGE_DIR}/outputs"
METRICS_DIR="${STAGE_DIR}/metrics"
LOG_DIR="${STAGE_DIR}/logs"
THREADS="${SLURM_CPUS_PER_TASK:-4}"
FASTANI_BIN="${FASTANI_BIN:-fastANI}"
SINGULARITY_BIN="${SINGULARITY_BIN:-singularity}"

if [ -n "${FASTANI_SIF:-}" ]; then
  FASTANI_SIF_PATH="${FASTANI_SIF}"
elif [ -s "containers/fastani_latest.sif" ]; then
  FASTANI_SIF_PATH="containers/fastani_latest.sif"
elif [ -s "containers/fastani.sif" ]; then
  FASTANI_SIF_PATH="containers/fastani.sif"
else
  FASTANI_SIF_PATH="fastani_latest.sif"
fi

mkdir -p "${OUT_DIR}" "${METRICS_DIR}" "${LOG_DIR}"
for path in "${OLD_FASTA}" "${NEW_FASTA}"; do
  if [ ! -s "${path}" ]; then
    echo "ERROR: Missing assembly FASTA: ${path}" >&2
    exit 1
  fi
done

run_fastani() {
  local query="$1"
  local reference="$2"
  local output="$3"
  if command -v "${FASTANI_BIN}" >/dev/null 2>&1; then
    "${FASTANI_BIN}" -q "${query}" -r "${reference}" -o "${output}" -t "${THREADS}"
  else
    if [ ! -s "${FASTANI_SIF_PATH}" ]; then
      echo "ERROR: fastANI not found and container is missing: ${FASTANI_SIF_PATH}" >&2
      exit 1
    fi
    "${SINGULARITY_BIN}" exec --cleanenv --bind "${PROJECT_DIR}:${PROJECT_DIR}" "${FASTANI_SIF_PATH}" \
      fastANI -q "${PROJECT_DIR}/${query}" -r "${PROJECT_DIR}/${reference}" -o "${PROJECT_DIR}/${output}" -t "${THREADS}"
  fi
}

run_fastani "${OLD_FASTA}" "${NEW_FASTA}" "${OUT_DIR}/${OLD_ID}_vs_${NEW_ID}.tsv"
run_fastani "${NEW_FASTA}" "${OLD_FASTA}" "${OUT_DIR}/${NEW_ID}_vs_${OLD_ID}.tsv"
python3 scripts/summarize_nb0507_14_resequencing.py
