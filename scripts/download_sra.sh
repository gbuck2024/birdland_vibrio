#!/usr/bin/env bash
#SBATCH -J download_sra
#SBATCH -p normal
#SBATCH -t 24:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=64G
#SBATCH -o slurm-download_sra_%j.out
#SBATCH -e slurm-download_sra_%j.err

# Download paired-end SRA runs, gzip FASTQ mates, and expose them to the
# existing raw-read pipeline through fq_raw-compatible symlinks.

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

if [ -z "${SLURM_JOB_ID:-}" ] && [ "${ALLOW_LOGIN_DOWNLOAD:-0}" != "1" ]; then
  echo "ERROR: Submit this download/conversion job with sbatch, or set ALLOW_LOGIN_DOWNLOAD=1 for a deliberate lightweight test." >&2
  exit 1
fi

THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-8}}"
STAGE_DIR="${STAGE_DIR:-${PROJECT_DIR}/sra_download}"
FASTQ_DIR="${FASTQ_DIR:-${STAGE_DIR}/fastq}"
SRA_CACHE_DIR="${SRA_CACHE_DIR:-${STAGE_DIR}/sra_cache}"
LOG_DIR="${LOG_DIR:-${STAGE_DIR}/logs}"
METRICS_DIR="${METRICS_DIR:-${STAGE_DIR}/metrics}"
FQ_RAW_DIR="${FQ_RAW_DIR:-${PROJECT_DIR}/fq_raw}"
SRA_RAW_DIR="${SRA_RAW_DIR:-${FQ_RAW_DIR}/sra_202609}"
ACCESSION_FILE="${ACCESSION_FILE:-${PROJECT_DIR}/configs/sra_accessions.txt}"
LINK_TO_FQ_RAW="${LINK_TO_FQ_RAW:-1}"
LINK_TO_TOPLEVEL_FQ_RAW="${LINK_TO_TOPLEVEL_FQ_RAW:-1}"
SRA_SIF="${SRA_SIF:-}"
CHECK_ONLY="${CHECK_ONLY:-0}"

mkdir -p "${FASTQ_DIR}" "${SRA_CACHE_DIR}" "${LOG_DIR}" "${METRICS_DIR}"

LOG_FILE="${LOG_DIR}/download_sra.log"
MANIFEST_OUT="${METRICS_DIR}/sra_download_manifest.tsv"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*" | tee -a "${LOG_FILE}"
}

fail() {
  log "ERROR: $*"
  exit 1
}

resolve_native_tool() {
  local tool_name="$1"
  if command -v "${tool_name}" >/dev/null 2>&1; then
    command -v "${tool_name}"
    return 0
  fi

  if command -v module >/dev/null 2>&1; then
    module load sratoolkit >/dev/null 2>&1 || module load sra-tools >/dev/null 2>&1 || true
  fi

  command -v "${tool_name}" || return 1
}

run_sra_tool() {
  local tool_name="$1"
  shift

  if [ "${USE_SRA_CONTAINER}" = "1" ]; then
    "${SINGULARITY_BIN}" exec \
      --bind "${PROJECT_DIR}:${PROJECT_DIR}" \
      "${SRA_SIF}" \
      "${tool_name}" "$@"
  else
    "${tool_name}" "$@"
  fi
}

read_accessions() {
  if [ -s "${ACCESSION_FILE}" ]; then
    awk 'BEGIN { FS = "[ \t]+" } /^[ \t]*($|#)/ { next } { print $1 }' "${ACCESSION_FILE}"
  else
    printf '%s\n' \
      SRR37852097 \
      SRR37851510 \
      SRR37851509 \
      SRR37852096 \
      SRR37852095 \
      SRR37852094
  fi
}

gzip_fastq_if_needed() {
  local fastq_path="$1"
  local gz_path="${fastq_path}.gz"

  if [ -s "${gz_path}" ]; then
    return 0
  fi

  if [ ! -s "${fastq_path}" ]; then
    fail "Missing FASTQ before gzip: ${fastq_path}"
  fi

  gzip -n "${fastq_path}"
}

link_into_fq_raw() {
  local src="$1"
  local dest="$2"
  local rel_src

  if [ -e "${dest}" ] || [ -L "${dest}" ]; then
    if [ -L "${dest}" ] && [ "$(readlink "${dest}")" = "$(realpath --relative-to="$(dirname "${dest}")" "${src}")" ]; then
      log "Symlink already present: ${dest}"
      return 0
    fi
    fail "Refusing to overwrite existing fq_raw entry: ${dest}"
  fi

  rel_src="$(realpath --relative-to="$(dirname "${dest}")" "${src}")"
  ln -s "${rel_src}" "${dest}"
}

cd "${PROJECT_DIR}"

log "START download_sra.sh"
log "Project directory: ${PROJECT_DIR}"
log "FASTQ staging directory: ${FASTQ_DIR}"
log "SRA cache directory: ${SRA_CACHE_DIR}"
log "Organized SRA raw-read directory: ${SRA_RAW_DIR}"
log "Accession file: ${ACCESSION_FILE}"
log "Threads: ${THREADS}"
log "Link to fq_raw: ${LINK_TO_FQ_RAW}"
log "Top-level fq_raw compatibility links: ${LINK_TO_TOPLEVEL_FQ_RAW}"
log "Check-only mode: ${CHECK_ONLY}"

if [ -z "${SRA_SIF}" ]; then
  if [ -s "${PROJECT_DIR}/containers/sratoolkit.sif" ]; then
    SRA_SIF="${PROJECT_DIR}/containers/sratoolkit.sif"
  else
    SRA_SIF="${PROJECT_DIR}/containers/sra-tools.sif"
  fi
