# Work Completed

## 2026-05-01 ANI substage prepared for the 3 best completed subsampled assemblies

- Reviewed the top-level project markdown files again before editing so the ANI updates follow the saved workflow, documentation, stage-isolation, and Git-tracking rules already in force on `2026-05-01`.
- Audited the existing ANI assets under `ani/`, `configs/`, `scripts/`, and `reference/` before patching so the new work reuses the saved reference manifest and does not collide with the older six-sample ANI preparation.
- Reviewed `assembly_filtered_subsampled_isolate/metrics/assembly_summary.tsv` and selected one best subsampled assembly per strong `Vibrio vulnificus` candidate for the next ANI run: `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7_50x`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7_25x`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7_100x`.
- Added `configs/ani_query_manifest_subsampled_best_assemblies.tsv` so the 3 chosen ANI queries are saved explicitly as scaffold-level FASTA paths under `assembly_filtered_subsampled_isolate/assemblies/`.
- Added the new substage directory `ani/subsampled_best_assemblies/` with `README.md` and `metrics/fastani_parameters.txt` documenting why those 3 assemblies were selected, the exact scaffold source paths, the intended tracked reference set, the planned `fastANI` thresholds, and the expected outputs.
- Updated `scripts/fastani_array.slurm` so ANI runs can now be redirected into a new stage with `STAGE_DIR`, can swap query manifests with `QUERY_MANIFEST`, can pin the reference manifest with `REFERENCE_MANIFEST`, and can accept either `contigs.fasta` or `scaffolds.fasta` as the query assembly FASTA.
- Updated `scripts/summarize_fastani.py` so the summary and matrix generation now respect `STAGE_DIR`, `QUERY_MANIFEST`, and `REFERENCE_MANIFEST`, which allows the same summarizer to be reused for the new substage without overwriting any older ANI summary targets.
- Updated `ani/README.md`, `.gitignore`, `README.md`, `NEXT_STEPS.md`, and `IN_PROGRESS.md` so the new ANI substage is documented and its future raw outputs and logs stay out of Git while curated metrics remain trackable.
- Ran only non-compute validation in this turn: manifest path checks, Bash syntax checks, and Python syntax checks for the updated ANI workflow. No SLURM jobs were submitted and no new ANI outputs were generated yet.

## 2026-05-01 Kraken2-filtered subsampling and subsampled-SPAdes stages prepared

- Read the top-level project markdown files again before editing so the new stage follows the saved workflow, documentation, and repo-tracking rules already in force on `2026-05-01`.
- Calculated the fixed target read-pair counts for the new downsampling test assuming a `5.2 Mb` genome and `149 bp` paired-end reads: `436,242` pairs for `25x`, `872,483` pairs for `50x`, and `1,744,966` pairs for `100x`.
- Added `configs/kraken2_vibrio_subsample_manifest.tsv` to define all 9 planned sample-depth subsets from the completed `kraken2_vibrio_read_filtering/filtered_reads/` inputs, including saved seeds, output FASTQ paths, and per-run metrics paths.
- Added `scripts/subsample_paired_fastq.py` as a reusable Python subsampling workflow that validates paired gzipped FASTQ inputs, preserves R1/R2 synchronization by reading both files in lockstep, draws a seeded random subset of pair indexes, and records `sample_id`, `subsample_id`, target depth assumptions, target pair counts, actual pair counts, seeds, and input/output FASTQ paths.
- Added `scripts/summarize_subsampled_reads.py` plus `scripts/subsample_vibrio_reads_array.slurm` so the new subsampling stage can be submitted as a 9-task SLURM array and then summarized into `kraken2_vibrio_subsampled_reads/metrics/subsampling_summary.tsv` without mixing outputs into earlier stages.
- Added the new stage directory `kraken2_vibrio_subsampled_reads/` with `README.md` and `metrics/subsampling_parameters.txt` so the planned fixed-depth FASTQ outputs, recorded fields, and submission form are documented before job submission.
- Added `configs/assembly_manifest_vulnificus_candidates_filtered_subsampled.tsv` for the downstream `SPAdes --isolate` rerun across the 9 planned subsampled paired-read sets.
- Added the new stage directory `assembly_filtered_subsampled_isolate/` with `README.md` and `metrics/spades_parameters.txt` so the fixed-depth assembly rerun can be submitted reproducibly without overwriting `assembly/`, `assembly_isolate_rerun/`, or `assembly_filtered_isolate_rerun/`.
- Updated `README.md`, `.gitignore`, and the milestone notes so the new subsampling-preparation state is documented and the future subsampled FASTQ outputs, runtime logs, and assembly directories stay out of Git while curated metrics remain trackable.
- Ran only non-compute validation in this turn: Python syntax checks, Bash syntax checks, and dry-run/path validation against all 9 planned subsampling rows. No SLURM jobs were submitted and no new FASTQ outputs were generated yet.

