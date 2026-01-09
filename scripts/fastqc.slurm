#!/bin/bash
#SBATCH -J fastqc
#SBATCH -p normal
#SBATCH -t 04:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=32G
#SBATCH -o fastqc_%j.out
#SBATCH -e fastqc_%j.err

set -euo pipefail

PROJECT_DIR="${SLURM_SUBMIT_DIR}"
FQ_DIR="${PROJECT_DIR}/fq_raw"
OUT_DIR="${PROJECT_DIR}/fastqc"

cd "$PROJECT_DIR"

module purge
module load fastqc/0.12.1

mkdir -p "$OUT_DIR"

shopt -s nullglob
FILES=("$FQ_DIR"/*.fq.gz)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "ERROR: No .fq.gz files found in: $FQ_DIR" >&2
  exit 1
fi

# Run FastQC (no srun needed on this cluster)
fastqc -t "${SLURM_CPUS_PER_TASK:-1}" -o "$OUT_DIR" "${FILES[@]}"

echo "Done. FastQC reports are in: $OUT_DIR"
