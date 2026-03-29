#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST_FILE="${PROJECT_DIR}/trimmomatic/metrics/trimmomatic_input_manifest.tsv"
SLURM_SCRIPT="scripts/trimmomatic_array.slurm"

cd "${PROJECT_DIR}"

if [ ! -f "${MANIFEST_FILE}" ]; then
  echo "ERROR: Missing manifest ${MANIFEST_FILE}. Run scripts/prepare_trimmomatic_inputs.sh first." >&2
  exit 1
fi

sample_count="$(tail -n +2 "${MANIFEST_FILE}" | wc -l)"
if [ "${sample_count}" -le 0 ]; then
  echo "ERROR: Manifest ${MANIFEST_FILE} contains no samples." >&2
  exit 1
fi

mkdir -p trimmomatic/logs/slurm

array_end=$((sample_count - 1))
echo "Submitting Trimmomatic array for ${sample_count} samples with range 0-${array_end}"
sbatch --array="0-${array_end}" "${SLURM_SCRIPT}"
