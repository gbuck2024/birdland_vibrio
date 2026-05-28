#!/usr/bin/env bash
# Extract best vcg hit sequences from expanded 46-genome BLAST calls.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

OUTDIR="phylogeny/expanded_vv_46/vcg_tree"
CALLS_TSV="${CALLS_TSV:-${OUTDIR}/metadata/expanded_vv_46_vcg_calls.tsv}"
SEQ_DIR="${OUTDIR}/extracted_sequences"
COMBINED_FASTA="${SEQ_DIR}/expanded_vv_46_vcg_sequences.fasta"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

log() {
  echo "[$(timestamp)] $*"
}

if [ ! -s "${CALLS_TSV}" ]; then
  log "ERROR: VCG call table missing or empty: ${CALLS_TSV}" >&2
  exit 1
fi

mkdir -p "${SEQ_DIR}"

python3 - "${CALLS_TSV}" "${SEQ_DIR}" "${COMBINED_FASTA}" <<'PY'
import csv
import gzip
import re
import sys
from pathlib import Path

calls_tsv = Path(sys.argv[1])
seq_dir = Path(sys.argv[2])
combined_fasta = Path(sys.argv[3])

required = {
    "genome_id", "genome_fasta", "best_vcg_call", "contig_hit",
    "hit_start", "hit_end", "strand",
}
complement = str.maketrans(
    "ACGTRYMKBDHVacgtrymkbdhvNn",
    "TGCAYRKMVHDBtgcayrkmvhdbNn",
)

def sanitize(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", value)

def open_text(path: Path):
    if path.suffix == ".gz":
        return gzip.open(path, "rt", encoding="utf-8")
    return path.open("r", encoding="utf-8")

def fasta_records(path: Path):
    header = None
    parts = []
    with open_text(path) as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped:
                continue
            if stripped.startswith(">"):
                if header is not None:
                    yield header, "".join(parts)
                header = stripped[1:].split()[0]
                parts = []
            else:
                parts.append(stripped)
    if header is not None:
        yield header, "".join(parts)

def wrap(sequence: str, width: int = 80) -> str:
    return "\n".join(sequence[i:i + width] for i in range(0, len(sequence), width))

with calls_tsv.open("r", encoding="utf-8", newline="") as handle:
    rows = list(csv.DictReader(handle, delimiter="\t"))

if not rows:
    raise SystemExit(f"ERROR: VCG call table contains no rows: {calls_tsv}")
missing = required.difference(rows[0].keys())
if missing:
    raise SystemExit(f"ERROR: VCG call table missing required columns: {', '.join(sorted(missing))}")

written = []
skipped = []

for row in rows:
    genome_id = row["genome_id"]
    call = row["best_vcg_call"]
    if call == "not_detected" or row["contig_hit"] == "NA":
        skipped.append((genome_id, call))
        continue

    genome_fasta = Path(row["genome_fasta"])
    if not genome_fasta.is_absolute():
        genome_fasta = Path.cwd() / genome_fasta
    if not genome_fasta.is_file() or genome_fasta.stat().st_size == 0:
        raise SystemExit(f"ERROR: Genome FASTA missing or empty for {genome_id}: {genome_fasta}")

    try:
        start = int(row["hit_start"])
        end = int(row["hit_end"])
    except ValueError as exc:
        raise SystemExit(f"ERROR: Non-numeric coordinates for {genome_id}") from exc
    if start < 1 or end < start:
        raise SystemExit(f"ERROR: Invalid coordinates for {genome_id}: {start}-{end}")

    target = row["contig_hit"]
    sequence = None
    for header, contig_sequence in fasta_records(genome_fasta):
        if header == target:
            if end > len(contig_sequence):
                raise SystemExit(f"ERROR: Coordinates exceed contig length for {genome_id}: {target}:{start}-{end}")
            sequence = contig_sequence[start - 1:end]
            break
    if sequence is None:
        raise SystemExit(f"ERROR: Contig {target} not found in {genome_fasta} for {genome_id}")

    if row["strand"] == "minus":
        sequence = sequence.translate(complement)[::-1]
    elif row["strand"] != "plus":
        raise SystemExit(f"ERROR: Unsupported strand for {genome_id}: {row['strand']}")

    header = f"{genome_id}|{call}"
    out_path = seq_dir / f"{sanitize(genome_id)}_{sanitize(call)}.fasta"
    with out_path.open("w", encoding="utf-8") as out_handle:
        out_handle.write(f">{header}\n{wrap(sequence)}\n")
    written.append(out_path)

with combined_fasta.open("w", encoding="utf-8") as combined:
    for path in sorted(written):
        combined.write(path.read_text(encoding="utf-8"))

if not written:
    raise SystemExit("ERROR: No vcg sequences were extracted.")

print(f"Wrote {len(written)} per-genome FASTA files to {seq_dir}")
print(f"Skipped {len(skipped)} genomes without extractable vcg calls")
print(f"Combined FASTA: {combined_fasta}")
PY

if [ ! -s "${COMBINED_FASTA}" ]; then
  log "ERROR: Combined VCG FASTA missing or empty: ${COMBINED_FASTA}" >&2
  exit 1
fi

log "VCG sequence extraction complete: ${COMBINED_FASTA}"
