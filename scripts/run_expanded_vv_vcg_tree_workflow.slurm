#!/bin/bash
# Submit the expanded 46-genome vcg-marker workflow as one SLURM job.
# This runs BLAST, extraction, MAFFT, FastTree, and the R visualization in order.

#SBATCH -J expanded_vcg_tree
#SBATCH -p normal
#SBATCH -t 04:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem=16G
#SBATCH -o phylogeny/expanded_vv_46/vcg_tree/logs/expanded_vcg_tree_%j.out
#SBATCH -e phylogeny/expanded_vv_46/vcg_tree/logs/expanded_vcg_tree_%j.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

echo "[$(timestamp)] START expanded 46-genome vcg-marker SLURM workflow"
echo "[$(timestamp)] Project directory: ${PROJECT_DIR}"
echo "[$(timestamp)] SLURM job ID: ${SLURM_JOB_ID:-not_set}"

mkdir -p phylogeny/expanded_vv_46/vcg_tree/logs

echo "[$(timestamp)] Step 1/5: mine vcg alleles"
bash scripts/mine_expanded_vv_vcg.sh

echo "[$(timestamp)] Step 2/5: extract best vcg sequences"
bash scripts/extract_expanded_vv_vcg_sequences.sh

echo "[$(timestamp)] Step 3/5: align vcg sequences with MAFFT"
bash scripts/align_expanded_vv_vcg_mafft.sh

echo "[$(timestamp)] Step 4/5: build vcg FastTree"
bash scripts/build_expanded_vv_vcg_fasttree.sh

echo "[$(timestamp)] Step 5/5: plot vcg tree"
if command -v module >/dev/null 2>&1; then
  module load R/gcc11/4.4.0
fi
Rscript scripts/plot_expanded_vv_vcg_tree.R

echo "[$(timestamp)] END expanded 46-genome vcg-marker SLURM workflow"