## 2026-05-01 Filtered-read assembly comparison and next-step decision

- Audited the completed `assembly_filtered_isolate_rerun/` stage and confirmed that all 3 target samples now have finished SPAdes outputs plus a saved comparison table at `assembly_filtered_isolate_rerun/metrics/assembly_summary.tsv`.
- Confirmed that Kraken2-guided `Vibrio` filtering materially improved the focused `--isolate` rerun relative to the prior isolate-mode rerun, reducing scaffold totals from about `66.5 Mb`, `32.6 Mb`, and `19.0 Mb` to about `13.5 Mb`, `11.0 Mb`, and `10.1 Mb` for `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, respectively.
- Confirmed that the filtered rerun is still too inflated for clean isolate-scale downstream use, because all 3 assemblies remain roughly `2x` or more above an expected `5.2 Mb` `Vibrio vulnificus` genome even after the Kraken2-guided narrowing step.
- Rechecked that these 3 samples remain the strongest current `Vibrio vulnificus` set in the saved project evidence: Kraken2 top-species calls still favor `Vibrio vulnificus`, and the retained filtered-pair percentages remain high at `91.86%`, `98.40%`, and `98.76%`.
- Confirmed from the saved SPAdes logs that the filtered read sets are still extremely deep and likely coverage-skewed for assembly, with SPAdes estimating genome-scale coverages in the thousands for `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7` and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, while `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7` still shows unreliable k-mer model warnings.
- Calculated that the retained filtered read sets still represent roughly `9,300x` to `12,600x` depth assuming a `5.2 Mb` genome and approximately `149 bp` trimmed read length, which makes a controlled downsampling test biologically justified rather than a blind extra rerun.
- Chose the next recommended corrective step as a new stage-specific subsampling experiment on the filtered paired FASTQ inputs, targeting approximate depths of `25x`, `50x`, and `100x`, followed by `SPAdes --isolate` assemblies for each subsampled dataset before ANI, annotation, or gene-mining on these 3 samples.

## 2026-04-30 Assembly rerun audit while filtered-read SPAdes job is running

- Audited the saved project state against `PROJECT_BRIEF.md` and confirmed that the completed stages on disk are raw FastQC, FastQC extraction and interpretation, Trimmomatic trimming, post-trim FastQC interpretation, single-reference alignment review, multi-reference alignment review, Kraken2 broad classification, first-pass SPAdes assembly, the 3-sample isolate-mode rerun, and the new Kraken2-guided Vibrio read-filtering stage.
- Verified that the Kraken2 Vibrio filtering array had already completed successfully for the 3 strongest current `Vibrio vulnificus` candidates and that the summary job `1321574` completed cleanly on `2026-04-30`, writing `kraken2_vibrio_read_filtering/metrics/kraken2_vibrio_filtering_summary.tsv` with no stderr output.
- Confirmed that the filtered-read retention is high enough to justify the current SPAdes rerun: `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7` retained `219,765,787` of `239,251,931` read pairs (`91.86%`), `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7` retained `177,537,029` of `180,420,959` (`98.40%`), and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7` retained `163,105,516` of `165,150,467` (`98.76%`).
- Rechecked that these same 3 samples remain the best-supported `Vibrio vulnificus` set across the saved evidence: Kraken2 top-species calls are `Vibrio vulnificus` for all three, and the best multi-reference alignment fits are also to `v_vulnificus` at `87.51%`, `81.57%`, and `88.12%` mapped, respectively.
- Reconfirmed that the prior isolate-mode rerun did not sufficiently solve assembly inflation, with scaffold totals still at about `66.5 Mb` for `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `32.6 Mb` for `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `19.0 Mb` for `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, so a filtered-read rerun remains a justified corrective step.
- Verified that the current SLURM submission was the correct next move: job array `1321575_[0-2]` is actively running under `scripts/spades_assembly_array.slurm` with `MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered.tsv`, `STAGE_DIR=assembly_filtered_isolate_rerun`, and default `--isolate` mode.
- Confirmed from the live SPAdes logs under `assembly_filtered_isolate_rerun/logs/` and the sample assembly directories that all 3 tasks started cleanly, are reading the intended filtered FASTQ pairs, are writing to the intended stage-specific directory, and have progressed into SPAdes `K21` assembly without an immediate startup or input-validation failure.

## 2026-04-28 Kraken2-guided Vibrio read-filtering and filtered-read assembly stage prepared

- Confirmed that QC, trimming, single-reference alignment review, Kraken2 broad classification, first-pass SPAdes assembly, and the 3-sample isolate-mode SPAdes rerun are already completed in the saved project tree.
- Confirmed again that the strongest current `Vibrio vulnificus` candidates remain `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, based on the saved Kraken2 classification summary.
- Confirmed that the isolate-mode rerun still looks inflated, with scaffold totals of about `66.5 Mb`, `32.6 Mb`, and `19.0 Mb` respectively in `assembly_isolate_rerun/metrics/assembly_summary.tsv`, which remains far above an expected isolate-scale `Vibrio vulnificus` genome size.
- Added `configs/kraken2_vibrio_filter_manifest.tsv` for a focused 3-sample Kraken2-guided filtering stage and `configs/assembly_manifest_vulnificus_candidates_filtered.tsv` for the downstream filtered-read rerun.
- Added `scripts/filter_kraken2_vibrio_reads.py`, `scripts/summarize_kraken2_vibrio_filtering.py`, and `scripts/kraken2_vibrio_filter_array.slurm` to reproducibly retain only paired fragments classified by Kraken2 as `Vibrio` genus (`taxid 662`) or below while preserving read-pair synchronization and recording per-sample filtering metrics.
- Added the new stage directories `kraken2_vibrio_read_filtering/` and `assembly_filtered_isolate_rerun/` with README and parameter files so the filtered FASTQ generation and the filtered-read `--isolate` SPAdes rerun can be submitted without overwriting the original trimmed reads or either prior assembly stage.

