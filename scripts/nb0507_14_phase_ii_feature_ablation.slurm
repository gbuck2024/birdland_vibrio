#!/bin/bash
# Submit from project root; Python module is loaded below.
# sbatch scripts/nb0507_14_phase_ii_feature_ablation.slurm
#SBATCH --job-name=nb14_p2_ablation
#SBATCH --partition=normal
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=comparison_nb0507_14_resequencing/phase_ii_feature_ablation/logs/ablation_%j.out
#SBATCH --error=comparison_nb0507_14_resequencing/phase_ii_feature_ablation/logs/ablation_%j.err

set -euo pipefail
: "${SLURM_SUBMIT_DIR:?Submit from project root}"
cd "${SLURM_SUBMIT_DIR}"
[[ -s PROJECT_BRIEF.md ]] || { echo 'ERROR: wrong submission directory' >&2; exit 1; }
STAGE=comparison_nb0507_14_resequencing/phase_ii_feature_ablation
[[ -d "${STAGE}/logs" ]] || { echo 'ERROR: stage logs directory is missing' >&2; exit 1; }
PYTHON_BIN="${PYTHON_BIN:-python3}"
RUN_ID="${RUN_ID:-ablation_seed20261102}"
[[ "${RUN_ID}" =~ ^[A-Za-z0-9_-]+$ ]] || { echo 'ERROR: invalid RUN_ID' >&2; exit 1; }
OUTPUT="${STAGE}/${RUN_ID}"
[[ ! -e "${OUTPUT}" ]] || { echo "ERROR: output exists: ${OUTPUT}" >&2; exit 1; }
type module >/dev/null 2>&1 || { echo 'ERROR: environment modules unavailable' >&2; exit 1; }
module load ml-pythondeps-py39-cuda11.8-gcc11/4.12.0
module load R/gcc11/4.4.0
command -v "${PYTHON_BIN}" >/dev/null || { echo "ERROR: Python unavailable: ${PYTHON_BIN}" >&2; exit 1; }
command -v Rscript >/dev/null || { echo 'ERROR: Rscript unavailable; load R module' >&2; exit 1; }
"${PYTHON_BIN}" -c 'import numpy, sklearn; print("numpy", numpy.__version__, "sklearn", sklearn.__version__)'
Rscript -e 'cat("R", as.character(getRversion()), "\n")'
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
export OPENBLAS_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
"${PYTHON_BIN}" scripts/nb0507_14_phase_ii_feature_ablation.py \
  --master comparison_nb0507_14_resequencing/metrics/downsampled_old.master_contig_table.tsv \
  --original comparison_nb0507_14_resequencing/downsampled_old_self_mapping/NB0507_14_downsampled/metrics/NB0507_14_downsampled.master_contig_table.tsv \
  --candidate-ids comparison_nb0507_14_resequencing/reyranella_validation/reyranella_1kb_ids.txt \
  --output "${OUTPUT}" --seed 20261102 --n-init 20 --silhouette-sample 2000
Rscript scripts/plot_nb0507_14_phase_ii_feature_ablation.R "${OUTPUT}"
[[ -s "${OUTPUT}/CLUSTERING_COMPLETE" && -s "${OUTPUT}/figures/ablation_summary.pdf" ]] || {
  echo 'ERROR: expected clustering or figure outputs missing' >&2; exit 1;
}
"${PYTHON_BIN}" - "${OUTPUT}" <<'PY'
import csv, pathlib, sys
p = pathlib.Path(sys.argv[1])
def rows(name):
    with (p / name).open() as f:
        return list(csv.DictReader(f, delimiter='\t'))
metrics, sizes, assignments = rows('cluster_metrics.tsv'), rows('cluster_sizes.tsv'), rows('assignments.tsv')
candidates, ari = rows('candidate_distribution.tsv'), rows('adjusted_rand.tsv')
assert len(metrics) == 28 and len(assignments) == 4*7*13807 and len(ari) == 42
for model in ('full', 'gc_coverage', 'gc_length', 'length_coverage'):
    for k in range(2, 9):
        assert sum(int(r['n_contigs']) for r in sizes if r['model'] == model and int(r['k']) == k) == 13807
        assert sum(int(r['candidate_count']) for r in candidates if r['model'] == model and int(r['k']) == k) == 41
assert len(list((p / 'figures').glob('*.pdf'))) == 8
(p / 'COMPLETE').write_text('Clustering, tables, candidate audit, and R figures validated.\n')
PY
echo "Validated ${OUTPUT}"
