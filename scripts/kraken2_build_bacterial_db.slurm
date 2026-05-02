#!/bin/bash
# Build a bacteria-focused Kraken2 database inside a Singularity container.
# This script is meant for cluster submission only; do not run it on a login node.
# It keeps large database files in a dedicated stage directory and records
# disk-usage snapshots plus build assumptions for reproducibility.
#SBATCH -J kraken2_bact_db
#SBATCH -p normal
#SBATCH -t 48:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 16
#SBATCH --mem=128G
#SBATCH -o kraken2_db/logs/slurm/kraken2_bact_db_%j.out
#SBATCH -e kraken2_db/logs/slurm/kraken2_bact_db_%j.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

STAGE_DIR="${PROJECT_DIR}/kraken2_db"
DB_DIR="${STAGE_DIR}/db"
METADATA_DIR="${STAGE_DIR}/metadata"
LOG_DIR="${STAGE_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"

SINGULARITY_BIN="${SINGULARITY_BIN:-singularity}"
KRAKEN2_THREADS="${KRAKEN2_THREADS:-${SLURM_CPUS_PER_TASK:-16}}"
KRAKEN2_CLEAN_AFTER_BUILD="${KRAKEN2_CLEAN_AFTER_BUILD:-1}"
KRAKEN2_BUILD_EXTRA_ARGS="${KRAKEN2_BUILD_EXTRA_ARGS:-}"
KRAKEN2_DOWNLOAD_PROTOCOL="${KRAKEN2_DOWNLOAD_PROTOCOL:-ftp}"
KRAKEN2_DOWNLOAD_MAX_ATTEMPTS="${KRAKEN2_DOWNLOAD_MAX_ATTEMPTS:-5}"
KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC="${KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC:-300}"

# Guardrails to avoid filling shared storage unexpectedly.
MIN_PROJECT_FREE_GB="${MIN_PROJECT_FREE_GB:-250}"
MIN_TMP_FREE_GB="${MIN_TMP_FREE_GB:-150}"

JOB_TMP_ROOT="${TMPDIR:-/tmp/${USER}}"
JOB_TMPDIR="${JOB_TMP_ROOT}/kraken2_build_${SLURM_JOB_ID:-manual}"

if [ -n "${KRAKEN2_SIF:-}" ]; then
  CONTAINER_IMAGE="${KRAKEN2_SIF}"
elif [ -s "${PROJECT_DIR}/containers/kraken2.sif" ]; then
  CONTAINER_IMAGE="${PROJECT_DIR}/containers/kraken2.sif"
else
  CONTAINER_IMAGE="${PROJECT_DIR}/kraken2.sif"
fi

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

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    log "ERROR: Required command not found in PATH: ${command_name}" >&2
    exit 1
  fi
}

require_positive_integer() {
  local value="$1"
  local label="$2"

  if ! [[ "${value}" =~ ^[1-9][0-9]*$ ]]; then
    log "ERROR: ${label} must be a positive integer. Observed: ${value}" >&2
    exit 1
  fi
}

free_gib() {
  local target_path="$1"

  df -PB1 "${target_path}" | awk 'NR==2 {printf "%.0f", $4 / 1024 / 1024 / 1024}'
}

record_disk_snapshot() {
  local output_path="$1"

  {
    echo "timestamp	$(timestamp)"
    echo "project_dir	${PROJECT_DIR}"
    echo "stage_dir	${STAGE_DIR}"
    echo "db_dir_exists	$( [ -d "${DB_DIR}" ] && echo yes || echo no )"
    echo "project_free_gib	$(free_gib "${PROJECT_DIR}")"
    echo "tmp_free_gib	$(free_gib "${JOB_TMP_ROOT}")"
    if [ -d "${DB_DIR}" ]; then
      echo "db_du_human	$(du -sh "${DB_DIR}" | awk '{print $1}')"
      echo "db_du_bytes	$(du -sb "${DB_DIR}" | awk '{print $1}')"
    else
      echo "db_du_human	NA"
      echo "db_du_bytes	NA"
    fi
  } > "${output_path}"
}

