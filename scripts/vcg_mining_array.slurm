#!/bin/bash
# Search selected Vibrio vulnificus assemblies for vcg reference alleles with BLAST.
# Submit as a SLURM array job; do not run BLAST searches on a login node.
#
# How to run:
# 1. Submit one BLAST task per saved assembly:
#    sbatch --array=0-2 scripts/vcg_mining_array.slurm
# 2. After the array job completes, summarize the best hit per sample:
#    sbatch --export=ALL,VCG_MODE=summary scripts/vcg_mining_array.slurm
#
# To reuse this workflow for another stage, override MANIFEST_FILE and STAGE_DIR.
# Use sbatch -o/-e at submission time if the alternate stage should receive its
# own SLURM stdout/stderr files.

#SBATCH -J vcg_mining
#SBATCH -p normal
#SBATCH -t 04:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem=16G
#SBATCH -o vcg_mining/logs/slurm/vcg_mining_%A_%a.out
#SBATCH -e vcg_mining/logs/slurm/vcg_mining_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MODE="${VCG_MODE:-blast}"
MANIFEST_FILE="${MANIFEST_FILE:-configs/vcg_mining_manifest.tsv}"
STAGE_DIR="${STAGE_DIR:-vcg_mining}"
STAGE_REFERENCE_FASTA="${STAGE_DIR}/references/vcg_reference_alleles.fasta"
SHARED_REFERENCE_FASTA="vcg_mining/references/vcg_reference_alleles.fasta"
REFERENCE_NOTE=""
if [ -z "${REFERENCE_FASTA:-}" ]; then
  if [ -s "${STAGE_REFERENCE_FASTA}" ]; then
    REFERENCE_FASTA="${STAGE_REFERENCE_FASTA}"
  elif [ "${STAGE_DIR}" != "vcg_mining" ] && [ -s "${SHARED_REFERENCE_FASTA}" ]; then
    REFERENCE_FASTA="${SHARED_REFERENCE_FASTA}"
    REFERENCE_NOTE="stage-local reference missing; reusing shared vcg reference FASTA"
  else
    REFERENCE_FASTA="${STAGE_REFERENCE_FASTA}"
  fi
fi
RESULTS_DIR="${STAGE_DIR}/results"
LOG_DIR="${STAGE_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
DB_DIR="${RESULTS_DIR}/blast_db"
SUMMARY_SCRIPT="${SUMMARY_SCRIPT:-scripts/summarize_vcg_hits.py}"
SUMMARY_OUT="${SUMMARY_OUT:-${RESULTS_DIR}/vcg_best_hits_summary.tsv}"

BLASTN_BIN="${BLASTN_BIN:-blastn}"
MAKEBLASTDB_BIN="${MAKEBLASTDB_BIN:-makeblastdb}"
BLAST_THREADS="${SLURM_CPUS_PER_TASK:-4}"
BLAST_TASK="${BLAST_TASK:-blastn}"
BLAST_MAX_TARGET_SEQS="${BLAST_MAX_TARGET_SEQS:-25}"
BLAST_EVALUE="${BLAST_EVALUE:-1e-10}"
BLAST_EXTRA_ARGS="${BLAST_EXTRA_ARGS:-}"

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

resolve_blast_tools() {
  local blastn_candidate=""
  local makeblastdb_candidate=""

  for blastn_candidate in "${BLASTN_BIN}" blastn; do
    if command -v "${blastn_candidate}" >/dev/null 2>&1; then
      BLASTN_BIN="${blastn_candidate}"
      break
    fi
  done

  for makeblastdb_candidate in "${MAKEBLASTDB_BIN}" makeblastdb; do
    if command -v "${makeblastdb_candidate}" >/dev/null 2>&1; then
      MAKEBLASTDB_BIN="${makeblastdb_candidate}"
      break
    fi
  done

  if command -v "${BLASTN_BIN}" >/dev/null 2>&1 && command -v "${MAKEBLASTDB_BIN}" >/dev/null 2>&1; then
    log "Using BLAST executables: ${BLASTN_BIN}, ${MAKEBLASTDB_BIN}"
    return 0
  fi

  if initialize_modules; then
    module purge
    for module_name in blast+ blast ncbi-blast+ ncbi-blast BLAST+ BLAST; do
      if module load "${module_name}" >/dev/null 2>&1; then
        if command -v blastn >/dev/null 2>&1 && command -v makeblastdb >/dev/null 2>&1; then
          BLASTN_BIN="blastn"
          MAKEBLASTDB_BIN="makeblastdb"
          log "Loaded BLAST via environment module '${module_name}'."
          log "Using BLAST executables: ${BLASTN_BIN}, ${MAKEBLASTDB_BIN}"
          return 0
        fi
      fi
      module purge
    done
  fi

  log "ERROR: BLAST tools not found. Provide blastn/makeblastdb in PATH or load a working BLAST module before submission." >&2
  return 1
}

