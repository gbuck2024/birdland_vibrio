#!/usr/bin/env bash
# Mine vcgC/vcgE alleles from the expanded 46-genome manifest with BLAST.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

MANIFEST="${MANIFEST:-configs/expanded_vv_46_genome_manifest.tsv}"
REFERENCE_FASTA="${REFERENCE_FASTA:-vcg_mining/vcg_reference_alleles.fasta}"
FALLBACK_REFERENCE_FASTA="vcg_mining/references/vcg_reference_alleles.fasta"
OUTDIR="phylogeny/expanded_vv_46/vcg_tree"
BLAST_DIR="${OUTDIR}/blast"
METADATA_DIR="${OUTDIR}/metadata"
LOG_DIR="${OUTDIR}/logs"
CALLS_TSV="${METADATA_DIR}/expanded_vv_46_vcg_calls.tsv"

BLASTN_BIN="${BLASTN_BIN:-blastn}"
BLAST_TASK="${BLAST_TASK:-blastn}"
BLAST_EVALUE="${BLAST_EVALUE:-1e-10}"
BLAST_MAX_TARGET_SEQS="${BLAST_MAX_TARGET_SEQS:-20}"
MIN_PIDENT="${MIN_PIDENT:-90}"
MIN_QCOV="${MIN_QCOV:-80}"
AMBIGUOUS_BITSCORE_DELTA="${AMBIGUOUS_BITSCORE_DELTA:-5}"
AMBIGUOUS_PIDENT_DELTA="${AMBIGUOUS_PIDENT_DELTA:-2}"

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

resolve_blastn() {
  if command -v "${BLASTN_BIN}" >/dev/null 2>&1; then
    return 0
  fi
  if initialize_modules; then
    for module_name in blast+ blast ncbi-blast+ ncbi-blast BLAST+ BLAST; do
      if module load "${module_name}" >/dev/null 2>&1 && command -v blastn >/dev/null 2>&1; then
        BLASTN_BIN="blastn"
        log "Loaded BLAST via environment module '${module_name}'."
        return 0
      fi
      module purge >/dev/null 2>&1 || true
    done
  fi
  log "ERROR: blastn not found. Provide BLAST in PATH or load a working BLAST module." >&2
  exit 1
}

sanitize_id() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9._-]/_/g'
}

mkdir -p "${BLAST_DIR}" "${METADATA_DIR}" "${LOG_DIR}"
require_file "${MANIFEST}" "expanded 46-genome manifest"

if [ ! -s "${REFERENCE_FASTA}" ] && [ -s "${FALLBACK_REFERENCE_FASTA}" ]; then
  log "Reference FASTA not found at ${REFERENCE_FASTA}; using ${FALLBACK_REFERENCE_FASTA}"
  REFERENCE_FASTA="${FALLBACK_REFERENCE_FASTA}"
fi
require_file "${REFERENCE_FASTA}" "vcg reference allele FASTA"
resolve_blastn

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/expanded_vv_vcg.XXXXXX")"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

calls_tmp="${CALLS_TSV}.tmp"
printf 'genome_id\tgenome_fasta\tbest_vcg_call\tbest_reference_allele\tpercent_identity\talignment_length\tquery_coverage\tevalue\tbitscore\tcontig_hit\thit_start\thit_end\tstrand\tnotes\n' > "${calls_tmp}"

python3 - "${MANIFEST}" "${REFERENCE_FASTA}" "${BLAST_DIR}" "${calls_tmp}" "${tmp_dir}" "${BLASTN_BIN}" "${BLAST_TASK}" "${BLAST_EVALUE}" "${BLAST_MAX_TARGET_SEQS}" "${MIN_PIDENT}" "${MIN_QCOV}" "${AMBIGUOUS_BITSCORE_DELTA}" "${AMBIGUOUS_PIDENT_DELTA}" <<'PY'
import csv
import gzip
import os
import re
import subprocess
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
reference_fasta = Path(sys.argv[2])
blast_dir = Path(sys.argv[3])
calls_tmp = Path(sys.argv[4])
tmp_dir = Path(sys.argv[5])
blastn_bin = sys.argv[6]
blast_task = sys.argv[7]
blast_evalue = sys.argv[8]
blast_max_target_seqs = sys.argv[9]
min_pident = float(sys.argv[10])
min_qcov = float(sys.argv[11])
ambiguous_bitscore_delta = float(sys.argv[12])
ambiguous_pident_delta = float(sys.argv[13])

blast_columns = [
    "qseqid", "sseqid", "pident", "length", "qlen", "qstart", "qend",
    "sstart", "send", "evalue", "bitscore"
]
known_buck_calls = {
    "BS0607_9": "vcgE",
    "CB0707_82": "vcgC",
    "NB0507_8": "vcgE",
}

def rel(path: Path) -> str:
    try:
        return str(path.relative_to(Path.cwd()))
    except ValueError:
        return str(path)

def allele_type(qseqid: str) -> str:
    lower = qseqid.lower()
    if qseqid.startswith("AY626578.1") or "vcgc" in lower:
        return "vcgC"
    if qseqid.startswith("AY626579.1") or "vcge" in lower:
        return "vcgE"
    return "unknown"

