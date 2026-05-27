#!/usr/bin/env bash
set -euo pipefail

# Placeholder maximum-likelihood tree commands for after Parsnp alignment review.
# Do not run these until the Parsnp XMFA has been converted or otherwise prepared
# into a tree-builder-compatible core-genome alignment FASTA/PHYLIP.

CORE_ALIGNMENT="phylogeny/expanded_vv_46/alignment/core_genome_alignment.fasta"
IQTREE_PREFIX="phylogeny/expanded_vv_46/tree/iqtree_expanded_vv_46"
RAXML_PREFIX="raxmlng_expanded_vv_46"
RAXML_DIR="phylogeny/expanded_vv_46/tree"

singularity exec containers/iqtree_2.4.0.sif iqtree2 \
  -s "${CORE_ALIGNMENT}" \
  -m MFP \
  -B 1000 \
  -alrt 1000 \
  -T AUTO \
  --prefix "${IQTREE_PREFIX}"

singularity exec containers/raxmlng_2.0.0.sif raxml-ng \
  --all \
  --msa "${CORE_ALIGNMENT}" \
  --model GTR+G \
  --bs-trees 100 \
  --threads auto \
  --prefix "${RAXML_PREFIX}" \
  --redo \
  --tree pars{10},rand{10} \
  --working-dir "${RAXML_DIR}"
