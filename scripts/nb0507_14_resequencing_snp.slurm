#!/bin/bash
# Lightweight whole-genome alignment/SNP screen for old-vs-new assemblies.
# Uses MUMmer when available. Results are assembly-level and should not be
# overinterpreted in repeats or poorly aligned regions.

#SBATCH -J nb0507_snp
#SBATCH -p normal
#SBATCH -t 08:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem=24G
#SBATCH -o comparison_nb0507_14_resequencing/snp/logs/snp_%j.out
#SBATCH -e comparison_nb0507_14_resequencing/snp/logs/snp_%j.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

OLD_ID="Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7"
NEW_ID="SRR37852095_L7"
OLD_FASTA="assembly/assemblies/${OLD_ID}/contigs.fasta"
NEW_FASTA="assembly_sra/assemblies/${NEW_ID}/contigs.fasta"
STAGE_DIR="comparison_nb0507_14_resequencing/snp"
OUT_DIR="${STAGE_DIR}/outputs"
METRICS_DIR="${STAGE_DIR}/metrics"
LOG_DIR="${STAGE_DIR}/logs"
PREFIX="${OUT_DIR}/old_vs_new"

mkdir -p "${OUT_DIR}" "${METRICS_DIR}" "${LOG_DIR}"
for path in "${OLD_FASTA}" "${NEW_FASTA}"; do
  if [ ! -s "${path}" ]; then
    echo "ERROR: Missing assembly FASTA: ${path}" >&2
    exit 1
  fi
done

if command -v module >/dev/null 2>&1; then
  module load mummer 2>/dev/null || module load MUMmer 2>/dev/null || true
fi

for cmd in nucmer delta-filter show-snps show-coords; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: Required MUMmer command not found: ${cmd}" >&2
    exit 1
  fi
done

nucmer --maxmatch --threads "${SLURM_CPUS_PER_TASK:-4}" --prefix "${PREFIX}" "${OLD_FASTA}" "${NEW_FASTA}"
delta-filter -1 "${PREFIX}.delta" > "${PREFIX}.1delta"
show-snps -ClrT "${PREFIX}.1delta" > "${PREFIX}.snps.tsv"
show-coords -rclT "${PREFIX}.1delta" > "${PREFIX}.coords.tsv"

python3 - "${OLD_FASTA}" "${NEW_FASTA}" "${PREFIX}.snps.tsv" "${PREFIX}.coords.tsv" "${METRICS_DIR}/old_vs_new_snp_summary.tsv" <<'PY'
import sys
from pathlib import Path

old_fasta, new_fasta, snps_path, coords_path, out_path = map(Path, sys.argv[1:])

def fasta_bases(path):
    total = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith(">"):
            total += len(line.strip())
    return total

snps = 0
indels = 0
for line in snps_path.read_text(encoding="utf-8", errors="replace").splitlines():
    if not line or line.startswith("[") or line.startswith("=") or line.startswith("NUCMER"):
        continue
    parts = line.split("\t")
    if len(parts) < 4:
        continue
    ref_base = parts[1].strip()
    qry_base = parts[2].strip()
    if ref_base == "." or qry_base == ".":
        indels += 1
    else:
        snps += 1

aligned_ref = 0
for line in coords_path.read_text(encoding="utf-8", errors="replace").splitlines():
    if not line or line.startswith("[") or line.startswith("=") or line.startswith("NUCMER"):
        continue
    parts = line.split("\t")
    if len(parts) < 8:
        continue
    try:
        aligned_ref += int(parts[4])
    except ValueError:
        pass

old_bases = fasta_bases(old_fasta)
new_bases = fasta_bases(new_fasta)
denom = min(old_bases, new_bases) or 1
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(
    "comparison\thigh_confidence_snp_differences\tindel_events\taligned_reference_bases\taligned_genome_fraction\tmethod\n"
    f"old_vs_new\t{snps}\t{indels}\t{aligned_ref}\t{aligned_ref / denom:.6f}\tnucmer_maxmatch_delta_filter_1_show_snps_ClrT\n",
    encoding="utf-8",
)
PY

python3 scripts/summarize_nb0507_14_resequencing.py
