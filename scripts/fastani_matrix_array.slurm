#!/bin/bash
# Run rectangular fastANI comparisons for reference-panel matrices and
# unknown-vs-reference-panel matrices. Submit compare mode as a SLURM array.
#
# Full panel plus unknowns:
#   sbatch --export=ALL,STAGE_DIR=ani/reference_panel_plus_unknown_matrix,QUERY_MANIFEST=configs/reference_sequence_manifest.tsv,REFERENCE_MANIFEST=configs/reference_sequence_manifest.tsv,EXTRA_QUERY_MANIFEST=configs/ani_unknown_query_manifest.tsv,EXTRA_REFERENCE_MANIFEST=configs/ani_unknown_query_manifest.tsv --array=0-81 scripts/fastani_matrix_array.slurm
#   sbatch --export=ALL,ANI_MODE=matrix,STAGE_DIR=ani/reference_panel_plus_unknown_matrix,QUERY_MANIFEST=configs/reference_sequence_manifest.tsv,REFERENCE_MANIFEST=configs/reference_sequence_manifest.tsv,EXTRA_QUERY_MANIFEST=configs/ani_unknown_query_manifest.tsv,EXTRA_REFERENCE_MANIFEST=configs/ani_unknown_query_manifest.tsv scripts/fastani_matrix_array.slurm
#
# Unknowns against the reference panel only:
#   sbatch --export=ALL,STAGE_DIR=ani/unknown_vs_reference_panel,QUERY_MANIFEST=configs/ani_unknown_query_manifest.tsv,REFERENCE_MANIFEST=configs/reference_sequence_manifest.tsv --array=0-5 scripts/fastani_matrix_array.slurm
#   sbatch --export=ALL,ANI_MODE=matrix,STAGE_DIR=ani/unknown_vs_reference_panel,QUERY_MANIFEST=configs/ani_unknown_query_manifest.tsv,REFERENCE_MANIFEST=configs/reference_sequence_manifest.tsv scripts/fastani_matrix_array.slurm

#SBATCH -J fastani_matrix
#SBATCH -p normal
#SBATCH -t 08:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=32G
#SBATCH -o ani/reference_panel_matrix/logs/slurm/fastani_matrix_%A_%a.out
#SBATCH -e ani/reference_panel_matrix/logs/slurm/fastani_matrix_%A_%a.err

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

MODE="${ANI_MODE:-compare}"
QUERY_MANIFEST="${QUERY_MANIFEST:-configs/reference_sequence_manifest.tsv}"
REFERENCE_MANIFEST="${REFERENCE_MANIFEST:-configs/reference_sequence_manifest.tsv}"
EXTRA_QUERY_MANIFEST="${EXTRA_QUERY_MANIFEST:-}"
EXTRA_REFERENCE_MANIFEST="${EXTRA_REFERENCE_MANIFEST:-}"
STAGE_DIR="${STAGE_DIR:-ani/reference_panel_matrix}"
OUTPUT_DIR="${STAGE_DIR}/outputs"
METRICS_DIR="${STAGE_DIR}/metrics"
LOG_DIR="${STAGE_DIR}/logs"
SLURM_LOG_DIR="${LOG_DIR}/slurm"
SUMMARY_SCRIPT="${SUMMARY_SCRIPT:-scripts/summarize_fastani_matrix.py}"

CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-singularity}"
FASTANI_BIN="${FASTANI_BIN:-fastANI}"
FASTANI_THREADS="${SLURM_CPUS_PER_TASK:-8}"
FASTANI_FRAGLEN="${FASTANI_FRAGLEN:-3000}"
FASTANI_KMER="${FASTANI_KMER:-16}"
FASTANI_MIN_FRACTION="${FASTANI_MIN_FRACTION:-0.2}"
FASTANI_EXTRA_ARGS="${FASTANI_EXTRA_ARGS:-}"

if [ -n "${FASTANI_SIF:-}" ]; then
  CONTAINER_IMAGE="${FASTANI_SIF}"
elif [ -s "${PROJECT_DIR}/containers/fastani_latest.sif" ]; then
  CONTAINER_IMAGE="${PROJECT_DIR}/containers/fastani_latest.sif"
elif [ -s "${PROJECT_DIR}/containers/fastani.sif" ]; then
  CONTAINER_IMAGE="${PROJECT_DIR}/containers/fastani.sif"
elif [ -s "${PROJECT_DIR}/fastani_latest.sif" ]; then
  CONTAINER_IMAGE="${PROJECT_DIR}/fastani_latest.sif"
else
  CONTAINER_IMAGE="${PROJECT_DIR}/fastani.sif"
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

