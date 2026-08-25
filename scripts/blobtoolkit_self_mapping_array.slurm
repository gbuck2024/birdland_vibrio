#!/bin/bash
# Manifest-driven self-contig read mapping for BlobToolKit coverage.
#
# Submit from the project root:
#   sbatch --array=0-5 scripts/blobtoolkit_self_mapping_array.slurm

#SBATCH -J btk_self_map
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -o ambiguous_isolate_resolution/blobtoolkit/logs/slurm/self_mapping_%A_%a.out
#SBATCH -e ambiguous_isolate_resolution/blobtoolkit/logs/slurm/self_mapping_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MANIFEST_FILE="${MANIFEST_FILE:-configs/blobtoolkit_self_mapping_manifest.tsv}"
STAGE_ROOT="${STAGE_ROOT:-ambiguous_isolate_resolution/blobtoolkit}"
CONDA_ENV_PATH="${CONDA_ENV_PATH:-/home/glametrie1/.conda/envs/blobtoolkit}"
THREADS="${SLURM_CPUS_PER_TASK:-8}"

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

initialize_conda() {
  if [ -r /cm/shared/tamucc/apps/miniconda3/24.1.2/etc/profile.d/conda.sh ]; then
    # shellcheck disable=SC1091
    source /cm/shared/tamucc/apps/miniconda3/24.1.2/etc/profile.d/conda.sh
  elif command -v conda >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    source "$(conda info --base)/etc/profile.d/conda.sh"
  else
    log "ERROR: conda command not found; cannot activate BlobToolKit environment." >&2
    exit 1
  fi

  conda activate "${CONDA_ENV_PATH}"
}

initialize_modules() {
  if command -v module >/dev/null 2>&1; then
    return 0
  fi

  if [ -r /etc/profile.d/modules.sh ]; then
    # shellcheck disable=SC1091
    source /etc/profile.d/modules.sh
  elif [ -r /usr/share/Modules/init/bash ]; then
    # shellcheck disable=SC1091
    source /usr/share/Modules/init/bash
  fi

  command -v module >/dev/null 2>&1
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log "ERROR: Required command not found in PATH: ${command_name}" >&2
    exit 1
  fi
}

load_command_from_modules() {
  local command_name="$1"
  shift

  if command -v "${command_name}" >/dev/null 2>&1; then
    return 0
  fi

  if initialize_modules; then
    local module_name
    for module_name in "$@"; do
      if module load "${module_name}" >/dev/null 2>&1 && command -v "${command_name}" >/dev/null 2>&1; then
        log "Loaded ${command_name} via environment module '${module_name}'."
        return 0
      fi
    done
  fi

  return 1
}

mkdir -p "${STAGE_ROOT}/logs/slurm"

log "START blobtoolkit_self_mapping_array.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Manifest: ${MANIFEST_FILE}"
require_file "${MANIFEST_FILE}" "BlobToolKit self-mapping manifest"

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit this script with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")
if [ "${#SAMPLE_ROWS[@]}" -eq 0 ]; then
  log "ERROR: Manifest contains no sample rows." >&2
  exit 1
fi

if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r short_id sample_id read1 read2 contigs_fasta <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"
if [ -z "${short_id}" ] || [ -z "${sample_id}" ] || [ -z "${read1}" ] || [ -z "${read2}" ] || [ -z "${contigs_fasta}" ]; then
  log "ERROR: Manifest row ${SLURM_ARRAY_TASK_ID} is malformed." >&2
  exit 1
fi

stage_dir="${STAGE_ROOT}/${short_id}"
bam_dir="${stage_dir}/bam"
index_dir="${stage_dir}/index"
metrics_dir="${stage_dir}/metrics"
metadata_dir="${stage_dir}/metadata"
sample_log_dir="${stage_dir}/logs/slurm"

bwa_index_prefix="${index_dir}/${short_id}.spades_contigs"
mapped_bam="${bam_dir}/${sample_id}.self_contigs.mapped.bam"
sorted_bam="${bam_dir}/${sample_id}.self_contigs.sorted.bam"
flagstat_file="${metrics_dir}/${sample_id}.self_contigs.sorted.flagstat.txt"
idxstats_file="${metrics_dir}/${sample_id}.self_contigs.sorted.idxstats.txt"
quickcheck_file="${metrics_dir}/${sample_id}.self_contigs.quickcheck.txt"
refname_diff="${metrics_dir}/${sample_id}.self_contigs.reference_name_diff.txt"
refname_check="${metrics_dir}/${sample_id}.self_contigs.reference_name_check.txt"
params_file="${metadata_dir}/${sample_id}.self_contigs.parameters.txt"
spades_contig_names="${metadata_dir}/${sample_id}.spades_contig_names.txt"
bam_reference_names="${metadata_dir}/${sample_id}.bam_reference_names.txt"

mkdir -p "${bam_dir}" "${index_dir}" "${metrics_dir}" "${metadata_dir}" "${sample_log_dir}"

