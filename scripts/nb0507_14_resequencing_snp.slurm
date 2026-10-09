#!/bin/bash
# Lightweight whole-genome alignment/SNP screen for old-vs-new assemblies.
# Runs MUMmer4 from a local Singularity image so this job does not depend on a
# cluster MUMmer module. Results are assembly-level and should not be
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
SUMMARY_PATH="${METRICS_DIR}/old_vs_new_snp_summary.tsv"
TMP_PREFIX="${OUT_DIR}/old_vs_new.tmp.${SLURM_JOB_ID:-$$}"
THREADS="${SLURM_CPUS_PER_TASK:-4}"
SINGULARITY_BIN="${SINGULARITY_BIN:-/usr/bin/singularity}"
MUMMER4_SIF="${MUMMER4_SIF:-containers/mummer4.sif}"
MUMMER4_IMAGE_SOURCE="${MUMMER4_IMAGE_SOURCE:-docker://staphb/mummer:4.0.0}"

cleanup_tmp() {
  rm -f "${TMP_PREFIX}.delta" "${TMP_PREFIX}.1delta" "${TMP_PREFIX}.snps.tsv" "${TMP_PREFIX}.coords.tsv"
}
trap cleanup_tmp EXIT

mkdir -p "${OUT_DIR}" "${METRICS_DIR}" "${LOG_DIR}"
for path in "${OLD_FASTA}" "${NEW_FASTA}"; do
  if [ ! -s "${path}" ]; then
    echo "ERROR: Missing assembly FASTA: ${path}" >&2
    exit 1
  fi
done

if [ -s "${PREFIX}.delta" ] && [ -s "${PREFIX}.1delta" ] && [ -s "${PREFIX}.snps.tsv" ] && [ -s "${PREFIX}.coords.tsv" ] && [ -s "${SUMMARY_PATH}" ]; then
  echo "Existing complete SNP comparison found for ${PREFIX}; skipping to avoid overwriting results."
  python3 scripts/summarize_nb0507_14_resequencing.py
  exit 0
fi

if [ -s "${PREFIX}.delta" ] && [ -s "${PREFIX}.1delta" ] && [ -s "${PREFIX}.snps.tsv" ] && [ -s "${PREFIX}.coords.tsv" ]; then
  echo "Existing complete MUMmer output found for ${PREFIX}; reusing it for the summary."
else
  if [ ! -x "${SINGULARITY_BIN}" ]; then
    echo "ERROR: Singularity is not executable at ${SINGULARITY_BIN}" >&2
    exit 1
  fi

  if [ ! -s "${MUMMER4_SIF}" ]; then
    mkdir -p "$(dirname "${MUMMER4_SIF}")"
    TMP_SIF="${MUMMER4_SIF}.tmp.${SLURM_JOB_ID:-$$}"
    echo "Building MUMmer4 container: ${MUMMER4_SIF}"
    "${SINGULARITY_BIN}" build "${TMP_SIF}" "${MUMMER4_IMAGE_SOURCE}"
    mv "${TMP_SIF}" "${MUMMER4_SIF}"
    chmod 755 "${MUMMER4_SIF}"
  fi

  run_mummer() {
    local cmd="$1"
    shift
    "${SINGULARITY_BIN}" exec --cleanenv --bind "${PROJECT_DIR}:${PROJECT_DIR}" "${MUMMER4_SIF}" \
      "${cmd}" "$@"
  }

  container_has_cmd() {
    local cmd="$1"
    "${SINGULARITY_BIN}" exec --cleanenv "${MUMMER4_SIF}" sh -lc 'command -v "$1" >/dev/null 2>&1' sh "${cmd}"
  }

  for cmd in nucmer delta-filter show-snps show-coords; do
    if ! container_has_cmd "${cmd}"; then
      echo "ERROR: Required MUMmer command unavailable in ${MUMMER4_SIF}: ${cmd}" >&2
      exit 1
    fi
  done

  cleanup_tmp
  run_mummer nucmer --maxmatch --threads "${THREADS}" --prefix "${PROJECT_DIR}/${TMP_PREFIX}" \
    "${PROJECT_DIR}/${OLD_FASTA}" "${PROJECT_DIR}/${NEW_FASTA}"
  run_mummer delta-filter -1 "${PROJECT_DIR}/${TMP_PREFIX}.delta" > "${TMP_PREFIX}.1delta"
  run_mummer show-snps -ClrT "${PROJECT_DIR}/${TMP_PREFIX}.1delta" > "${TMP_PREFIX}.snps.tsv"
  run_mummer show-coords -rclT "${PROJECT_DIR}/${TMP_PREFIX}.1delta" > "${TMP_PREFIX}.coords.tsv"

  for path in "${TMP_PREFIX}.delta" "${TMP_PREFIX}.1delta" "${TMP_PREFIX}.snps.tsv" "${TMP_PREFIX}.coords.tsv"; do
    if [ ! -s "${path}" ]; then
      echo "ERROR: MUMmer output was not created or is empty: ${path}" >&2
      exit 1
    fi
  done

  mv "${TMP_PREFIX}.delta" "${PREFIX}.delta"
  mv "${TMP_PREFIX}.1delta" "${PREFIX}.1delta"
  mv "${TMP_PREFIX}.snps.tsv" "${PREFIX}.snps.tsv"
  mv "${TMP_PREFIX}.coords.tsv" "${PREFIX}.coords.tsv"
fi

python3 - "${OLD_FASTA}" "${NEW_FASTA}" "${PREFIX}.snps.tsv" "${PREFIX}.coords.tsv" "${SUMMARY_PATH}" <<'PY'
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
