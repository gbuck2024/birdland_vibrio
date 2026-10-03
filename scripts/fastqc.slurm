#!/bin/bash
#SBATCH -J fastqc
#SBATCH -p normal
#SBATCH -t 04:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=32G
#SBATCH -o fastqc/logs/slurm/fastqc_%j.out
#SBATCH -e fastqc/logs/slurm/fastqc_%j.err

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

FQ_DIR="${PROJECT_DIR}/fq_raw"
OUT_DIR="${PROJECT_DIR}/fastqc"
SLURM_LOG_DIR="${OUT_DIR}/logs/slurm"
FASTQC_INPUT_GLOB="${FASTQC_INPUT_GLOB:-*.fq.gz}"

cd "$PROJECT_DIR"

module purge
module load fastqc/0.12.1

mkdir -p "$OUT_DIR" "$SLURM_LOG_DIR"

shopt -s nullglob
FILES=("$FQ_DIR"/$FASTQC_INPUT_GLOB)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "ERROR: No files matched FASTQC_INPUT_GLOB='$FASTQC_INPUT_GLOB' in: $FQ_DIR" >&2
  exit 1
fi

echo "Project directory: $PROJECT_DIR"
echo "Raw read directory: $FQ_DIR"
echo "Output directory: $OUT_DIR"
echo "FASTQC_INPUT_GLOB: $FASTQC_INPUT_GLOB"
echo "Selected input files (${#FILES[@]}):"
printf '  %s\n' "${FILES[@]}"

# Run FastQC (no srun needed on this cluster)
fastqc -t "${SLURM_CPUS_PER_TASK:-1}" -o "$OUT_DIR" "${FILES[@]}"

echo "Done. FastQC reports are in: $OUT_DIR"
