# Work Completed

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
