#!/bin/bash
# Compare equal read-pair counts against the complete old downsampled assembly.
# Submit from the project root; all generated data stay in this separate stage.
#SBATCH -J reyranella_depth_map
#SBATCH -p normal
#SBATCH -t 36:00:00
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 8
#SBATCH --mem=32G
#SBATCH -o comparison_nb0507_14_resequencing/reyranella_validation/read_mapping_depth_matched/logs/map_%j.out
#SBATCH -e comparison_nb0507_14_resequencing/reyranella_validation/read_mapping_depth_matched/logs/map_%j.err

set -euo pipefail

# SLURM spools the script, so locate the project through the submission path.
if [[ -z "${SLURM_SUBMIT_DIR:-}" ]]; then
  echo 'SLURM_SUBMIT_DIR is unset; submit from the project root.' >&2
  exit 1
fi
cd "${SLURM_SUBMIT_DIR}"
if [[ ! -f PROJECT_BRIEF.md || ! -f scripts/reyranella_read_mapping_report.py ]]; then
  echo "Not the project root: ${SLURM_SUBMIT_DIR}" >&2
  exit 1
fi

stage="comparison_nb0507_14_resequencing/reyranella_validation/read_mapping_depth_matched"
manifest="comparison_nb0507_14_resequencing/manifests/reyranella_read_mapping_depth_matched.tsv"
reference="comparison_nb0507_14_resequencing/downsampled_old_assembly/assemblies/Buck_NB0507_14_downsampled_to_SRR37852095_L7/contigs.fasta"
candidates="comparison_nb0507_14_resequencing/reyranella_validation/reyranella_1kb_ids.txt"
index="${stage}/index/full_downsampled_old_contigs"
expected_pairs=914516
reference_sha256="08d26c889f01226f068f3d0882f91716248e2629a25f9575ceae2e5c6eddae6e"
candidates_sha256="10810a094313b52958c0904ae74f684b4bab5177b53df204b53628a59c487984"

# Do not silently replace any prior index, mapping metric, or report. SLURM
# creates its own map_%j log before this code runs, so those logs are exempt.
for directory in index bam metrics reports; do
  if [[ -d "${stage}/${directory}" ]] && [[ -n "$(find "${stage}/${directory}" -mindepth 1 -print -quit)" ]]; then
    echo "Refusing to overwrite existing ${stage}/${directory} outputs" >&2
    exit 1
  fi
done
if [[ -d "${stage}/logs" ]] && [[ -n "$(find "${stage}/logs" -type f ! -name 'map_*.out' ! -name 'map_*.err' -print -quit)" ]]; then
  echo "Refusing to overwrite existing ${stage}/logs tool logs" >&2
  exit 1
fi
if ! mkdir "${stage}/.run_lock"; then
  echo "Another run or an unresolved prior run owns ${stage}/.run_lock" >&2
  exit 1
fi
trap 'rmdir "${stage}/.run_lock"' EXIT

module load bowtie2/2.5.3 samtools/1.20
[[ "$(bowtie2 --version | sed -n '1s/.*version //p')" == "2.5.3" ]] || { echo 'Bowtie2 version mismatch' >&2; exit 1; }
[[ "$(samtools --version | sed -n '1s/samtools //p')" == "1.20" ]] || { echo 'samtools version mismatch' >&2; exit 1; }

# This reads all four FASTQs to EOF: gzip CRC, FASTQ structure, R1/R2 order,
# and exact pair counts are checked before any index or BAM is made.
python3 scripts/validate_reyranella_mapping_pairs.py \
  --root . --manifest "${manifest}" --reference "${reference}" \
  --candidates "${candidates}" --expected-pairs "${expected_pairs}" \
  --expected-contigs 13807 --expected-reference-sha256 "${reference_sha256}" \
  --expected-candidates-sha256 "${candidates_sha256}" \
  --output "${stage}/metrics/input_audit.tsv"

mkdir -p "${stage}/index" "${stage}/bam" "${stage}/reports" "${stage}/logs"
{
  printf 'reference\t%s\nmanifest\t%s\ncandidates\t%s\n' "${reference}" "${manifest}" "${candidates}"
  printf 'reference_contigs\t13807\ncandidate_ids\t41\nexpected_read_pairs_per_sample\t%s\n' "${expected_pairs}"
  printf 'reference_sha256\t%s\n' "$(sha256sum "${reference}" | cut -d ' ' -f 1)"
  printf 'manifest_sha256\t%s\n' "$(sha256sum "${manifest}" | cut -d ' ' -f 1)"
  printf 'candidates_sha256\t%s\n' "$(sha256sum "${candidates}" | cut -d ' ' -f 1)"
  printf 'bowtie2_version\t2.5.3\nsamtools_version\t1.20\n'
  printf 'bowtie2_options\t--very-sensitive -p 8\n'
  printf 'samtools_sort_options\t-@ 4 -m 2G\n'
  printf 'coverage_options\t-q 20 -Q 20 --ff 0xF04\n'
  printf 'candidate_depth_options\t-a -s -q 20 -Q 20 -G 0x800; 5x threshold\n'
  printf 'candidate_read_classes\tMAPQ 0 ambiguous; MAPQ 1-19 intermediate; MAPQ >=20 unique-placement proxy\n'
  printf 'proper_pair_definition\tboth primary mapped mates on same contig with SAM 0x2; distinct QNAMEs\n'
} > "${stage}/metrics/parameters.tsv"

# Index all 13,807 contigs; only restrict to 41 IDs during reporting.
bowtie2-build --threads 8 "${reference}" "${index}" > "${stage}/logs/bowtie2_build.log" 2>&1
while IFS=$'\t' read -r sample read1 read2; do
  [[ "${sample}" == 'sample_id' ]] && continue
  [[ -n "${sample}" ]] || continue
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
echo "Depth-matched mapping complete: ${stage}/reports/reyranella_candidate_read_support.tsv"
