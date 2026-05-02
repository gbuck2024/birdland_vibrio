# In Progress

## 2026-05-01 Best-subsampled ANI setup

- The next active downstream step is now ANI for the 3 selected best completed subsampled assemblies rather than another assembly-preparation task.
- The planned representative set is `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7_50x`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7_25x`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7_100x`, based on the saved scaffold totals, scaffold counts, and scaffold `N50` values in `assembly_filtered_subsampled_isolate/metrics/assembly_summary.tsv`.
- The ANI workflow is now prepared to run as a separate substage at `ani/subsampled_best_assemblies/` using `configs/ani_query_manifest_subsampled_best_assemblies.tsv` and the tracked reference manifest at `configs/ani_reference_manifest.tsv`.
- Current technical caveat is dependency-specific rather than workflow-specific: the cluster submission will still require `fastANI` to be available through `FASTANI_BIN`, `PATH`, or an environment module.

## 2026-05-01 Filtered-read assembly follow-up

- The Kraken2-guided filtered-read `SPAdes --isolate` rerun is now complete for the 3 strongest current `Vibrio vulnificus` candidates, and the current comparison table is saved at `assembly_filtered_isolate_rerun/metrics/assembly_summary.tsv`.
- Current technical caveat is that the filtered rerun improved assembly size substantially but did not reach isolate scale: scaffold totals remain about `13.5 Mb`, `11.0 Mb`, and `10.1 Mb`, which is still too inflated for clean downstream interpretation as a `5.2 Mb` genome.
- Saved SPAdes evidence suggests that excessive depth is still a major confounder, because the filtered read sets remain extremely deep and two of the three assemblies still show genome-scale coverage estimates in the thousands.
- Next active pipeline step is to prepare a new stage-specific subsampling workflow on the filtered paired FASTQ files for `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`.
- The intended subsampling test should target approximate coverages of `25x`, `50x`, and `100x` assuming a `5.2 Mb` genome, followed by separate `SPAdes --isolate` assemblies for each depth before ANI, annotation, or gene mining on these 3 samples.

## 2026-04-17 Project status snapshot

- Workflow checkpoints completed through Step 7 review are now in place for all 6 samples: raw QC, FastQC extraction, QC interpretation, trimming, post-trim QC, single-reference alignment review, multi-reference alignment review, Kraken2 database build, and Kraken2 classification summary.
- The summary step is now complete at `kraken2_classification/metrics/kraken2_classification_summary.tsv`; the original SLURM summary job failed because the parser incorrectly treated the Kraken2 `root` row as total reads rather than classified reads only.
- Three samples currently have strong `Vibrio vulnificus` support across both alignment and Kraken2 review: `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`.
- Two samples remain biologically ambiguous for different reasons: `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` is clearly `Vibrio` but not a clean species-level fit, while `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` now shows a dominant `Bacillus` genus signal instead of `Vibrio`.
- Next active pipeline step is SPAdes assembly preparation and submission planning, with downstream annotation and gene mining used to test whether the Kraken2 and alignment-based species interpretations hold at the assembled-genome level.

## 2026-04-18 SPAdes assembly preparation

- Added `configs/assembly_manifest.tsv` so the assembly stage now has a saved manifest of all 6 paired trimmed read sets using relative paths under `trimmomatic/trimmed_reads/`.
- Added `scripts/spades_assembly_array.slurm` as a reusable SLURM workflow that validates paired trimmed reads, writes one SPAdes output directory per sample under `assembly/assemblies/`, records per-sample stage logs, and supports a `summary` mode for post-run metric collation.
- Added `scripts/summarize_spades_assemblies.py` to parse `contigs.fasta` and `scaffolds.fasta` after the array run and write the curated table `assembly/metrics/assembly_summary.tsv`.
- Added `assembly/README.md` and `assembly/metrics/spades_parameters.txt` so the assembly stage has documented inputs, expected outputs, resource defaults, and submission commands before any heavy job is submitted.
- Current technical caveat is environment-specific rather than workflow-specific: the script will use `SPADES_BIN` if set and otherwise tries to load a module named `spades`, so the exact cluster SPAdes command should be verified at submission time if the local module name differs.
- Next active step is cluster submission of the SPAdes array, followed by the saved summary mode and then assembly-quality review before annotation.

## 2026-04-18 ANI stage preparation

- Added `configs/ani_query_manifest.tsv` so ANI queries come from `assembly/assemblies/<sample_id>/contigs.fasta` in a saved manifest-driven format consistent with the other stages.
- Added `configs/ani_reference_manifest.tsv` for ANI comparisons against the same saved reference genomes already used in the alignment stages.
- Added `scripts/fastani_array.slurm` as a reusable SLURM workflow that compares one assembled sample per task against the reference set with `fastANI`, writes one raw output file per sample under `ani/outputs/`, and supports a `summary` mode for post-run collation.
- Added `scripts/summarize_fastani.py` to combine the raw fastANI outputs into `ani/metrics/ani_summary.tsv` and `ani/metrics/ani_matrix.tsv`, including per-sample best-reference calls and threshold-based interpretation labels.
- Added `ani/README.md` and `ani/metrics/fastani_parameters.txt` so the ANI stage has documented dependencies, inputs, outputs, interpretation thresholds, and submission commands.
- Current technical caveat is dependency-specific: the ANI workflow prefers `fastANI` and will fail with a clear error if `fastANI` is not available through `FASTANI_BIN`, `PATH`, or an environment module.
- Next active step is still assembly submission first, then ANI submission after `assembly/assemblies/<sample_id>/contigs.fasta` exists for each sample.

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