log "Sample: ${sample_id}"
log "Short ID: ${short_id}"
log "Read 1: ${read1}"
log "Read 2: ${read2}"
log "SPAdes contigs: ${contigs_fasta}"
log "Stage directory: ${stage_dir}"

require_file "${read1}" "trimmed R1 paired reads"
require_file "${read2}" "trimmed R2 paired reads"
require_file "${contigs_fasta}" "SPAdes contigs FASTA"

read1_base="$(basename "${read1}")"
read2_base="$(basename "${read2}")"
if [[ "${read1_base}" != "${sample_id}_1_paired.fq.gz" ]]; then
  log "ERROR: R1 filename does not match expected paired-read pattern for ${sample_id}: ${read1}" >&2
  exit 1
fi
if [[ "${read2_base}" != "${sample_id}_2_paired.fq.gz" ]]; then
  log "ERROR: R2 filename does not match expected paired-read pattern for ${sample_id}: ${read2}" >&2
  exit 1
fi

initialize_conda
load_command_from_modules bwa bwa/0.7.17 bwa || true
load_command_from_modules samtools samtools/1.20 samtools/1.19 samtools || true

require_command bwa
require_command samtools
require_command blobtools

{
  echo "sample_id=${sample_id}"
  echo "short_id=${short_id}"
  echo "manifest_file=${MANIFEST_FILE}"
  echo "conda_env_path=${CONDA_ENV_PATH}"
  echo "blobtools_version=$(blobtools --version 2>&1 | tail -n 1)"
  echo "bwa_path=$(command -v bwa)"
  echo "samtools_path=$(command -v samtools)"
  echo "read1=${read1}"
  echo "read2=${read2}"
  echo "contigs_fasta=${contigs_fasta}"
  echo "bwa_index_prefix=${bwa_index_prefix}"
  echo "threads=${THREADS}"
} > "${params_file}"

log "Recording SPAdes contig names."
awk '/^>/ {sub(/^>/, ""); sub(/[ \t].*/, ""); print}' "${contigs_fasta}" > "${spades_contig_names}"
require_file "${spades_contig_names}" "SPAdes contig name list"

log "Building BWA index under the sample stage directory."
bwa index -p "${bwa_index_prefix}" "${contigs_fasta}"
for bwa_sidecar in \
  "${bwa_index_prefix}.amb" \
  "${bwa_index_prefix}.ann" \
  "${bwa_index_prefix}.bwt" \
  "${bwa_index_prefix}.pac" \
  "${bwa_index_prefix}.sa"; do
  require_file "${bwa_sidecar}" "BWA index sidecar"
done

log "Mapping trimmed paired reads back to the sample's own SPAdes contigs."
bwa mem -t "${THREADS}" "${bwa_index_prefix}" "${read1}" "${read2}" \
  | samtools view -@ "${THREADS}" -b -o "${mapped_bam}" -
require_file "${mapped_bam}" "mapped BAM"

log "Coordinate-sorting BAM."
samtools sort -@ "${THREADS}" -o "${sorted_bam}" "${mapped_bam}"
require_file "${sorted_bam}" "coordinate-sorted BAM"

log "Indexing coordinate-sorted BAM with BAI and CSI indexes."
samtools index -@ "${THREADS}" "${sorted_bam}"
samtools index -@ "${THREADS}" -c "${sorted_bam}"
require_file "${sorted_bam}.bai" "coordinate-sorted BAM BAI index"
require_file "${sorted_bam}.csi" "coordinate-sorted BAM CSI index"

log "Verifying BAM integrity with samtools quickcheck."
samtools quickcheck -v "${mapped_bam}" "${sorted_bam}" > "${quickcheck_file}" 2>&1
echo "PASS: samtools quickcheck completed for mapped and coordinate-sorted BAMs." >> "${quickcheck_file}"

log "Writing samtools flagstat and idxstats for the coordinate-sorted BAM."
samtools flagstat "${sorted_bam}" > "${flagstat_file}"
samtools idxstats "${sorted_bam}" > "${idxstats_file}"
require_file "${flagstat_file}" "flagstat report"
require_file "${idxstats_file}" "idxstats report"

log "Verifying BAM reference names match SPAdes contig names."
awk '$1 != "*" {print $1}' "${idxstats_file}" > "${bam_reference_names}"
if ! diff -u "${spades_contig_names}" "${bam_reference_names}" > "${refname_diff}"; then
  log "ERROR: BAM reference names differ from SPAdes contig names. See ${refname_diff}" >&2
  exit 1
fi
echo "PASS: BAM reference names match the SPAdes contig names from ${contigs_fasta}." > "${refname_check}"

log "Completed self-contig mapping for ${sample_id}"
log "Sorted BAM: ${sorted_bam}"
log "BAM indexes: ${sorted_bam}.bai ${sorted_bam}.csi"
log "END blobtoolkit_self_mapping_array.slurm"
