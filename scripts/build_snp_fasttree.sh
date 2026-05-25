#!/bin/bash
# Build an approximate maximum-likelihood tree from the core SNP alignment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

CORE_FASTA="${1:-snp_phylogeny/core_alignment/core_snps.fasta}"
TREE_DIR="snp_phylogeny/tree"
TREE_FILE="${TREE_DIR}/core_snps.fasttree.nwk"
LOG_DIR="snp_phylogeny/logs"
LOG_FILE="${LOG_DIR}/build_snp_fasttree.log"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

mkdir -p "${TREE_DIR}" "${LOG_DIR}"

{
  echo "[$(timestamp)] START build_snp_fasttree.sh"
  echo "[$(timestamp)] Core SNP FASTA: ${CORE_FASTA}"

  if [ ! -s "${CORE_FASTA}" ]; then
    echo "[$(timestamp)] ERROR: Core SNP FASTA missing or empty: ${CORE_FASTA}" >&2
    exit 1
  fi

  if ! grep -q '^>' "${CORE_FASTA}"; then
    echo "[$(timestamp)] ERROR: Core SNP FASTA has no sequence headers: ${CORE_FASTA}" >&2
    exit 1
  fi

  module purge
  module load fasttree/2.1.11

  FastTree -nt -gtr "${CORE_FASTA}" > "${TREE_FILE}"

  if [ ! -s "${TREE_FILE}" ]; then
    echo "[$(timestamp)] ERROR: FastTree output missing or empty: ${TREE_FILE}" >&2
    exit 1
  fi

  echo "[$(timestamp)] Tree: ${TREE_FILE}"
  echo "[$(timestamp)] END build_snp_fasttree.sh"
} 2>&1 | tee "${LOG_FILE}"