cleanup() {
  rm -rf "${JOB_TMPDIR}"
}
trap cleanup EXIT

mkdir -p "${DB_DIR}" "${METADATA_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}" "${JOB_TMPDIR}"

log "START kraken2_build_bacterial_db.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Stage directory: ${STAGE_DIR}"
log "Database directory: ${DB_DIR}"
log "Metadata directory: ${METADATA_DIR}"
log "Temporary directory: ${JOB_TMPDIR}"
log "Container image: ${CONTAINER_IMAGE}"
log "Singularity binary: ${SINGULARITY_BIN}"
log "Kraken2 threads: ${KRAKEN2_THREADS}"

require_command "${SINGULARITY_BIN}"
require_file "${CONTAINER_IMAGE}" "Singularity image"

project_free_gib="$(free_gib "${PROJECT_DIR}")"
tmp_free_gib="$(free_gib "${JOB_TMP_ROOT}")"

if [ "${project_free_gib}" -lt "${MIN_PROJECT_FREE_GB}" ]; then
  log "ERROR: Project filesystem has ${project_free_gib} GiB free; ${MIN_PROJECT_FREE_GB} GiB required." >&2
  exit 1
fi

if [ "${tmp_free_gib}" -lt "${MIN_TMP_FREE_GB}" ]; then
  log "ERROR: Temporary filesystem has ${tmp_free_gib} GiB free; ${MIN_TMP_FREE_GB} GiB required." >&2
  exit 1
fi

BEFORE_SNAPSHOT="${METADATA_DIR}/disk_usage_before_job_${SLURM_JOB_ID:-manual}.tsv"
AFTER_SNAPSHOT="${METADATA_DIR}/disk_usage_after_job_${SLURM_JOB_ID:-manual}.tsv"
PARAMETERS_FILE="${METADATA_DIR}/build_parameters_job_${SLURM_JOB_ID:-manual}.tsv"
ASSUMPTIONS_FILE="${METADATA_DIR}/build_assumptions_job_${SLURM_JOB_ID:-manual}.txt"

record_disk_snapshot "${BEFORE_SNAPSHOT}"

cat > "${PARAMETERS_FILE}" <<EOF
timestamp	$(timestamp)
project_dir	${PROJECT_DIR}
stage_dir	${STAGE_DIR}
db_dir	${DB_DIR}
container_image	${CONTAINER_IMAGE}
singularity_bin	${SINGULARITY_BIN}
threads	${KRAKEN2_THREADS}
clean_after_build	${KRAKEN2_CLEAN_AFTER_BUILD}
download_protocol	${KRAKEN2_DOWNLOAD_PROTOCOL}
build_extra_args	${KRAKEN2_BUILD_EXTRA_ARGS:-none}
min_project_free_gb	${MIN_PROJECT_FREE_GB}
min_tmp_free_gb	${MIN_TMP_FREE_GB}
job_tmpdir	${JOB_TMPDIR}
EOF

cat > "${ASSUMPTIONS_FILE}" <<EOF
This job builds a bacteria-focused Kraken2 database using only the RefSeq bacteria library plus taxonomy.
It assumes the Singularity image already contains kraken2-build and its standard helper tools.
It assumes the project should avoid a full standard Kraken2 database because that would add unnecessary non-bacterial content.
It assumes temporary space is available on the compute node and that cleanup should happen automatically at job end.
It assumes storage protection matters, so the script aborts if free space falls below the configured project or temporary thresholds.
If KRAKEN2_CLEAN_AFTER_BUILD=1, kraken2-build --clean is run after a successful build to reduce retained intermediate files.
The default download protocol is ftp to avoid rsync endpoint failures seen with older Kraken2 download logic.
EOF

DOWNLOAD_FLAGS=""
case "${KRAKEN2_DOWNLOAD_PROTOCOL}" in
  ftp)
    DOWNLOAD_FLAGS="--use-ftp"
    ;;
  rsync)
    DOWNLOAD_FLAGS=""
    ;;
  *)
    log "ERROR: Unsupported KRAKEN2_DOWNLOAD_PROTOCOL='${KRAKEN2_DOWNLOAD_PROTOCOL}'. Use 'ftp' or 'rsync'." >&2
    exit 1
    ;;
