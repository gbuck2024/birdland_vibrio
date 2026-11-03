#!/bin/bash
# Submit from project root: sbatch scripts/nb0507_14_phase_ii_cluster_biology.slurm
# Optional new run: sbatch --export=ALL,RUN_ID=biology_YYYYMMDD_v2 scripts/nb0507_14_phase_ii_cluster_biology.slurm
#SBATCH --job-name=nb14_p2_biology
#SBATCH --partition=normal
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --output=comparison_nb0507_14_resequencing/phase_ii_cluster_biology/logs/biology_%j.out
#SBATCH --error=comparison_nb0507_14_resequencing/phase_ii_cluster_biology/logs/biology_%j.err

set -euo pipefail
: "${SLURM_SUBMIT_DIR:?Submit from project root}"
cd "${SLURM_SUBMIT_DIR}"
[[ -s PROJECT_BRIEF.md ]] || { echo 'ERROR: wrong submission directory' >&2; exit 1; }
STAGE=comparison_nb0507_14_resequencing/phase_ii_cluster_biology
[[ -d "${STAGE}/logs" ]] || { echo 'ERROR: missing log directory' >&2; exit 1; }
RUN_ID="${RUN_ID:-biology_20261102}"
[[ "${RUN_ID}" =~ ^[A-Za-z0-9_-]+$ ]] || { echo 'ERROR: invalid RUN_ID' >&2; exit 1; }
OUTPUT="${STAGE}/${RUN_ID}"
[[ ! -e "${OUTPUT}" ]] || { echo "ERROR: output exists: ${OUTPUT}" >&2; exit 1; }
PYTHON_BIN="${PYTHON_BIN:-python3}"
command -v "${PYTHON_BIN}" >/dev/null || { echo "ERROR: unavailable Python: ${PYTHON_BIN}" >&2; exit 1; }
"${PYTHON_BIN}" scripts/nb0507_14_phase_ii_cluster_biology.py \
  --master comparison_nb0507_14_resequencing/metrics/downsampled_old.master_contig_table.tsv \
  --candidate-ids comparison_nb0507_14_resequencing/reyranella_validation/reyranella_1kb_ids.txt \
  --baseline comparison_nb0507_14_resequencing/phase_ii_kmeans/baseline_seed20261102 \
  --ablation comparison_nb0507_14_resequencing/phase_ii_feature_ablation/ablation_seed20261102 \
  --output "${OUTPUT}"
[[ -s "${OUTPUT}/COMPLETE" && -s "${OUTPUT}/report.md" && -s "${OUTPUT}/figures/composition_k5.svg" ]] || {
  echo 'ERROR: expected outputs missing' >&2; exit 1;
}
echo "Validated ${OUTPUT}"