## 2026-03-27 FastQC extraction and interpretation

- Extracted 12 FastQC zip reports into `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/fastqc_extracted`.
- Parsed every `summary.txt` and `fastqc_data.txt` file and wrote the interpreted report to `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/fastqc_review/fastqc_interpreted_report.md`.
- Confirmed project-wide high raw read quality with persistent tile-quality, duplication, and reverse-read PolyG/GC anomalies that should be addressed during trimming.

## 2026-03-28 Trimmomatic preparation milestone

- Added `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/prepare_trimmomatic_inputs.sh` to validate paired FASTQ inputs, create step directories, copy raw reads into a separate trimming workspace, and append prep actions to `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/logs/prepare_trimmomatic_inputs.log`.
- Ran the prep script successfully and generated `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/metrics/trimmomatic_input_manifest.tsv` covering all 6 paired-end samples.
- Added `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/trimmomatic_array.slurm` as a reusable SLURM array script that trims only the copied reads and writes per-task stdout/stderr logs into the new trimmomatic step directory.
- Confirmed local HPC prerequisites for the batch script: Java is available, `trimmomatic/0.39` is installed on the cluster, `TruSeq3-PE.fa` is present, and both scripts pass `bash -n` syntax checks.
## 2026-04-09 Post-trim FastQC extraction and interpretation

- Added `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/extract_fastqc_trimmed_reports.sh` and `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/analyze_fastqc_trimmed_reports.py` to reproducibly extract and interpret trimmed-read FastQC outputs.
- Extracted 12 trimmed FastQC zip reports into `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/fastqc_trimmed_extracted` and wrote the review outputs to `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/fastqc_trimmed_review`.
- Verified that trimming removed the raw reverse-read overrepresented-sequence failures and resolved the strongest GC-content anomaly, while forward-read tile-quality failures and duplication remained.

## 2026-04-10 BWA-MEM alignment preparation milestone

- Added `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/configs/alignment_manifest.tsv` listing all 6 trimmed read pairs with relative paths for array-based alignment.
- Added `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/bwa_align_array.slurm` as a reusable SLURM array script that validates paired trimmed reads, loads `bwa` and `samtools`, aligns against `reference/v_vulnificus_ref.fasta`, writes sorted BAM outputs under `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/alignment/bam`, and writes `flagstat` plus `idxstats` reports under `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/alignment/metrics`.
- Created the stage-specific alignment directories `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/alignment/bam`, `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/alignment/logs/slurm`, and `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/alignment/metrics`.
- Updated `.gitignore` so generated alignment BAMs and SLURM logs remain out of Git while alignment manifests, scripts, and the curated TSV summary can be tracked.