def sanitize(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", value)

def open_text(path: Path):
    if path.suffix == ".gz":
        return gzip.open(path, "rt", encoding="utf-8")
    return path.open("r", encoding="utf-8")

def stage_subject(genome_fasta: Path, genome_id: str) -> Path:
    if genome_fasta.suffix != ".gz":
        return genome_fasta
    staged = tmp_dir / f"{sanitize(genome_id)}.fasta"
    with open_text(genome_fasta) as src, staged.open("w", encoding="utf-8") as dst:
        for line in src:
            dst.write(line)
    return staged

def parse_blast(path: Path) -> list[dict[str, str]]:
    rows = []
    if not path.exists():
        return rows
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.rstrip("\n")
            if not stripped:
                continue
            fields = stripped.split("\t")
            if len(fields) != len(blast_columns):
                raise SystemExit(f"ERROR: Unexpected BLAST column count in {path} line {line_number}")
            row = dict(zip(blast_columns, fields))
            row["pident_float"] = float(row["pident"])
            row["length_int"] = int(float(row["length"]))
            row["qlen_int"] = int(float(row["qlen"]))
            row["qcov_float"] = (row["length_int"] / row["qlen_int"]) * 100 if row["qlen_int"] else 0.0
            row["bitscore_float"] = float(row["bitscore"])
            row["evalue_float"] = float(row["evalue"])
            row["allele_type"] = allele_type(row["qseqid"])
            rows.append(row)
    rows.sort(key=lambda r: (r["bitscore_float"], -r["evalue_float"], r["pident_float"], r["qcov_float"]), reverse=True)
    return rows

def classify(best, rows):
    if best is None:
        return "not_detected", ["no_blast_hit"]
    notes = []
    strong = [
        row for row in rows
        if row["pident_float"] >= min_pident and row["qcov_float"] >= min_qcov and row["allele_type"] in {"vcgC", "vcgE"}
    ]
    if best["pident_float"] < min_pident or best["qcov_float"] < min_qcov or best["allele_type"] not in {"vcgC", "vcgE"}:
        return "not_detected", [f"best_hit_below_thresholds_min_pident_{min_pident:g}_min_qcov_{min_qcov:g}"]
    best_type = best["allele_type"]
    competing = [
        row for row in strong
        if row["allele_type"] != best_type
        and abs(row["bitscore_float"] - best["bitscore_float"]) <= ambiguous_bitscore_delta
        and abs(row["pident_float"] - best["pident_float"]) <= ambiguous_pident_delta
    ]
    if competing:
        notes.append("vcgC_and_vcgE_hits_similar")
        return "ambiguous", notes
    notes.append("strong_hit")
    return best_type, notes

with manifest_path.open("r", encoding="utf-8", newline="") as handle:
    manifest_rows = list(csv.DictReader(handle, delimiter="\t"))

if not manifest_rows:
    raise SystemExit(f"ERROR: Manifest contains no rows: {manifest_path}")

fieldnames = set(manifest_rows[0].keys())
id_col = "genome_id" if "genome_id" in fieldnames else "reference_id" if "reference_id" in fieldnames else None
fasta_col = "genome_fasta" if "genome_fasta" in fieldnames else "reference_fasta" if "reference_fasta" in fieldnames else None
if id_col is None or fasta_col is None:
    raise SystemExit("ERROR: Manifest must contain genome_id/genome_fasta or reference_id/reference_fasta columns.")

with calls_tmp.open("a", encoding="utf-8", newline="") as calls_handle:
    writer = csv.writer(calls_handle, delimiter="\t", lineterminator="\n")
    for row in manifest_rows:
        genome_id = row[id_col]
        genome_fasta_text = row[fasta_col]
        genome_fasta = Path(genome_fasta_text)
        if not genome_fasta.is_absolute():
            genome_fasta = Path.cwd() / genome_fasta
        blast_out = blast_dir / f"{sanitize(genome_id)}.vcg.blast.tsv"
        notes: list[str] = []

        if not genome_fasta.is_file() or genome_fasta.stat().st_size == 0:
            writer.writerow([genome_id, genome_fasta_text, "not_detected", "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", "missing_or_empty_genome_fasta"])
            continue

        subject = stage_subject(genome_fasta, genome_id)
        cmd = [
            blastn_bin,
            "-task", blast_task,
            "-query", str(reference_fasta),
            "-subject", str(subject),
            "-evalue", blast_evalue,
            "-max_target_seqs", blast_max_target_seqs,
            "-outfmt", "6 " + " ".join(blast_columns),
        ]
        with blast_out.open("w", encoding="utf-8") as out_handle:
            completed = subprocess.run(cmd, stdout=out_handle, stderr=subprocess.PIPE, text=True)
        if completed.returncode != 0:
            raise SystemExit(f"ERROR: blastn failed for {genome_id}: {completed.stderr.strip()}")

        hits = parse_blast(blast_out)
        best = hits[0] if hits else None
        call, call_notes = classify(best, hits)
        notes.extend(call_notes)
        for buck_id, expected in known_buck_calls.items():
            if buck_id in genome_id:
                if call == expected:
                    notes.append(f"known_buck_call_confirmed_{expected}")
                else:
                    notes.append(f"known_buck_call_mismatch_expected_{expected}")

        if best is None:
            writer.writerow([genome_id, genome_fasta_text, call, "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", ";".join(notes)])
            continue

        sstart = int(best["sstart"])
        send = int(best["send"])
        strand = "plus" if sstart <= send else "minus"
        hit_start, hit_end = sorted([sstart, send])
        writer.writerow([
            genome_id,
            genome_fasta_text,
            call,
            best["qseqid"],
            f"{best['pident_float']:.3f}",
            best["length"],
            f"{best['qcov_float']:.2f}",
            best["evalue"],
            best["bitscore"],
            best["sseqid"],
            hit_start,
            hit_end,
            strand,
            ";".join(notes),
        ])

print(f"Wrote {calls_tmp}")
PY

mv "${calls_tmp}" "${CALLS_TSV}"
log "VCG mining complete."
log "Call table: ${CALLS_TSV}"
log "Per-genome BLAST TSV files: ${BLAST_DIR}"
