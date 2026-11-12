#!/bin/bash
# Poster 25/50/100x SPAdes assemblies; additive and restart-safe.
#SBATCH -J abrcms_spades
#SBATCH -p normal
#SBATCH -t 48:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 16
#SBATCH --mem=128G
#SBATCH -o ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111/logs/slurm/assemble_%A_%a.out
#SBATCH -e ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111/logs/slurm/assemble_%A_%a.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?Submit from project root}"
test -s PROJECT_BRIEF.md
stage=ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111
manifest=configs/abrcms_poster_depth_20261111_assembly.tsv
test -s "$manifest"
test -s containers/spades.sif
command -v singularity >/dev/null
test -n "${SLURM_ARRAY_TASK_ID:-}"
mapfile -t rows < <(tail -n +2 "$manifest")
(( SLURM_ARRAY_TASK_ID >= 0 && SLURM_ARRAY_TASK_ID < ${#rows[@]} ))
IFS=$'\t' read -r sample_id r1 r2 <<< "${rows[$SLURM_ARRAY_TASK_ID]}"
test "$(basename "$r1")" = "${sample_id}_1_paired.fq.gz"
test "$(basename "$r2")" = "${sample_id}_2_paired.fq.gz"
test -s "$r1"
test -s "$r2"
metrics="$stage/metrics/${sample_id}.subsampling_metrics.tsv"
test -s "$metrics"
python3 - "$r1" "$r2" "$metrics" <<'PY'
import csv, sys
from pathlib import Path
sys.path.insert(0, 'scripts')
from subsample_paired_fastq import count_and_validate_pairs
with open(sys.argv[3], newline='') as handle:
    row = next(csv.DictReader(handle, delimiter='\t'))
expected = int(row['target_read_pairs'])
actual = count_and_validate_pairs(Path(sys.argv[1]), Path(sys.argv[2]))
if actual != expected or int(row['actual_read_pairs']) != actual:
    raise SystemExit(f'Paired-read count mismatch: actual={actual}, target={expected}')
PY
out="$stage/assembly/assemblies/$sample_id"
tmp="$stage/assembly/tmp/${sample_id}_${SLURM_JOB_ID}"
log="$stage/assembly/logs/${sample_id}.spades.log"
test ! -e "$out"
test ! -e "$tmp"
test ! -e "$log"
mkdir -p "$stage/assembly/assemblies" "$stage/assembly/tmp" "$stage/assembly/logs"
mkdir "$out" # exclusive per-condition run lock
singularity exec --cleanenv --bind "$PWD:$PWD" containers/spades.sif \
    spades.py --isolate --pe1-1 "$r1" --pe1-2 "$r2" \
    -o "$out" -t "${SLURM_CPUS_PER_TASK:-16}" -m 120 --tmp-dir "$tmp" \
    2>&1 | tee "$log"
test -s "$out/contigs.fasta"
test -s "$out/scaffolds.fasta"
test -s "$out/params.txt"
test -s "$out/spades.log"
echo "PASS $sample_id"
