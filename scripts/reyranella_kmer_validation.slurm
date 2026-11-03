#!/bin/bash
# Exact canonical 31-mer validation of the previously audited matched FASTQs.
# Submit from the project root; the earlier read-mapping stages are untouched.
#SBATCH -J reyranella_31mer
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem=16G
#SBATCH -o comparison_nb0507_14_resequencing/reyranella_validation/kmer_validation/logs/kmer_%j.out
#SBATCH -e comparison_nb0507_14_resequencing/reyranella_validation/kmer_validation/logs/kmer_%j.err

set -euo pipefail
[[ -n "${SLURM_SUBMIT_DIR:-}" ]] || { echo 'SLURM_SUBMIT_DIR is unset' >&2; exit 1; }
cd "${SLURM_SUBMIT_DIR}"
[[ -f PROJECT_BRIEF.md && -f scripts/reyranella_kmer_validation.py ]] || { echo 'Submit from project root' >&2; exit 1; }
stage=comparison_nb0507_14_resequencing/reyranella_validation/kmer_validation
[[ -d "${stage}/logs" ]] || { echo "Missing ${stage}/logs; create before submission" >&2; exit 1; }
for directory in metrics reports; do
  if [[ -d "${stage}/${directory}" ]] && [[ -n "$(find "${stage}/${directory}" -mindepth 1 -print -quit)" ]]; then
    echo "Refusing existing ${stage}/${directory} outputs" >&2
    exit 1
  fi
done
if ! mkdir "${stage}/.run_lock"; then
  echo "Existing run lock: ${stage}/.run_lock" >&2
  exit 1
fi
trap 'rmdir "${stage}/.run_lock"' EXIT
command -v python3 >/dev/null || { echo 'python3 unavailable' >&2; exit 1; }
python3 -c 'import sys; assert sys.version_info >= (3, 8), "Python 3.8+ required"'
python3 scripts/reyranella_kmer_validation.py \
  --root . \
  --manifest comparison_nb0507_14_resequencing/manifests/reyranella_read_mapping_depth_matched.tsv \
  --reference comparison_nb0507_14_resequencing/downsampled_old_assembly/assemblies/Buck_NB0507_14_downsampled_to_SRR37852095_L7/contigs.fasta \
  --candidates comparison_nb0507_14_resequencing/reyranella_validation/reyranella_1kb_ids.txt \
  --prior-audit comparison_nb0507_14_resequencing/reyranella_validation/read_mapping_depth_matched/metrics/input_audit.tsv \
  --stage "${stage}"
python3 - "${stage}" <<'PY'
import csv
import sys
from pathlib import Path
stage = Path(sys.argv[1])
for name, expected in (("reports/candidate_31mer_support.tsv", 82), ("metrics/input_audit.tsv", 2)):
    path = stage / name
    with path.open(newline="") as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    if len(rows) != expected:
        raise SystemExit(f"Invalid output row count: {path}: {len(rows)} != {expected}")
print("31-mer stage complete and output counts verified")
PY
