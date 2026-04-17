# In Progress

## 2026-04-17 Project status snapshot

- Workflow checkpoints completed through Step 7 review are now in place for all 6 samples: raw QC, FastQC extraction, QC interpretation, trimming, post-trim QC, single-reference alignment review, multi-reference alignment review, Kraken2 database build, and Kraken2 classification summary.
- The summary step is now complete at `kraken2_classification/metrics/kraken2_classification_summary.tsv`; the original SLURM summary job failed because the parser incorrectly treated the Kraken2 `root` row as total reads rather than classified reads only.
- Three samples currently have strong `Vibrio vulnificus` support across both alignment and Kraken2 review: `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`.
- Two samples remain biologically ambiguous for different reasons: `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` is clearly `Vibrio` but not a clean species-level fit, while `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` now shows a dominant `Bacillus` genus signal instead of `Vibrio`.
- Next active pipeline step is SPAdes assembly preparation and submission planning, with downstream annotation and gene mining used to test whether the Kraken2 and alignment-based species interpretations hold at the assembled-genome level.

## 2026-03-27 FastQC extraction and interpretation

- FastQC review is complete and the project is ready to enter the read-trimming stage.
- Main open technical question for trimming is whether standard Trimmomatic settings will adequately reduce reverse-read PolyG artifacts.
- Next verification point should be post-trim FastQC on all paired samples.

## 2026-03-28 Trimmomatic preparation

- Created a non-destructive trimming workspace at `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic` with `copied_reads`, `logs`, and `metrics`.
- Copied and byte-validated all 6 paired FASTQ datasets from `fq_raw/` into `trimmomatic/copied_reads/`; raw reads remain unchanged.
- Prepared the SLURM array script and manifest for a `0-5` array submission; next active step is job submission plus a 1-2 minute early-failure check in the SLURM logs.
- Remaining technical caveat: Trimmomatic quality trimming can reduce low-quality PolyG-heavy tails, but post-trim FastQC is still required to confirm whether the reverse-read artifact is sufficiently improved.
## 2026-04-09 Post-trim FastQC extraction and interpretation

- Post-trim FastQC interpretation is complete and the quality-control checkpoint for trimmed paired reads has been verified.
- Remaining technical caveat is the persistent forward-read per-tile FastQC failure, which appears to be a lane artifact rather than a trimming deficiency.
- Next active pipeline step is assembly planning and submission on the trimmed paired reads.

## 2026-04-12 Alignment review

- Alignment against the current `Vibrio vulnificus` reference is complete for all 6 trimmed paired samples, and `alignment/metrics/alignment_summary.tsv` has been regenerated from the saved per-sample metrics.
- Current technical caveat is that reference suitability appears uneven across isolates because mapped-read percentages range from `1.05%` to `88.12%`.
- Next active step is assembly workflow submission, with optional follow-up review of sample identity or contamination for the lowest-alignment isolates before any reference-based downstream analysis.

## 2026-04-13 Multi-reference alignment review

- The multi-reference comparison is complete and the saved summaries now show sample-specific reference preferences instead of a single project-wide best fit.
- Current technical caveat is that `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` aligns best to `Vibrio alginolyticus`, while `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` remains near-background against every tested reference.
- The two `Vibrio ostreicida` references still need cautious interpretation because they are draft multi-contig assemblies, but they do not outperform the best closed-reference matches for any sample.
- Next active pipeline step is assembly-stage preparation and documentation for all six trimmed paired samples, with later annotation and gene mining used to clarify species identity and virulence content.

## 2026-04-17 Kraken2 database verification

- The bacteria-focused Kraken2 database build is now complete and the saved final database files are present under `kraken2_db/db/`.
- Current technical caveat is that the successful build log still contains one transient FTP download failure and two gzip-corrupt downloaded genomes, so the database is usable but may be missing a very small number of RefSeq bacterial entries from that snapshot.
- Next active step is to use the completed database for taxonomic classification of the ambiguous isolates while continuing assembly-stage preparation in parallel.

## 2026-04-17 Kraken2 sample classification summary

- The Kraken2 sample-classification stage has now completed end-to-end: per-sample outputs and reports are present under `kraken2_classification/`, and the curated summary table is present at `kraken2_classification/metrics/kraken2_classification_summary.tsv`.
- Current technical caveat is biological rather than computational: Kraken2 strongly supports `Vibrio vulnificus` for 3 samples, points `Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` toward `Vibrio cidicii`, leaves `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` genus-level `Vibrio` but species-ambiguous, and shifts `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` toward `Bacillus`.
- Next active step is assembly-stage preparation for all 6 trimmed paired samples, with special attention to whether the ambiguous or non-`vulnificus` classifications remain consistent after assembly and annotation.