esac

run_in_container() {
  local command_text="$1"

  "${SINGULARITY_BIN}" exec \
    --cleanenv \
    --bind "${PROJECT_DIR}:${PROJECT_DIR}" \
    --bind "${JOB_TMPDIR}:${JOB_TMPDIR}" \
    "${CONTAINER_IMAGE}" \
    bash -c "${command_text}"
}

retry_library_download() {
  local attempt=1

  while [ "${attempt}" -le "${KRAKEN2_DOWNLOAD_MAX_ATTEMPTS}" ]; do
    log "Downloading RefSeq bacteria library into ${DB_DIR}. Attempt ${attempt}/${KRAKEN2_DOWNLOAD_MAX_ATTEMPTS}."
    if run_in_container "set -euo pipefail; export TMPDIR='${JOB_TMPDIR}'; kraken2-build --download-library bacteria ${DOWNLOAD_FLAGS} --threads '${KRAKEN2_THREADS}' --db '${DB_DIR}'"; then
      log "RefSeq bacteria library download completed on attempt ${attempt}."
      return 0
    fi

    if [ "${attempt}" -lt "${KRAKEN2_DOWNLOAD_MAX_ATTEMPTS}" ]; then
      log "RefSeq bacteria library download failed on attempt ${attempt}. Sleeping ${KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC} seconds before retry."
      sleep "${KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC}"
    fi

    attempt=$((attempt + 1))
  done

  log "ERROR: RefSeq bacteria library download failed after ${KRAKEN2_DOWNLOAD_MAX_ATTEMPTS} attempts." >&2
  return 1
}

run_in_container "set -euo pipefail; command -v kraken2-build >/dev/null 2>&1"
require_positive_integer "${KRAKEN2_DOWNLOAD_MAX_ATTEMPTS}" "KRAKEN2_DOWNLOAD_MAX_ATTEMPTS"
require_positive_integer "${KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC}" "KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC"

log "Downloading taxonomy into ${DB_DIR}."
run_in_container "set -euo pipefail; export TMPDIR='${JOB_TMPDIR}'; kraken2-build --download-taxonomy ${DOWNLOAD_FLAGS} --skip-maps --threads '${KRAKEN2_THREADS}' --db '${DB_DIR}'"

retry_library_download

require_file "${DB_DIR}/library/bacteria/assembly_summary.txt" "Kraken2 bacteria library assembly summary"
require_file "${DB_DIR}/library/bacteria/manifest.txt" "Kraken2 bacteria library manifest"

log "Building Kraken2 database."
run_in_container "set -euo pipefail; export TMPDIR='${JOB_TMPDIR}'; kraken2-build --build --threads '${KRAKEN2_THREADS}' ${KRAKEN2_BUILD_EXTRA_ARGS} --db '${DB_DIR}'"

for required_output in hash.k2d opts.k2d taxo.k2d; do
  require_file "${DB_DIR}/${required_output}" "Kraken2 database output"
done

if [ "${KRAKEN2_CLEAN_AFTER_BUILD}" = "1" ]; then
  log "Cleaning intermediate Kraken2 files after successful build."
  run_in_container "set -euo pipefail; export TMPDIR='${JOB_TMPDIR}'; kraken2-build --clean --threads '${KRAKEN2_THREADS}' --db '${DB_DIR}'"
fi

record_disk_snapshot "${AFTER_SNAPSHOT}"

log "Completed bacteria-focused Kraken2 database build."
log "Final database files: ${DB_DIR}/hash.k2d ${DB_DIR}/opts.k2d ${DB_DIR}/taxo.k2d"
log "Disk snapshots: ${BEFORE_SNAPSHOT} ${AFTER_SNAPSHOT}"
log "Build parameters: ${PARAMETERS_FILE}"
log "Assumptions: ${ASSUMPTIONS_FILE}"
log "END kraken2_build_bacterial_db.slurm"