build_assembly_db() {
  local sample_id="$1"
  local assembly_fasta="$2"
  local db_prefix="${DB_DIR}/${sample_id}"
  local rebuild_db=0
  local suffix=""

  mkdir -p "${DB_DIR}"

  for suffix in nhr nin nsq; do
    if [ ! -s "${db_prefix}.${suffix}" ]; then
      rebuild_db=1
      break
    fi
  done

  if [ "${rebuild_db}" -eq 0 ] && [ "${assembly_fasta}" -nt "${db_prefix}.nhr" ]; then
    rebuild_db=1
  fi

  if [ "${rebuild_db}" -eq 1 ]; then
    log "Building BLAST database from ${assembly_fasta}"
    "${MAKEBLASTDB_BIN}" \
      -in "${assembly_fasta}" \
      -dbtype nucl \
      -parse_seqids \
      -out "${db_prefix}" \
      > "${LOG_DIR}/${sample_id}.makeblastdb.log" 2>&1
  else
    log "Reusing existing BLAST database: ${db_prefix}"
  fi

  SAMPLE_DB_PREFIX="${db_prefix}"
}

mkdir -p "${RESULTS_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}"

log "START vcg_mining_array.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Mode: ${MODE}"
log "Manifest: ${MANIFEST_FILE}"
log "Stage directory: ${STAGE_DIR}"
log "Reference FASTA: ${REFERENCE_FASTA}"
if [ -n "${REFERENCE_NOTE}" ]; then
  log "Reference selection note: ${REFERENCE_NOTE}"
fi

require_file "${MANIFEST_FILE}" "vcg mining manifest"

if [ "${MODE}" = "summary" ]; then
  require_file "${SUMMARY_SCRIPT}" "vcg summary script"
  python3 "${SUMMARY_SCRIPT}" \
    --manifest "${MANIFEST_FILE}" \
    --summary-out "${SUMMARY_OUT}"
  log "END vcg_mining_array.slurm"
  exit 0
fi

if [ "${MODE}" != "blast" ]; then
  log "ERROR: Unsupported VCG_MODE='${MODE}'. Use 'blast' or 'summary'." >&2
  exit 1
fi

require_file "${REFERENCE_FASTA}" "vcg reference FASTA"

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit blast mode with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t SAMPLE_ROWS < <(tail -n +2 "${MANIFEST_FILE}")

if [ "${#SAMPLE_ROWS[@]}" -eq 0 ]; then
  log "ERROR: vcg mining manifest contains no sample rows." >&2
  exit 1
fi

if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#SAMPLE_ROWS[@]}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#SAMPLE_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r sample_id assembly_fasta blast_output <<< "${SAMPLE_ROWS[${SLURM_ARRAY_TASK_ID}]}"

if [ -z "${sample_id}" ] || [ -z "${assembly_fasta}" ] || [ -z "${blast_output}" ]; then
  log "ERROR: Manifest row ${SLURM_ARRAY_TASK_ID} is malformed." >&2
  exit 1
fi

require_file "${assembly_fasta}" "assembly FASTA"

assembly_base="$(basename "${assembly_fasta}")"
assembly_dir="$(dirname "${assembly_fasta}")"
assembly_dir_base="$(basename "${assembly_dir}")"

if [ "${assembly_dir_base}" != "${sample_id}" ]; then
  log "NOTE: sample_id '${sample_id}' does not match assembly directory name '${assembly_dir_base}'; continuing because manifest sample IDs may be simplified labels."
fi

if [ "${assembly_base}" != "scaffolds.fasta" ] && [ "${assembly_base}" != "contigs.fasta" ]; then
  log "ERROR: Assembly FASTA must be scaffolds.fasta or contigs.fasta: ${assembly_fasta}" >&2
  exit 1
fi

resolve_blast_tools
build_assembly_db "${sample_id}" "${assembly_fasta}"

mkdir -p "$(dirname "${blast_output}")"
tmp_output="${blast_output}.tmp"
rm -f "${tmp_output}"

log "Sample: ${sample_id}"
log "Assembly FASTA: ${assembly_fasta}"
log "BLAST output: ${blast_output}"
log "BLAST task: ${BLAST_TASK}"
log "BLAST e-value cutoff: ${BLAST_EVALUE}"
log "BLAST max target sequences: ${BLAST_MAX_TARGET_SEQS}"
log "BLAST threads: ${BLAST_THREADS}"

"${BLASTN_BIN}" \
  -task "${BLAST_TASK}" \
  -query "${REFERENCE_FASTA}" \
  -db "${SAMPLE_DB_PREFIX}" \
  -evalue "${BLAST_EVALUE}" \
  -max_target_seqs "${BLAST_MAX_TARGET_SEQS}" \
  -num_threads "${BLAST_THREADS}" \
  -outfmt "6 qseqid sseqid pident length qstart qend sstart send evalue bitscore qcovs" \
  ${BLAST_EXTRA_ARGS} \
  > "${tmp_output}"

mv "${tmp_output}" "${blast_output}"

log "END vcg_mining_array.slurm"
