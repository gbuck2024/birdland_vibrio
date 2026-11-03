# Depth-matched Reyranella candidate mapping

This stage compares the downsampled old NB0507-14 trimmed read pair with the
new `SRR37852095_L7` trimmed pair. Each input is expected to contain **914,516
read pairs**. Matching pair counts does not match sequenced bases because read
lengths differ. These are two sequencing runs of a matched isolate, not
biological replicates. The old reads contributed to the reference assembly;
the new reads provide an independent resequencing check.

Job `1558466` used the **full** old trimmed pair and completed in the separate
`../read_mapping/` stage. Its index, BAMs, metrics, reports, and logs must stay
there. This stage ran as job `1559028` and completed (`COMPLETED`, exit `0:0`).
Both BAMs passed `samtools quickcheck`; each full-reference coverage table has
13,807 rows, the candidate report has 41 rows, and the class summary has two.

## Inputs and submission

- Manifest: `../../manifests/reyranella_read_mapping_depth_matched.tsv`.
- Complete old downsampled assembly: `../../downsampled_old_assembly/assemblies/Buck_NB0507_14_downsampled_to_SRR37852095_L7/contigs.fasta` (13,807 contigs).
- Candidate IDs: `../reyranella_1kb_ids.txt` (41 unique IDs). All contigs are
  retained for alignment; the candidate list only selects reporting targets.
- Bowtie2 2.5.3, samtools 1.20, and Python 3 are required on the cluster.

From the project root, run the lightweight manifest/reference check, then
submit. The `logs/` directory must exist before `sbatch` opens its log files:

```bash
python3 scripts/reyranella_read_mapping_report.py validate \
  --root . \
  --manifest comparison_nb0507_14_resequencing/manifests/reyranella_read_mapping_depth_matched.tsv \
  --reference comparison_nb0507_14_resequencing/downsampled_old_assembly/assemblies/Buck_NB0507_14_downsampled_to_SRR37852095_L7/contigs.fasta \
  --candidates comparison_nb0507_14_resequencing/reyranella_validation/reyranella_1kb_ids.txt \
  --stage comparison_nb0507_14_resequencing/reyranella_validation/read_mapping_depth_matched
mkdir -p comparison_nb0507_14_resequencing/reyranella_validation/read_mapping_depth_matched/logs
sbatch scripts/reyranella_read_mapping_depth_matched.slurm
```

The SLURM job reads every FASTQ to EOF before mapping. Its input audit checks
gzip integrity, FASTQ structure, synchronized R1/R2 IDs, and exactly 914,516
pairs for each manifest row. It checks for 13,807 unique reference contigs and
41 unique candidate IDs, then records the resolved read paths, pair counts,
and compressed-file SHA-256 checksums in `metrics/input_audit.tsv`. The job
refuses to start if index, BAM, metrics, report, or tool-log outputs already
exist, and uses a stage-local run lock to prevent overlapping attempts. If a
job fails, inspect its logs and partial outputs before preparing any retry;
do not overwrite them.

## Methods and expected outputs

The job builds an index from the full reference, maps each pair with Bowtie2
`--very-sensitive -p 8`, coordinate sorts with samtools `-@ 4 -m 2G`, and
indexes both BAMs. `samtools coverage -q 20 -Q 20 --ff 0xF04` produces a
full-reference table per sample. Candidate breadth at ≥5× uses `samtools
depth -a -s -q 20 -Q 20 -G 0x800`, avoiding double counting overlapping
mates. Primary mapped candidate reads are classified as MAPQ 0 ambiguous,
MAPQ 1–19 intermediate, or MAPQ ≥20 high-confidence placement proxy. Proper
pairs are distinct read names with two primary mapped mates on the same
candidate contig and SAM flag `0x2`; the stricter count also requires MAPQ
≥20 on both mates. `metrics/parameters.tsv` records paths, checksums,
versions, and options. The reporting calculations use
`scripts/reyranella_read_mapping_report.py`, the same script as job `1558466`.

Job `1559028` produced the following outputs. Confirm them again after any
future rerun in a new stage:

- Six Bowtie2 index files under `index/` and two valid BAM/BAI pairs under
  `bam/`, with sample IDs from the new manifest.
- Two nonempty `metrics/<sample>.flagstat.txt` files and two
  `metrics/<sample>.mapq20_baseq20.coverage.tsv` files, each covering all
  13,807 reference contigs.
- `metrics/input_audit.tsv`, `metrics/parameters.tsv`, and
  `metrics/candidate_regions.bed`.
- `reports/reyranella_candidate_read_support.tsv` with 41 candidate rows and
  `reports/reyranella_mapping_class_summary.tsv` with two sample rows.
- SLURM, index-build, and sample-specific Bowtie2 logs under `logs/`.

The report script checks required files and all reference IDs before writing
reports. Interpret the comparison only after the SLURM job and these checks
pass. Pair-count equality alone does not imply equal base yield or equivalent
mapping opportunity.
