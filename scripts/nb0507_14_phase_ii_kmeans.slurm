#!/bin/bash
# Submit from project root after confirming Python dependencies.
# sbatch scripts/nb0507_14_phase_ii_kmeans.slurm
# Optional: sbatch --export=ALL,RUN_ID=baseline_YYYYMMDD_v2 scripts/nb0507_14_phase_ii_kmeans.slurm
# Requires numpy, scikit-learn, matplotlib in PYTHON_BIN's environment.
#SBATCH --job-name=nb14_kmeans_p2
#SBATCH --partition=normal
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=comparison_nb0507_14_resequencing/phase_ii_kmeans/logs/kmeans_%j.out
#SBATCH --error=comparison_nb0507_14_resequencing/phase_ii_kmeans/logs/kmeans_%j.err

set -euo pipefail
: "${SLURM_SUBMIT_DIR:?Submit from the project root with sbatch}"
cd "${SLURM_SUBMIT_DIR}"
[[ -s PROJECT_BRIEF.md ]] || { echo 'ERROR: wrong submission directory' >&2; exit 1; }
[[ -d comparison_nb0507_14_resequencing/phase_ii_kmeans/logs ]] || {
  echo 'ERROR: create phase_ii_kmeans/logs before submitting' >&2; exit 1;
}

PYTHON_BIN="${PYTHON_BIN:-python3}"
RUN_ID="${RUN_ID:-baseline_seed20261102}"
[[ "${RUN_ID}" =~ ^[A-Za-z0-9_-]+$ ]] || { echo 'ERROR: invalid RUN_ID' >&2; exit 1; }
OUTPUT="comparison_nb0507_14_resequencing/phase_ii_kmeans/${RUN_ID}"
[[ ! -e "${OUTPUT}" ]] || { echo "ERROR: output already exists: ${OUTPUT}" >&2; exit 1; }
command -v "${PYTHON_BIN}" >/dev/null || { echo "ERROR: Python unavailable: ${PYTHON_BIN}" >&2; exit 1; }
"${PYTHON_BIN}" -c 'import numpy, sklearn, matplotlib; print("numpy", numpy.__version__, "sklearn", sklearn.__version__, "matplotlib", matplotlib.__version__)'

export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
export OPENBLAS_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
"${PYTHON_BIN}" scripts/nb0507_14_phase_ii_kmeans.py \
  --master comparison_nb0507_14_resequencing/metrics/downsampled_old.master_contig_table.tsv \
  --original comparison_nb0507_14_resequencing/downsampled_old_self_mapping/NB0507_14_downsampled/metrics/NB0507_14_downsampled.master_contig_table.tsv \
  --candidate-ids comparison_nb0507_14_resequencing/reyranella_validation/reyranella_1kb_ids.txt \
  --output "${OUTPUT}" --seed 20261102 --silhouette-sample 2000
[[ -s "${OUTPUT}/COMPLETE" && -s "${OUTPUT}/cluster_metrics.tsv" && -s "${OUTPUT}/assignments.tsv" ]] || {
  echo 'ERROR: expected outputs missing' >&2; exit 1;
}
echo "Completed ${OUTPUT}"
