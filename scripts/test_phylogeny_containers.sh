#!/usr/bin/env bash
set -euo pipefail

# Lightweight checks for the phylogeny containers. This does not run Parsnp,
# IQ-TREE, or RAxML analyses.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

PARSNP_CONTAINER="containers/parsnp_2.1.5.sif"
IQTREE_CONTAINER="containers/iqtree_2.4.0.sif"
RAXML_CONTAINER="containers/raxmlng_2.0.0.sif"

require_file() {
  local path="$1"
  local label="$2"

  if [[ ! -s "${path}" ]]; then
    printf 'ERROR: %s missing or empty: %s\n' "${label}" "${path}" >&2
    exit 1
  fi
}

if ! command -v singularity >/dev/null 2>&1; then
  printf 'ERROR: singularity is not available on PATH.\n' >&2
  exit 1
fi

require_file "${PARSNP_CONTAINER}" "Parsnp container"
require_file "${IQTREE_CONTAINER}" "IQ-TREE container"
require_file "${RAXML_CONTAINER}" "RAxML-NG container"

printf 'Checking Parsnp container...\n'
singularity exec containers/parsnp_2.1.5.sif parsnp --help >/dev/null

printf 'Checking IQ-TREE container...\n'
singularity exec containers/iqtree_2.4.0.sif iqtree2 --version

printf 'Checking RAxML-NG container...\n'
singularity exec containers/raxmlng_2.0.0.sif raxml-ng --help >/dev/null

cat <<'NEXT'

Container checks passed.

To stage Parsnp inputs:
  bash scripts/prepare_expanded_vv_parsnp_inputs.sh

To submit the Parsnp alignment job:
  sbatch scripts/parsnp_expanded_vv_46.slurm

After Parsnp completes, review:
  phylogeny/expanded_vv_46/alignment/parsnp/parsnp.xmfa
  phylogeny/expanded_vv_46/alignment/parsnp/parsnp.tree
  phylogeny/expanded_vv_46/alignment/parsnp/parsnp.snps.mblocks
  phylogeny/expanded_vv_46/alignment/parsnp/parsnp.ggr

Do not run IQ-TREE or RAxML until the Parsnp alignment has been reviewed and converted/prepared for downstream tree building.
Placeholder commands are written by the prep script to:
  phylogeny/expanded_vv_46/metadata/downstream_tree_commands.sh
NEXT