## 2026-04-12 Alignment metrics review and documentation update

- Verified that `scripts/summarize_alignment_metrics.sh` passes `bash -n`, runs successfully, and reproduces `alignment/metrics/alignment_summary.tsv` from the per-sample `flagstat` and `idxstats` files.
- Confirmed that `alignment/metrics/alignment_summary.tsv` is internally consistent: `idx_mapped_sum` matches the `flagstat` mapped count for all 6 samples, and each `idxstats` file reports the two expected reference contigs plus the `*` unmapped row.
- Confirmed that the saved alignment SLURM script needed one reproducibility fix: the reference path now matches the checked-in FASTA at `reference/v_vulnificus_ref.fasta`.
- Recorded the observed alignment-rate spread across samples: `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` at `1.05%`, `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` at `10.86%`, `Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` at `30.57%`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7` at `81.57%`, `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7` at `87.51%`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7` at `88.12%`.

## 2026-04-13 Multi-reference alignment preparation milestone

- Added `configs/multi_reference_reference_manifest.tsv` to track the 5 candidate references with relative FASTA paths, reference-format annotations, and notes about how to interpret draft versus closed genomes.
- Added `scripts/bwa_align_multiref_array.slurm` as a reusable SLURM array workflow that expands the saved 6-sample trimming manifest across all 5 references, validates paired reads plus BWA and samtools reference sidecars, and writes stage-specific outputs under `multi_reference_alignment/`.
- Added `scripts/summarize_multiref_alignment_metrics.py` to combine the per-combination `flagstat` and `idxstats` files into a long-form summary table and a mapped-percentage matrix for all 30 sample-reference combinations.
- Verified from the checked-in FASTA indexes that the two `Vibrio ostreicida` references are not a blocking format error for `bwa` or `samtools`, but they are draft multi-contig assemblies (`33` contigs for `v_ostreicida_PP203` and `81` contigs for `v_ostreicida_r172`) rather than two-chromosome closed references.
- Implemented the multi-contig workaround in the new scripts by validating each reference with its `.fai`, recording the reference format from the manifest, and aggregating `idxstats` across all contigs instead of assuming a fixed chromosome count.

## 2026-04-13 Multi-reference alignment review completed

- Confirmed that the full 30-task comparison run completed and produced the curated outputs `multi_reference_alignment/metrics/multi_reference_alignment_summary.tsv` and `multi_reference_alignment/metrics/multi_reference_alignment_mapped_pct_matrix.tsv`.
- Verified the strongest reference match for `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7` (`87.51%`), `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7` (`81.57%`), `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7` (`88.12%`), and `Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` (`30.57%`) remains the current `Vibrio vulnificus` reference.
- Verified that `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` aligns best to the `Vibrio alginolyticus` reference at `43.84%`, exceeding its `Vibrio parahaemolyticus` (`31.18%`) and `Vibrio vulnificus` (`10.86%`) mapping rates.
- Confirmed that `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` remains a low-alignment outlier against all five references, with mapped percentages clustered near `1%`.
- Preserved the per-combination BAMs, `flagstat`, and `idxstats` files under the dedicated `multi_reference_alignment/` stage while keeping only the curated TSV summaries intended for Git tracking.

## 2026-04-14 Kraken2 database preparation milestone

- Added `scripts/kraken2_build_bacterial_db.slurm` as a reusable SLURM script that uses Singularity rather than environment modules to build a bacteria-focused Kraken2 database in the new `kraken2_db/` stage.
- Added `kraken2_db/README.md` to document the intended container input, expected runtime outputs, conservative storage guardrails, and the assumption that a bacteria-only database is the most appropriate next taxonomic screen after the ambiguous multi-reference alignment results.
- Configured the new SLURM workflow to record build parameters plus before/after disk-usage snapshots under `kraken2_db/metadata/` and to abort early if project or temporary free space is below conservative thresholds.
- Updated `.gitignore` so the large Kraken2 database files and SLURM logs remain outside Git while the stage documentation and future small metadata records can remain trackable.
- Did not submit or run the Kraken2 build job.

## 2026-04-16 Kraken2 build troubleshooting and retry hardening

