#!/usr/bin/env bash
# Run the expanded 46-genome vcg-marker workflow in order.
# Submit this script to SLURM or run only in an interactive compute allocation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

echo "START expanded 46-genome vcg-marker workflow: $(date '+%Y-%m-%d %H:%M:%S %Z')"

bash scripts/mine_expanded_vv_vcg.sh
bash scripts/extract_expanded_vv_vcg_sequences.sh
bash scripts/align_expanded_vv_vcg_mafft.sh
bash scripts/build_expanded_vv_vcg_fasttree.sh
Rscript scripts/plot_expanded_vv_vcg_tree.R

echo "END expanded 46-genome vcg-marker workflow: $(date '+%Y-%m-%d %H:%M:%S %Z')"