fi

log "SRA Toolkit container candidate: ${SRA_SIF}"

if PREFETCH_BIN="$(resolve_native_tool prefetch)" && FASTERQ_DUMP_BIN="$(resolve_native_tool fasterq-dump)"; then
  USE_SRA_CONTAINER=0
  log "Using native SRA Toolkit: prefetch=${PREFETCH_BIN}; fasterq-dump=${FASTERQ_DUMP_BIN}"
elif [ -s "${SRA_SIF}" ]; then
  SINGULARITY_BIN="$(command -v singularity || command -v apptainer || true)"
  if [ -z "${SINGULARITY_BIN}" ]; then
    fail "Found ${SRA_SIF}, but neither singularity nor apptainer is available on PATH."
  fi
  USE_SRA_CONTAINER=1
  log "Using SRA Toolkit container with ${SINGULARITY_BIN}: ${SRA_SIF}"
else
  fail "SRA Toolkit is unavailable. Provide prefetch/fasterq-dump on PATH or place an SRA Toolkit image at ${SRA_SIF}."
fi

mapfile -t ACCESSIONS < <(read_accessions)

if [ "${#ACCESSIONS[@]}" -eq 0 ]; then
  fail "No SRA accessions found."
fi

if [ "${CHECK_ONLY}" = "1" ]; then
  log "Validated SRA Toolkit availability and ${#ACCESSIONS[@]} accession(s); exiting before download."
  log "END download_sra.sh"
  exit 0
fi

printf "accession\tfastq_r1\tfastq_r2\torganized_fq_raw_r1\torganized_fq_raw_r2\ttoplevel_fq_raw_r1\ttoplevel_fq_raw_r2\tstatus\n" > "${MANIFEST_OUT}.tmp"

for SRR in "${ACCESSIONS[@]}"; do
  case "${SRR}" in
    SRR*|ERR*|DRR*) ;;
    *) fail "Unexpected run accession '${SRR}'. Expected SRR/ERR/DRR-style run IDs." ;;
  esac

  log "Processing ${SRR}"

  r1_gz="${FASTQ_DIR}/${SRR}_1.fastq.gz"
  r2_gz="${FASTQ_DIR}/${SRR}_2.fastq.gz"
  r1_sra_raw_link="${SRA_RAW_DIR}/${SRR}_L7_1.fq.gz"
  r2_sra_raw_link="${SRA_RAW_DIR}/${SRR}_L7_2.fq.gz"
  r1_toplevel_raw_link="${FQ_RAW_DIR}/${SRR}_L7_1.fq.gz"
  r2_toplevel_raw_link="${FQ_RAW_DIR}/${SRR}_L7_2.fq.gz"

  if [ ! -s "${r1_gz}" ] || [ ! -s "${r2_gz}" ]; then
    run_sra_tool prefetch \
      --output-directory "${SRA_CACHE_DIR}" \
      "${SRR}" \
      2>&1 | tee -a "${LOG_FILE}"

    tmp_dir="${FASTQ_DIR}/${SRR}.tmp"
    rm -rf "${tmp_dir}"
    mkdir -p "${tmp_dir}"

    run_sra_tool fasterq-dump \
      "${SRA_CACHE_DIR}/${SRR}" \
      --split-files \
      --threads "${THREADS}" \
      --outdir "${tmp_dir}" \
      2>&1 | tee -a "${LOG_FILE}"

    gzip_fastq_if_needed "${tmp_dir}/${SRR}_1.fastq"
    gzip_fastq_if_needed "${tmp_dir}/${SRR}_2.fastq"

    if [ -e "${r1_gz}" ] || [ -e "${r2_gz}" ]; then
      rm -rf "${tmp_dir}"
      fail "Refusing to overwrite existing staged FASTQ for ${SRR}"
    fi

    mv "${tmp_dir}/${SRR}_1.fastq.gz" "${r1_gz}"
    mv "${tmp_dir}/${SRR}_2.fastq.gz" "${r2_gz}"
    rm -rf "${tmp_dir}"
  else
    log "Staged gzipped FASTQ pair already exists for ${SRR}; skipping download."
  fi

  if [ ! -s "${r1_gz}" ] || [ ! -s "${r2_gz}" ]; then
    fail "Expected gzipped paired FASTQ files are missing or empty for ${SRR}"
  fi

  if [ "${LINK_TO_FQ_RAW}" = "1" ]; then
    mkdir -p "${SRA_RAW_DIR}"
    link_into_fq_raw "${r1_gz}" "${r1_sra_raw_link}"
    link_into_fq_raw "${r2_gz}" "${r2_sra_raw_link}"

    if [ "${LINK_TO_TOPLEVEL_FQ_RAW}" = "1" ]; then
      mkdir -p "${FQ_RAW_DIR}"
      link_into_fq_raw "${r1_sra_raw_link}" "${r1_toplevel_raw_link}"
      link_into_fq_raw "${r2_sra_raw_link}" "${r2_toplevel_raw_link}"
    fi
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "${SRR}" \
    "${r1_gz}" \
    "${r2_gz}" \
    "${r1_sra_raw_link}" \
    "${r2_sra_raw_link}" \
    "${r1_toplevel_raw_link}" \
    "${r2_toplevel_raw_link}" \
    "paired_fastq_ready" >> "${MANIFEST_OUT}.tmp"

  log "Finished ${SRR}"
done

mv "${MANIFEST_OUT}.tmp" "${MANIFEST_OUT}"

log "Wrote manifest: ${MANIFEST_OUT}"
log "END download_sra.sh"