- Reviewed the two saved Kraken2 SLURM runs under `kraken2_db/logs/slurm` and confirmed that job `1319090` failed during taxonomy download because the containerized `rsync` path hit `Unknown module 'pub'`.
- Confirmed that job `1319091` successfully launched Singularity, downloaded taxonomy into `kraken2_db/db/taxonomy`, and then failed during the RefSeq bacteria library transfer because repeated FTP attempts for `GCF_022220625.1_ASM2222062v1_genomic.fna.gz` ended with `Connection closed`.
- Verified that the Kraken2 stage remains incomplete because `kraken2_db/db/hash.k2d`, `kraken2_db/db/opts.k2d`, and `kraken2_db/db/taxo.k2d` are still absent.
- Updated `scripts/kraken2_build_bacterial_db.slurm` so the bacteria-library download step now retries transient failures with configurable `KRAKEN2_DOWNLOAD_MAX_ATTEMPTS` and `KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC` settings, clearer retry logging, and explicit checks for `library/bacteria/assembly_summary.txt` plus `manifest.txt` before the build step.
- Updated `kraken2_db/README.md` and `NEXT_STEPS.md` so the failed job history, FTP recommendation, and resubmission guidance are documented for the next cluster submission.

## 2026-04-17 Kraken2 database build verification completed

- Reviewed all three Kraken2 build jobs under `kraken2_db/logs/slurm` and confirmed that job `1319269` is the first successful end-to-end run, finishing on `2026-04-17 09:50:55 CDT`.
- Verified that the expected final database files now exist at `kraken2_db/db/hash.k2d`, `kraken2_db/db/opts.k2d`, and `kraken2_db/db/taxo.k2d`, with `hash.k2d` occupying about `93G`.
- Confirmed from `kraken2_db/metadata/disk_usage_after_job_1319269.tsv` that the cleaned database footprint is about `100G`, consistent with the completed build log.
- Recorded a stage-specific interpretation in `kraken2_db/metadata/kraken2_build_verification_2026-04-17.md` documenting that the database build succeeded and is usable, but the successful run still logged one transient FTP fetch failure and two gzip-corrupt downloaded genomes during library processing.
- Concluded that the Kraken2 stage is complete enough for downstream classification, while noting that the RefSeq bacteria snapshot used for this build may be missing a very small number of source genomes because the successful run was not perfectly clean at the individual-download level.

## 2026-04-17 Kraken2 sample-classification stage prepared

- Added `configs/kraken2_classification_manifest.tsv` so the Kraken2 stage has its own saved manifest of the 6 paired trimmed read sets, using relative paths under `trimmomatic/trimmed_reads/`.
- Added `scripts/kraken2_classify_array.slurm` as a reusable SLURM workflow that classifies one saved sample pair per array task against `kraken2_db/db/`, writes one Kraken2 output file plus one Kraken2 report per sample under `kraken2_classification/`, and supports a `summary` mode for post-run aggregation.
- Added `scripts/summarize_kraken2_classification.py` to parse the saved Kraken2 reports, rank species-level hits before genus-level hits, and write the curated summary table `kraken2_classification/metrics/kraken2_classification_summary.tsv`.
- Added `kraken2_classification/README.md` to document that Kraken2 uses paired trimmed FASTQ inputs rather than FastQC artifacts, to describe expected stage outputs, and to record the interpretation labels `strong species fit`, `genus-level only fit`, `mixed/ambiguous`, and `mostly unclassified`.
- Updated `.gitignore` so per-sample Kraken2 outputs, reports, and SLURM logs stay outside Git while the curated TSV summary can remain trackable.

## 2026-04-17 Kraken2 sample-classification summary completed

- Verified from `kraken2_classification/logs/slurm/kraken2_classify_1319693_*.out` and matching `.err` files that the 6-sample Kraken2 array job completed and wrote one output plus one report for each trimmed paired sample.
- Identified why the original summary submission `1319701` failed: the parser compared the Kraken2 output line count to the report `root` row, but the `root` row records only classified reads, not total reads including the `unclassified` row.
- Corrected `scripts/summarize_kraken2_classification.py` so the summary step now derives total reads from the saved report counts and only uses the Kraken2 output files as non-empty existence checks.
- Regenerated `kraken2_classification/metrics/kraken2_classification_summary.tsv` successfully from the saved reports.
- Confirmed the current taxonomic split across the 6 samples: 3 strong `Vibrio vulnificus` fits (`Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`), 1 strong non-`vulnificus Vibrio` fit (`Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` as `Vibrio cidicii`), 1 genus-level `Vibrio` but species-ambiguous sample (`Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7`), and 1 likely non-`Vibrio` outlier (`Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` with a dominant `Bacillus` genus signal).

