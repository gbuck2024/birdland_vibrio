# Reyranella candidate read mapping

This stage maps two paired-end sequencing runs of NB0507-14 to the **complete**
old downsampled SPAdes `contigs.fasta` (13,807 contigs). The 41 IDs in
`../reyranella_1kb_ids.txt` are selected only when making the final report.
The old Buck reads contributed to the reference assembly; SRR37852095_L7 is
the independent resequencing check. These are matched-isolate sequencing runs,
not biological replicates. The full old trimmed read pair is used, so raw read
counts and depth are not directly comparable across runs with different yields.
Compare breadth and depth together, and treat sparse or low-quality mappings
cautiously.

## Inputs and software

- `../../manifests/reyranella_read_mapping.tsv` lists the two R1/R2 trimmed
  read pairs and their sample IDs.
- Full reference:
  `../../downsampled_old_assembly/assemblies/Buck_NB0507_14_downsampled_to_SRR37852095_L7/contigs.fasta`.
- Candidate IDs: `../reyranella_1kb_ids.txt`.
- Bowtie2 2.5.3 and samtools 1.20 loaded through cluster modules; Python 3
  standard library for validation/reporting.

## Submit

From the project root, first run the lightweight input check and create the
SLURM log directory (SLURM opens log files before the job starts). The job
uses `SLURM_SUBMIT_DIR` as the project root and exits if submitted from a
different directory:

```bash
python3 scripts/reyranella_read_mapping_report.py validate \
  --root . \
  --manifest comparison_nb0507_14_resequencing/manifests/reyranella_read_mapping.tsv \
  --reference comparison_nb0507_14_resequencing/downsampled_old_assembly/assemblies/Buck_NB0507_14_downsampled_to_SRR37852095_L7/contigs.fasta \
  --candidates comparison_nb0507_14_resequencing/reyranella_validation/reyranella_1kb_ids.txt \
  --stage comparison_nb0507_14_resequencing/reyranella_validation/read_mapping
mkdir -p comparison_nb0507_14_resequencing/reyranella_validation/read_mapping/logs
sbatch scripts/reyranella_read_mapping.slurm
```

The job checks gzip integrity of both pairs, builds one Bowtie2 index of the
full reference, then maps each pair with `--very-sensitive -p 8`. It coordinate
sorts and indexes both BAMs. `samtools coverage` uses minimum mapping quality
20, minimum base quality 20, and excludes unmapped, secondary, QC-failed,
duplicate, and supplementary records (`--ff 0xF04`). Coverage percentage is
the proportion of each full contig covered by at least one qualifying base.
`numreads` counts alignments, not read pairs. Bowtie2's full alignment summary
is in each sample's `.bowtie2.log` file.

For each candidate, `samtools depth -a -s -q 20 -Q 20 -G 0x800` computes
`bases_ge5` and `breadth_ge5_pct` using bases of quality at least 20 from
alignments of MAPQ at least 20. `-s` counts overlapping mates only once at a
position. `proper_pairs` counts distinct templates whose two primary mapped
mates occur on the same candidate contig and carry the SAM proper-pair flag
(`0x2`); `proper_pairs_both_mapq_ge20` also requires both mates to have MAPQ
at least 20. Secondary, supplementary, duplicate, and QC-failed alignments
are excluded from read and pair counts.

Mapped primary reads on the 41 candidates are divided into three classes:
`unique_proxy_mapq_ge20_reads`, `ambiguous_mapq0_reads`, and
`intermediate_mapq1_19_reads`. The report provides both counts and percentages
of mapped candidate reads for the first two classes. MAPQ is an aligner
confidence score: MAPQ at least 20 is a *high-confidence unique-placement
proxy*, not proof that no other alignment exists. MAPQ 0 indicates ambiguous
placement. Bases and alignments use different quality filters, so the MAPQ
class counts need not equal the `samtools coverage` `numreads` value.

## Outputs and verification

- `index/`: shared full-assembly Bowtie2 index.
- `bam/<sample>.sorted.bam` and `.bai`: complete-reference alignments.
- `metrics/<sample>.flagstat.txt` and
  `<sample>.mapq20_baseq20.coverage.tsv`: per-run mapping and full-assembly
  coverage metrics.
- `metrics/parameters.tsv`: exact paths, software versions, options, and
  reference/candidate SHA-256 checksums.
- `reports/reyranella_candidate_read_support.tsv`: one row for each of the 41
  contigs, with length and both samples' read count, covered bases, breadth,
  mean depth, mean base quality, mean mapping quality, >=5x breadth, proper-pair
  counts, and MAPQ class counts and percentages.
- `reports/reyranella_mapping_class_summary.tsv`: two-row comparison of read
  mapping classes and proper-pair support summed across the 41 candidates.
- `metrics/candidate_regions.bed`: regenerated candidate intervals used to
  query the full-reference BAMs.
- `logs/`: SLURM, Bowtie2, and index-build logs.

The job runs `samtools quickcheck` on each BAM and checks the BAM, index,
flagstat, coverage table, all 13,807 reference IDs, and all 41 candidate IDs
before writing the report. Job `1558410` failed before mapping because it
tried to locate the report script in SLURM's spool directory; the root lookup
was corrected. Job `1558466` subsequently completed (`COMPLETED`, exit
`0:0`) and produced this stage's full-old-read outputs. Keep these results in
place. A separate equal-pair-count comparison is prepared under
`../read_mapping_depth_matched/` and has not been submitted.
