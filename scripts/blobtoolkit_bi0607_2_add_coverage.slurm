#!/bin/bash
#SBATCH -J btk_bi0607_2_addcov
#SBATCH -p normal
#SBATCH -t 02:00:00
#SBATCH -N 1
#SBATCH -n 1 
#SBATCH -c 4
#SBATCH --mem=16G
#SBATCH -o ambiguous_isolate_resolution/blobtoolkit/BI0607_2/logs/slurm/addcov_%j.out
#SBATCH -e ambiguous_isolate_resolution/blobtoolkit/BI0607_2/logs/slurm/addcov_%j.err

set -euo pipefail

cd "${SLURM_SUBMIT_DIR}"

source /cm/shared/tamucc/apps/miniconda3/24.1.2/etc/profile.d/conda.sh
conda activate blobtoolkit

blobtools add \
  --cov ambiguous_isolate_resolution/blobtoolkit/BI0607_2/bam/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7.self_contigs.sorted.bam \
  ambiguous_isolate_resolution/blobtoolkit/BI0607_2/blobdir