## 2026-04-18 SPAdes assembly preparation milestone

- Added `configs/assembly_manifest.tsv` listing all 6 trimmed read pairs with relative paths for the assembly stage.
- Added `scripts/spades_assembly_array.slurm` as a reusable SLURM array script that validates paired trimmed reads, writes one sample-specific assembly directory under `assembly/assemblies/`, records per-task logs under `assembly/logs/`, and supports a `summary` mode for post-run metric collation.
- Added `scripts/summarize_spades_assemblies.py` to compute contig and scaffold counts, total assembled bases, N50, longest sequence, GC percentage, and the number of sequences at least `1000 bp`, then write the curated table `assembly/metrics/assembly_summary.tsv`.
- Added `assembly/README.md` plus `assembly/metrics/spades_parameters.txt` so the assembly stage has documented inputs, outputs, resource defaults, and completion checks before submission.
- Updated `.gitignore` so bulky assembly outputs and runtime logs remain outside Git while the parameter record and curated summary TSV can stay trackable.

## 2026-04-18 ANI preparation milestone

- Added `configs/ani_query_manifest.tsv` so ANI queries come from `assembly/assemblies/<sample_id>/contigs.fasta` in a saved manifest-driven format.
- Added `configs/ani_reference_manifest.tsv` so ANI comparisons use the same tracked reference genomes already used by the alignment stages.
- Added `scripts/fastani_array.slurm` as a reusable SLURM array script that validates assembled query FASTA files, resolves the reference manifest automatically, writes one raw fastANI output file per sample under `ani/outputs/`, and supports a `summary` mode for post-run collation.
- Added `scripts/summarize_fastani.py` to combine the raw fastANI outputs into a long-form summary table plus a sample-by-reference ANI matrix, with threshold-based interpretation labels for likely `Vibrio vulnificus`, likely other species, or outlier status.
- Added `ani/README.md` plus `ani/metrics/fastani_parameters.txt` so the ANI stage has documented dependencies, inputs, outputs, interpretation thresholds, and completion checks before submission.
- Updated `.gitignore` so bulky ANI outputs and runtime logs remain outside Git while the parameter record and curated ANI TSV summaries can stay trackable.

## 2026-04-20 Assembly interpretation review and isolate-rerun preparation

- Reviewed the completed SPAdes outputs under `assembly/assemblies/` together with `kraken2_classification/metrics/kraken2_classification_summary.tsv`, `alignment/metrics/alignment_summary.tsv`, and `multi_reference_alignment/metrics/multi_reference_alignment_summary.tsv`.
- Confirmed that the original 6-sample assembly run completed only after three failed SPAdes-resolution attempts and one successful container-backed submission (`1319742`), then regenerated the missing curated file `assembly/metrics/assembly_summary.tsv` from the saved assembly outputs.
- Interpreted the first-pass assembly metrics as poor for isolate-scale downstream use: all 6 assemblies are highly fragmented and inflated in total size, with scaffold totals from about `18.7 Mb` to `65.2 Mb`, indicating that the current outputs should not be treated as strong finished genomes.
- Confirmed that `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` is the strongest non-target or contamination candidate because Kraken2 is dominated by `Bacillus` and all tested Vibrio references map at only about `1%`.
- Confirmed that `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` remains a mixed or unresolved `Vibrio` sample because Kraken2 species calls are split and the best tested reference fit is `Vibrio alginolyticus` rather than `Vibrio vulnificus`.
- Confirmed that the best current `Vibrio vulnificus` candidates remain `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, because they have strong Kraken2 `Vibrio vulnificus` calls and strong `Vibrio vulnificus` alignment rates even though their first-pass assemblies still look poor.
- Updated `scripts/spades_assembly_array.slurm` so the workflow now supports `MANIFEST_FILE` and `STAGE_DIR` overrides, logs the chosen stage and extra arguments, defaults to `--isolate` for bacterial isolate reruns unless explicitly overridden, and uses `bash -c` rather than `bash -lc` inside the containerized execution path to reduce shell-init noise in SLURM logs.
- Added `configs/assembly_manifest_vulnificus_candidates.tsv` to define a focused 3-sample rerun set for the strongest current `Vibrio vulnificus` candidates.
- Added the new comparison stage `assembly_isolate_rerun/` with `README.md` and `metrics/spades_parameters.txt` so the isolate-oriented rerun can be submitted reproducibly without overwriting the original `assembly/` outputs.
