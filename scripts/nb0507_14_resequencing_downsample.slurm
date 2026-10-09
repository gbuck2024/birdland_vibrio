#!/bin/bash
# Reproducibly downsample old NB0507-14 trimmed paired reads to the retained
# paired-read count of SRR37852095_L7 after Trimmomatic.

#SBATCH -J nb0507_downsample
#SBATCH -p normal
#SBATCH -t 12:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=16G
#SBATCH -o comparison_nb0507_14_resequencing/logs/slurm/downsample_%j.out
#SBATCH -e comparison_nb0507_14_resequencing/logs/slurm/downsample_%j.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

OLD_SAMPLE="Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7"
NEW_SAMPLE="SRR37852095_L7"
DOWNSAMPLED_SAMPLE="Buck_NB0507_14_downsampled_to_SRR37852095_L7"
SEED="${SEED:-20261009}"
STAGE_DIR="comparison_nb0507_14_resequencing"
OUT_DIR="${STAGE_DIR}/downsampled_old_reads"
METRICS_DIR="${STAGE_DIR}/metrics"

old_r1="trimmomatic/trimmed_reads/${OLD_SAMPLE}_1_paired.fq.gz"
old_r2="trimmomatic/trimmed_reads/${OLD_SAMPLE}_2_paired.fq.gz"
new_fastqc="trimmomatic/fastqc_trimmed_extracted/${NEW_SAMPLE}_1_paired_fastqc/fastqc_data.txt"
out_r1="${OUT_DIR}/${DOWNSAMPLED_SAMPLE}_1_paired.fq.gz"
out_r2="${OUT_DIR}/${DOWNSAMPLED_SAMPLE}_2_paired.fq.gz"
metrics_out="${METRICS_DIR}/downsampled_old_read_count.tsv"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

log() {
  echo "[$(timestamp)] $*"
}

require_file() {
  local path="$1"
  local label="$2"
  if [ ! -s "${path}" ]; then
    log "ERROR: ${label} missing or empty: ${path}" >&2
    exit 1
  fi
}

mkdir -p "${OUT_DIR}" "${METRICS_DIR}" "${STAGE_DIR}/logs/slurm"
require_file "${old_r1}" "old trimmed R1"
require_file "${old_r2}" "old trimmed R2"
require_file "${new_fastqc}" "new post-trim FastQC data"
require_file "scripts/downsample_paired_fastq.py" "paired FASTQ downsampler"

target_pairs="$(awk -F '\t' '$1=="Total Sequences" {print $2}' "${new_fastqc}")"
if [ -z "${target_pairs}" ] || ! [[ "${target_pairs}" =~ ^[0-9]+$ ]]; then
  log "ERROR: Could not parse retained paired-read target from ${new_fastqc}" >&2
  exit 1
fi

log "Downsampling ${OLD_SAMPLE} to ${target_pairs} read pairs with seed ${SEED}."
python3 scripts/downsample_paired_fastq.py \
  --r1 "${old_r1}" \
  --r2 "${old_r2}" \
  --out-r1 "${out_r1}" \
  --out-r2 "${out_r2}" \
  --pairs "${target_pairs}" \
  --seed "${SEED}"

require_file "${out_r1}" "downsampled R1"
require_file "${out_r2}" "downsampled R2"

{
  echo -e "sample_id\tsource_sample_id\ttarget_sample_id\ttarget_pairs\tseed\tread1\tread2"
  echo -e "${DOWNSAMPLED_SAMPLE}\t${OLD_SAMPLE}\t${NEW_SAMPLE}\t${target_pairs}\t${SEED}\t${out_r1}\t${out_r2}"
} > "${metrics_out}"

log "Wrote ${metrics_out}"
log "Next submit SPAdes, self-mapping, Kraken2, FastANI/SNP, then rerun scripts/summarize_nb0507_14_resequencing.py."
