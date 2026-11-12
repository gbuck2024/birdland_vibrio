#!/usr/bin/env bash
#SBATCH -J vibrio_mash_nj
#SBATCH -p normal
#SBATCH -t 08:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=32G
#SBATCH -o phylogeny/multispecies_mash/logs/slurm/multispecies_mash_%j.out
#SBATCH -e phylogeny/multispecies_mash/logs/slurm/multispecies_mash_%j.err
set -euo pipefail

# Submit from the project root. This creates an unrooted exploratory Mash/NJ tree.
ROOT="${SLURM_SUBMIT_DIR:?Submit from project root}"
cd "$ROOT"
[[ -s PROJECT_BRIEF.md ]] || { echo 'Submit from the project root' >&2; exit 1; }
STAGE=phylogeny/multispecies_mash
MANIFEST=configs/multispecies_mash_panel.tsv
[[ -s "$MANIFEST" ]] || { echo "Missing $MANIFEST" >&2; exit 1; }
[[ ! -e "$STAGE/sketches" && ! -e "$STAGE/metadata" && ! -e "$STAGE/tree" && ! -e "$STAGE/figures" && ! -e "$STAGE/panel.msh" && ! -e "$STAGE/distances.tsv" ]] || { echo 'Stage output exists; refusing to overwrite' >&2; exit 1; }
mkdir "$STAGE/run.lock" || { echo 'Stage is already running or previously attempted; refusing to overwrite' >&2; exit 1; }
mkdir -p "$STAGE/sketches" "$STAGE/metadata" "$STAGE/tree" "$STAGE/figures"
module load mash/2.3 R/gcc11/4.4.0
command -v mash >/dev/null
command -v Rscript >/dev/null
mash --version > "$STAGE/metadata/mash_version.txt"
Rscript --version > "$STAGE/metadata/r_version.txt" 2>&1
sha256sum "$MANIFEST" > "$STAGE/metadata/manifest.sha256"
printf 'parameter\tvalue\nmethod\tMash distance plus neighbor joining\nmash_k\t21\nmash_sketch_size\t10000\nmash_dist_threads\t%s\nslurm_job_id\t%s\n' "${SLURM_CPUS_PER_TASK:-8}" "${SLURM_JOB_ID:-unknown}" > "$STAGE/metadata/parameters.tsv"
printf 'genome_id\tgenome_fasta\tsha256\n' > "$STAGE/metadata/input_checksums.tsv"
count=0
while IFS=$'\t' read -r id fasta source label; do
  [[ "$id" == genome_id ]] && continue
  [[ "$id" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid genome ID: $id" >&2; exit 1; }
  [[ -s "$fasta" ]] || { echo "Missing/empty genome: $fasta" >&2; exit 1; }
  [[ ! -e "$STAGE/sketches/$id.msh" ]] || { echo "Sketch already exists: $id" >&2; exit 1; }
  hash=$(sha256sum "$fasta" | cut -d' ' -f1)
  printf '%s\t%s\t%s\n' "$id" "$fasta" "$hash" >> "$STAGE/metadata/input_checksums.tsv"
  mash sketch -p 1 -k 21 -s 10000 -o "$STAGE/sketches/$id" "$fasta"
  count=$((count+1))
done < "$MANIFEST"
[[ "$count" -eq 87 ]] || { echo "Expected 87 genomes, got $count" >&2; exit 1; }
mash paste "$STAGE/panel" "$STAGE"/sketches/*.msh
mash dist -p "${SLURM_CPUS_PER_TASK:-8}" "$STAGE/panel.msh" "$STAGE/panel.msh" > "$STAGE/distances.tsv"
Rscript scripts/plot_multispecies_mash_tree.R "$MANIFEST" "$STAGE/distances.tsv" "$STAGE"
[[ -s "$STAGE/tree/unrooted_mash_nj.nwk" && -s "$STAGE/figures/unrooted_mash_nj.pdf" ]] || { echo 'Required tree outputs missing' >&2; exit 1; }
