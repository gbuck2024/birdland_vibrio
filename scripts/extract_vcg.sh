#!/usr/bin/env bash

set -euo pipefail

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  PROJECT_DIR="${SLURM_SUBMIT_DIR}"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

cd "${PROJECT_DIR}"

INPUT_TSV="${INPUT_TSV:-vcg_mining/results/vcg_best_hits_summary.tsv}"
OUTDIR="${OUTDIR:-vcg_mining/extracted_sequences}"

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

resolve_samtools() {
  if command -v samtools >/dev/null 2>&1; then
    SAMTOOLS_BIN="samtools"
    return 0
  fi

  if initialize_modules; then
    for module_name in samtools/1.20 samtools/1.19 samtools; do
      if module load "${module_name}" >/dev/null 2>&1; then
        if command -v samtools >/dev/null 2>&1; then
          SAMTOOLS_BIN="samtools"
          log "Loaded samtools via environment module '${module_name}'."
          return 0
        fi
      fi
    done
  fi

  log "ERROR: samtools not found. Provide it in PATH or load a working samtools module before running." >&2
  exit 1
}

vcg_label_from_qseqid() {
  local qseqid="$1"

  case "${qseqid}" in
    AY626578.1*)
      echo "vcgC"
      ;;
    AY626579.1*)
      echo "vcgE"
      ;;
    *)
      local compact
      compact="$(printf '%s' "${qseqid}" | sed 's/[^A-Za-z0-9._-]/_/g')"
      echo "${compact}"
      ;;
  esac
}

reverse_complement_fasta() {
  local input_fasta="$1"
  local output_fasta="$2"

  python3 - "${input_fasta}" "${output_fasta}" <<'PY'
from pathlib import Path
import sys

input_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

header = None
sequence_parts = []

with input_path.open("r", encoding="utf-8") as handle:
    for line in handle:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith(">"):
            if header is not None:
                raise SystemExit(f"ERROR: Expected one FASTA record in {input_path}")
            header = stripped
        else:
            sequence_parts.append(stripped)

if header is None:
    raise SystemExit(f"ERROR: No FASTA header found in {input_path}")

sequence = "".join(sequence_parts)
translation = str.maketrans("ACGTRYMKBDHVacgtrymkbdhvNn", "TGCAYRKMVHDBtgcayrkmvhdbNn")
reverse_complement = sequence.translate(translation)[::-1]

with output_path.open("w", encoding="utf-8") as handle:
    handle.write(f"{header}\n")
    for index in range(0, len(reverse_complement), 80):
        handle.write(reverse_complement[index:index + 80] + "\n")
PY
}

require_file "${INPUT_TSV}" "vcg best-hit summary TSV"
mkdir -p "${OUTDIR}"
resolve_samtools

processed_count=0
skipped_existing_count=0
no_hit_count=0

while IFS=$'\t' read -r sample_id assembly_fasta blast_output best_hit_found qseqid sseqid pident length qstart qend sstart send evalue bitscore qcovs; do
  if [ "${sample_id}" = "sample_id" ]; then
    continue
  fi

  if [ "${best_hit_found}" != "yes" ]; then
    log "Skipping ${sample_id}: no vcg hit recorded in summary."
    no_hit_count=$((no_hit_count + 1))
    continue
  fi

  require_file "${assembly_fasta}" "assembly FASTA for ${sample_id}"

  sample_prefix="${sample_id%%_WKDL*}"
  vcg_label="$(vcg_label_from_qseqid "${qseqid}")"
  fasta_id="${sample_prefix}_${vcg_label}"
  outfile="${OUTDIR}/${fasta_id}.fasta"
  mapfile -t existing_sample_outputs < <(find "${OUTDIR}" -maxdepth 1 -type f -name "${sample_prefix}_*.fasta" ! -name 'all_vcg_sequences.fasta' | sort)

  if [ -s "${outfile}" ]; then
    log "Skipping ${sample_id}: extracted sequence already exists at ${outfile}"
    skipped_existing_count=$((skipped_existing_count + 1))
    continue
  fi

  if [ "${#existing_sample_outputs[@]}" -gt 0 ]; then
    log "Skipping ${sample_id}: found existing sample-level extraction ${existing_sample_outputs[0]}"
    skipped_existing_count=$((skipped_existing_count + 1))
    continue
  fi

  if [[ "${sstart}" =~ ^[0-9]+$ ]] && [[ "${send}" =~ ^[0-9]+$ ]]; then
    :
  else
    log "ERROR: Non-numeric subject coordinates for ${sample_id}: sstart='${sstart}', send='${send}'" >&2
    exit 1
  fi

  if (( sstart <= send )); then
    start="${sstart}"
    end="${send}"
    strand="forward"
  else
    start="${send}"
    end="${sstart}"
    strand="reverse"
  fi

  region="${sseqid}:${start}-${end}"
  tmp_out="${outfile}.tmp"

  log "Extracting ${sample_id} ${vcg_label} from ${region} (${strand})"

  if [ ! -s "${assembly_fasta}.fai" ] || [ "${assembly_fasta}" -nt "${assembly_fasta}.fai" ]; then
    log "Indexing assembly FASTA: ${assembly_fasta}"
    "${SAMTOOLS_BIN}" faidx "${assembly_fasta}"
  fi

  "${SAMTOOLS_BIN}" faidx "${assembly_fasta}" "${region}" > "${tmp_out}"

  if [ "${strand}" = "reverse" ]; then
    reverse_complement_fasta "${tmp_out}" "${outfile}"
    rm -f "${tmp_out}"
  else
    mv "${tmp_out}" "${outfile}"
  fi

  sed -i "1s|.*|>${fasta_id}|g" "${outfile}"
  processed_count=$((processed_count + 1))
done < "${INPUT_TSV}"

combined_out="${OUTDIR}/all_vcg_sequences.fasta"
tmp_combined="${combined_out}.tmp"

find "${OUTDIR}" -maxdepth 1 -type f -name '*.fasta' ! -name 'all_vcg_sequences.fasta' | sort | while read -r fasta_path; do
  cat "${fasta_path}"
done > "${tmp_combined}"

if [ -s "${tmp_combined}" ]; then
  mv "${tmp_combined}" "${combined_out}"
else
  rm -f "${tmp_combined}"
  log "WARNING: No extracted FASTA files were available to combine."
fi

log "vcg extraction complete. New files: ${processed_count}; existing files reused: ${skipped_existing_count}; no-hit rows skipped: ${no_hit_count}"