require_path_exists() {
  local path="$1"
  local label="$2"

  if [ ! -e "${path}" ]; then
    log "ERROR: ${label} not found: ${path}" >&2
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

normalize_manifest() {
  local primary_manifest="$1"
  local extra_manifest="$2"
  local output_manifest="$3"

  python3 - "${primary_manifest}" "${extra_manifest}" "${output_manifest}" <<'PY'
import csv
import re
import sys
from pathlib import Path

primary = Path(sys.argv[1])
extra = sys.argv[2]
out = Path(sys.argv[3])

def parse_species(notes, genome_id):
    match = re.search(r"Vibrio [a-z]+", notes or "")
    if match:
        return match.group(0)
    if genome_id.startswith("Buck_"):
        return "unknown"
    return "unknown"

def load(path):
    if not path.is_file():
        raise SystemExit(f"ERROR: Manifest not found: {path}")
    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if not rows:
        raise SystemExit(f"ERROR: Manifest has no data rows: {path}")
    normalized = []
    for row in rows:
        genome_id = row.get("genome_id") or row.get("reference_id") or row.get("sample_id")
        genome_fasta = row.get("genome_fasta") or row.get("reference_fasta") or row.get("query_fasta")
        if not genome_id or not genome_fasta:
            raise SystemExit(f"ERROR: Manifest row lacks usable ID/path columns in {path}: {row}")
        notes = row.get("notes", "")
        normalized.append({
            "genome_id": genome_id,
            "genome_fasta": genome_fasta,
            "species": row.get("species") or parse_species(notes, genome_id),
            "genome_type": row.get("genome_type") or row.get("reference_format") or row.get("query_format") or "query_genome",
            "is_unknown": "yes" if genome_id.startswith("Buck_") else row.get("is_unknown", "no"),
            "notes": notes,
        })
    return normalized

rows = load(primary)
if extra:
    rows.extend(load(Path(extra)))

seen = set()
for row in rows:
    if row["genome_id"] in seen:
        raise SystemExit(f"ERROR: Duplicate genome_id in matrix manifests: {row['genome_id']}")
    seen.add(row["genome_id"])

out.parent.mkdir(parents=True, exist_ok=True)
with out.open("w", encoding="utf-8", newline="") as handle:
    writer = csv.DictWriter(
        handle,
        fieldnames=["genome_id", "genome_fasta", "species", "genome_type", "is_unknown", "notes"],
        delimiter="\t",
    )
    writer.writeheader()
    writer.writerows(rows)
PY
}

resolve_fastani_bin() {
  local candidate=""

  for candidate in "${FASTANI_BIN}" fastANI fastani; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      FASTANI_BIN="${candidate}"
      log "Using fastANI executable: ${FASTANI_BIN}"
      return 0
    fi
  done

  if command -v module >/dev/null 2>&1; then
    module purge
    if module load fastani >/dev/null 2>&1 || module load FastANI >/dev/null 2>&1; then
      for candidate in "${FASTANI_BIN}" fastANI fastani; do
        if command -v "${candidate}" >/dev/null 2>&1; then
          FASTANI_BIN="${candidate}"
          log "Using fastANI executable from module: ${FASTANI_BIN}"
          return 0
        fi
      done
    fi
    module purge
  fi

  log "ERROR: fastANI executable not found. Set FASTANI_BIN or provide a container image with FASTANI_SIF." >&2
  return 1
}

run_fastani_in_container() {
  require_command "${CONTAINER_RUNTIME}"
  require_file "${CONTAINER_IMAGE}" "fastANI container image"

  log "Using container runtime: ${CONTAINER_RUNTIME}"
  log "Using container image: ${CONTAINER_IMAGE}"

  "${CONTAINER_RUNTIME}" exec \
    --cleanenv \
    --bind "${PROJECT_DIR}:${PROJECT_DIR}" \
    "${CONTAINER_IMAGE}" \
    bash -c "
      set -euo pipefail
      if command -v '${FASTANI_BIN}' >/dev/null 2>&1; then
        resolved_fastani='${FASTANI_BIN}'
      elif command -v fastANI >/dev/null 2>&1; then
        resolved_fastani='fastANI'
      elif command -v fastani >/dev/null 2>&1; then
        resolved_fastani='fastani'
      else
        echo 'fastANI executable not found inside container.' >&2
        exit 1
      fi
      # These paths are expanded by the host shell before entering the container.
      \"\${resolved_fastani}\" \
        --query '${query_fasta}' \
        --rl '${REFERENCE_LIST_FILE}' \
        --output '${sample_output}' \
        --threads '${FASTANI_THREADS}' \
        --fragLen '${FASTANI_FRAGLEN}' \
        --kmer '${FASTANI_KMER}' \
        --minFraction '${FASTANI_MIN_FRACTION}' \
        ${FASTANI_EXTRA_ARGS}
    "
}

mkdir -p "${OUTPUT_DIR}" "${METRICS_DIR}" "${LOG_DIR}" "${SLURM_LOG_DIR}"

NORMALIZED_QUERY_MANIFEST="${METRICS_DIR}/query_manifest.normalized.tsv"
NORMALIZED_REFERENCE_MANIFEST="${METRICS_DIR}/reference_manifest.normalized.tsv"
REFERENCE_LIST_FILE="${METRICS_DIR}/fastani_reference_list.txt"

normalize_manifest "${QUERY_MANIFEST}" "${EXTRA_QUERY_MANIFEST}" "${NORMALIZED_QUERY_MANIFEST}"
normalize_manifest "${REFERENCE_MANIFEST}" "${EXTRA_REFERENCE_MANIFEST}" "${NORMALIZED_REFERENCE_MANIFEST}"
awk -F '\t' 'NR > 1 {print $2}' "${NORMALIZED_REFERENCE_MANIFEST}" > "${REFERENCE_LIST_FILE}"

log "START fastani_matrix_array.slurm"
log "Project directory: ${PROJECT_DIR}"
log "Mode: ${MODE}"
log "Stage directory: ${STAGE_DIR}"
log "Query manifest: ${QUERY_MANIFEST}"
log "Reference manifest: ${REFERENCE_MANIFEST}"
log "Extra query manifest: ${EXTRA_QUERY_MANIFEST:-none}"
log "Extra reference manifest: ${EXTRA_REFERENCE_MANIFEST:-none}"
log "Container image candidate: ${CONTAINER_IMAGE}"

require_file "${NORMALIZED_QUERY_MANIFEST}" "Normalized query manifest"
require_file "${NORMALIZED_REFERENCE_MANIFEST}" "Normalized reference manifest"
require_file "${REFERENCE_LIST_FILE}" "fastANI reference list"

while IFS= read -r reference_fasta; do
  require_file "${reference_fasta}" "Reference FASTA listed for ANI"
done < "${REFERENCE_LIST_FILE}"

if [ "${MODE}" = "matrix" ] || [ "${MODE}" = "summary" ]; then
  require_file "${SUMMARY_SCRIPT}" "ANI matrix summary script"
  QUERY_MANIFEST="${QUERY_MANIFEST}" \
  REFERENCE_MANIFEST="${REFERENCE_MANIFEST}" \
  EXTRA_QUERY_MANIFEST="${EXTRA_QUERY_MANIFEST}" \
  EXTRA_REFERENCE_MANIFEST="${EXTRA_REFERENCE_MANIFEST}" \
  STAGE_DIR="${STAGE_DIR}" \
    python3 "${SUMMARY_SCRIPT}"
  log "END fastani_matrix_array.slurm"
  exit 0
fi

if [ "${MODE}" != "compare" ]; then
  log "ERROR: Unsupported ANI_MODE='${MODE}'. Use 'compare', 'matrix', or 'summary'." >&2
  exit 1
fi

if [ -z "${SLURM_ARRAY_TASK_ID:-}" ]; then
  log "ERROR: Submit ANI compare mode with sbatch --array=0-N." >&2
  exit 1
fi

mapfile -t QUERY_ROWS < <(tail -n +2 "${NORMALIZED_QUERY_MANIFEST}")

if [ "${#QUERY_ROWS[@]}" -eq 0 ]; then
  log "ERROR: ANI query manifest contains no sample rows." >&2
  exit 1
fi

if [ "${SLURM_ARRAY_TASK_ID}" -lt 0 ] || [ "${SLURM_ARRAY_TASK_ID}" -ge "${#QUERY_ROWS[@]}" ]; then
  log "ERROR: SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID} is outside 0-$(( ${#QUERY_ROWS[@]} - 1 ))." >&2
  exit 1
fi

IFS=$'\t' read -r sample_id query_fasta query_species query_type query_is_unknown query_notes <<< "${QUERY_ROWS[${SLURM_ARRAY_TASK_ID}]}"

if [ -z "${sample_id}" ] || [ -z "${query_fasta}" ]; then
  log "ERROR: Query manifest row ${SLURM_ARRAY_TASK_ID} is malformed." >&2
  exit 1
fi

require_file "${query_fasta}" "ANI query FASTA"

sample_output="${OUTPUT_DIR}/${sample_id}.fastani.tsv"
rm -f "${sample_output}"

log "Query ID: ${sample_id}"
log "Query species: ${query_species}"
log "Query type: ${query_type}"
log "Query FASTA: ${query_fasta}"
log "Raw output: ${sample_output}"

if [ -s "${CONTAINER_IMAGE}" ]; then
  run_fastani_in_container
else
  resolve_fastani_bin
  "${FASTANI_BIN}" \
    --query "${query_fasta}" \
    --rl "${REFERENCE_LIST_FILE}" \
    --output "${sample_output}" \
    --threads "${FASTANI_THREADS}" \
    --fragLen "${FASTANI_FRAGLEN}" \
    --kmer "${FASTANI_KMER}" \
    --minFraction "${FASTANI_MIN_FRACTION}" \
    ${FASTANI_EXTRA_ARGS}
fi

require_path_exists "${sample_output}" "Raw fastANI output"

log "Completed ANI comparison for ${sample_id}"
log "END fastani_matrix_array.slurm"
