#!/bin/bash
# Map both sequencing runs to the COMPLETE old downsampled assembly, then
# measure high-quality read support for every contig and summarize 41 targets.
# Submit from the project root after creating the stage logs directory.
#SBATCH -J reyranella_map
#SBATCH -p normal
#SBATCH -t 36:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=32G
#SBATCH -o comparison_nb0507_14_resequencing/reyranella_validation/read_mapping/logs/map_%j.out
#SBATCH -e comparison_nb0507_14_resequencing/reyranella_validation/read_mapping/logs/map_%j.err

set -euo pipefail

# SLURM spools the batch script elsewhere, so its source path is not a
# reliable way to locate the project. Submission must occur from the root.
if [[ -z "${SLURM_SUBMIT_DIR:-}" ]]; then
  echo 'SLURM_SUBMIT_DIR is unset; submit this job from the project root.' >&2
  exit 1
fi
cd "${SLURM_SUBMIT_DIR}"
if [[ ! -f PROJECT_BRIEF.md || ! -f scripts/reyranella_read_mapping_report.py ]]; then
  echo "SLURM_SUBMIT_DIR is not the project root: ${SLURM_SUBMIT_DIR}" >&2
  exit 1
fi

stage="comparison_nb0507_14_resequencing/reyranella_validation/read_mapping"
manifest="comparison_nb0507_14_resequencing/manifests/reyranella_read_mapping.tsv"
reference="comparison_nb0507_14_resequencing/downsampled_old_assembly/assemblies/Buck_NB0507_14_downsampled_to_SRR37852095_L7/contigs.fasta"
candidates="comparison_nb0507_14_resequencing/reyranella_validation/reyranella_1kb_ids.txt"
index="${stage}/index/full_downsampled_old_contigs"

module load bowtie2/2.5.3 samtools/1.20
[[ "$(bowtie2 --version | sed -n '1s/.*version //p')" == "2.5.3" ]] || { echo 'Bowtie2 version mismatch' >&2; exit 1; }
[[ "$(samtools --version | sed -n '1s/samtools //p')" == "1.20" ]] || { echo 'samtools version mismatch' >&2; exit 1; }

python3 scripts/reyranella_read_mapping_report.py validate \
  --root . --manifest "${manifest}" --reference "${reference}" \
  --candidates "${candidates}" --stage "${stage}"

mkdir -p "${stage}/index" "${stage}/bam" "${stage}/metrics" "${stage}/reports" "${stage}/logs"
{
  printf 'reference\t%s\nmanifest\t%s\ncandidates\t%s\n' "${reference}" "${manifest}" "${candidates}"
  printf 'reference_sha256\t%s\n' "$(sha256sum "${reference}" | cut -d ' ' -f 1)"
  printf 'candidates_sha256\t%s\n' "$(sha256sum "${candidates}" | cut -d ' ' -f 1)"
  printf 'bowtie2_version\t%s\nsamtools_version\t%s\n' '2.5.3' '1.20'
  printf 'bowtie2_options\t--very-sensitive -p 8\n'
  printf 'samtools_sort_options\t-@ 4 -m 2G\n'
  printf 'coverage_options\t-q 20 -Q 20 --ff 0xF04\n'
  printf 'candidate_depth_options\t-a -s -q 20 -Q 20 -G 0x800; 5x threshold\n'
  printf 'candidate_read_classes\tMAPQ 0 ambiguous; MAPQ 1-19 intermediate; MAPQ >=20 unique-placement proxy\n'
  printf 'proper_pair_definition\tboth primary mapped mates on same contig with SAM 0x2; distinct QNAMEs\n'
} > "${stage}/metrics/parameters.tsv"

# Build one shared index from the full reference. The 41 IDs are only used
# after alignment, so competing noncandidate contigs remain in the reference.
bowtie2-build --threads 8 "${reference}" "${index}" > "${stage}/logs/bowtie2_build.log" 2>&1

while IFS=$'\t' read -r sample read1 read2; do
  [[ "${sample}" == 'sample_id' ]] && continue
  [[ -n "${sample}" ]] || continue
  gzip -t "${read1}" "${read2}"
  bam="${stage}/bam/${sample}.sorted.bam"
  tmp_bam="${bam}.tmp"
  bowtie2 --very-sensitive -p 8 --rg-id "${sample}" --rg "SM:${sample}" \
    -x "${index}" -1 "${read1}" -2 "${read2}" \
    2> "${stage}/logs/${sample}.bowtie2.log" \
    | samtools sort -@ 4 -m 2G -o "${tmp_bam}" -
  samtools quickcheck -v "${tmp_bam}"
  mv "${tmp_bam}" "${bam}"
  samtools index -@ 4 "${bam}"
  samtools flagstat -@ 4 "${bam}" > "${stage}/metrics/${sample}.flagstat.txt"
  samtools coverage -q 20 -Q 20 --ff 0xF04 "${bam}" \
    > "${stage}/metrics/${sample}.mapq20_baseq20.coverage.tsv"
done < "${manifest}"

python3 scripts/reyranella_read_mapping_report.py summarize \
  --root . --manifest "${manifest}" --reference "${reference}" \
  --candidates "${candidates}" --stage "${stage}"

echo "Read mapping and 41-contig report complete: ${stage}/reports/reyranella_candidate_read_support.tsv"
