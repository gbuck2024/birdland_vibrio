# Vibrio WGS Detailed Workflow

## Project overview

- This repository documents a reproducible whole-genome sequencing workflow for 6 paired-end bacterial isolate datasets stored under `fq_raw/`.
- The original project brief targets `Vibrio vulnificus`, but the audited repository now clearly contains a broader decision workflow for mixed or ambiguous `Vibrio` and non-`Vibrio` candidates.
- The pipeline is organized so each major stage writes to its own directory, raw data remain unchanged, and reusable scripts plus curated summaries are tracked in Git.
- Compute-heavy steps are written for SLURM submission and should not be run on the login node.

## Audited repository status as of 2026-04-28

- Completed and saved in the repository workspace:
  - Raw FastQC
  - FastQC extraction
  - Raw-read QC interpretation
  - Trimmomatic preparation and trimming
  - Post-trim FastQC
  - Post-trim FastQC extraction and interpretation
  - Single-reference BWA-MEM alignment and summary
  - Multi-reference BWA-MEM comparison and summary
  - Kraken2 bacteria database build
  - Kraken2 paired-read classification and summary
  - First-pass SPAdes assembly and summary
  - Focused 3-sample `--isolate` SPAdes rerun and summary
- Prepared but not yet completed:
  - Kraken2-guided `Vibrio` read filtering for the 3 strongest `Vibrio vulnificus` candidates
  - Filtered-read `--isolate` SPAdes rerun
  - ANI execution and summary
  - Annotation
  - Gene mining
  - Phylogenetics

## Current biological interpretation checkpoint

- Strongest current `Vibrio vulnificus` candidates:
  - `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`
  - `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`
  - `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`
- Likely non-`vulnificus Vibrio` sample:
  - `Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7`, which Kraken2 currently calls as `Vibrio cidicii`
- Mixed or unresolved `Vibrio` sample:
  - `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7`
- Strongest outlier / likely non-`Vibrio` or contaminated sample:
  - `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7`, which now shows a dominant `Bacillus` genus signal in Kraken2 and only about `1%` mapping against all tested references
- Assembly interpretation remains cautious:
  - The first-pass 6-sample assemblies and the 3-sample isolate rerun both remain inflated and fragmented relative to an isolate-scale bacterial genome, so the next corrective step in the repository is Kraken2-guided `Vibrio` read filtering before another focused assembly rerun.

## Repository structure

| Path | Purpose |
| --- | --- |
| `AGENTS.md` | Project-specific working rules for repository handling, staging, SLURM use, and documentation updates. |
| `PROJECT_BRIEF.md` | Project background, goals, planned workflow, and core computing constraints. |
| `IN_PROGRESS.md` | Running status notes for active pipeline state. |
| `WORK_COMPLETED.md` | Date-stamped milestone log of completed work. |
| `NEXT_STEPS.md` | Date-stamped queue of next actions and submission checkpoints. |
| `README.md` | High-level repository summary and quick rerun notes. |
| `fq_raw/` | Raw paired-end FASTQ inputs. Never modify these files. |
| `configs/` | Saved manifests and reference lists used by SLURM and summary scripts. |
| `scripts/` | Reusable shell, Python, and SLURM workflow scripts. |
| `fastqc/` | Raw-read FastQC HTML and ZIP outputs. |
| `fastqc_extracted/` | Extracted raw FastQC archive contents used for scripted review. |
| `fastqc_review/` | Curated raw-read QC interpretation outputs. |
| `trimmomatic/` | Trimming workspace, trimmed reads, unpaired reads, post-trim FastQC outputs, and trimming parameter records. |
| `alignment/` | Single-reference alignment workspace and curated summary table. |
| `multi_reference_alignment/` | 6-by-5 sample/reference alignment comparison workspace and curated comparison tables. |
| `kraken2_db/` | Bacteria-focused Kraken2 database build stage and metadata records. |
| `kraken2_classification/` | Broad Kraken2 paired-read classification stage and curated summary table. |
| `assembly/` | First-pass SPAdes assembly stage and curated summary table. |
| `assembly_isolate_rerun/` | Focused 3-sample isolate-mode SPAdes rerun stage and curated summary table. |
| `kraken2_vibrio_read_filtering/` | Prepared stage for retaining only Kraken2-classified `Vibrio` read pairs from the 3 strongest candidates. |
| `assembly_filtered_isolate_rerun/` | Prepared stage for the filtered-read isolate-mode rerun. |
| `ani/` | Prepared ANI stage, parameter record, and future summary targets. |
| `reference/` | Local reference FASTA files and indexes used by alignment and ANI preparation. |

## Directory details

### `configs/`

- Tracked manifest files currently present:
  - `configs/alignment_manifest.tsv`
  - `configs/ani_query_manifest.tsv`
  - `configs/ani_reference_manifest.tsv`
  - `configs/assembly_manifest.tsv`
  - `configs/assembly_manifest_vulnificus_candidates.tsv`
  - `configs/assembly_manifest_vulnificus_candidates_filtered.tsv`
  - `configs/kraken2_classification_manifest.tsv`
  - `configs/kraken2_vibrio_filter_manifest.tsv`
  - `configs/multi_reference_reference_manifest.tsv`
- These manifests are the reproducible handoff points between workflow stages.

### `fastqc/`, `fastqc_extracted/`, and `fastqc_review/`

- `fastqc/` stores the raw FastQC HTML and ZIP outputs for all forward and reverse reads.
- `fastqc_extracted/` stores the extracted archive contents used by the QC parser.
- `fastqc_review/` stores the interpreted report `fastqc_interpreted_report.md` plus generated status tables and logs.
- The curated raw-read interpretation is already complete.

### `trimmomatic/`

- Main subdirectories:

| Subdirectory | Purpose |
| --- | --- |
| `trimmomatic/copied_reads/` | Read-only copies of raw FASTQ files used as Trimmomatic inputs. |
| `trimmomatic/trimmed_reads/` | Paired trimmed reads used in downstream alignment, Kraken2, and assembly. |
| `trimmomatic/unpaired_reads/` | Unpaired reads produced by Trimmomatic. |
| `trimmomatic/logs/` | Stage logs and SLURM stdout/stderr. |
| `trimmomatic/metrics/` | Trimming parameter records and the generated input manifest. |
| `trimmomatic/fastqc_trimmed/` | FastQC outputs for trimmed paired reads. |
| `trimmomatic/fastqc_trimmed_extracted/` | Extracted post-trim FastQC archive contents. |
| `trimmomatic/fastqc_trimmed_review/` | Curated markdown interpretation of post-trim QC. |

- The tracked parameter files already present are:
  - `trimmomatic/metrics/trimmomatic_parameters.txt`
  - `trimmomatic/metrics/trimmomatic_input_manifest.tsv`

### `alignment/`

- `alignment/bam/` stores per-sample sorted BAM files and indexes.
- `alignment/metrics/` stores per-sample `flagstat` and `idxstats` files plus the curated table `alignment_summary.tsv`.
- This stage aligns against `reference/v_vulnificus_ref.fasta`.

### `multi_reference_alignment/`

- This stage expands the 6 trimmed samples across 5 references:
  - `v_alginolyticus`
  - `v_ostreicida_PP203`
  - `v_ostreicida_r172`
  - `v_parahaemolyticus`
  - `v_vulnificus`
- `multi_reference_alignment/metrics/` contains:
  - Per-combination `flagstat` files
  - Per-combination `idxstats` files
  - `multi_reference_alignment_summary.tsv`
  - `multi_reference_alignment_mapped_pct_matrix.tsv`
- The two `Vibrio ostreicida` references are draft multi-contig assemblies, so interpretation is based on aggregated contig-level mapping rather than a fixed two-chromosome assumption.

### `kraken2_db/`

- Stores the bacteria-focused Kraken2 database build stage.
- `kraken2_db/db/` is ignored in Git because it contains large `*.k2d` database files.
- `kraken2_db/metadata/` stores tracked build parameter files, disk-usage records, and the verification note `kraken2_build_verification_2026-04-17.md`.
- The database build is complete enough for downstream use.

### `kraken2_classification/`

- Stores the broad paired-read classification step against the finished Kraken2 database.
- Main outputs:
  - `kraken2_classification/outputs/` for per-sample Kraken2 output
  - `kraken2_classification/reports/` for per-sample report tables
  - `kraken2_classification/metrics/kraken2_classification_summary.tsv` for the curated summary
- The summary parser has already been corrected for the earlier `root`-row counting bug.

### `assembly/`

- Stores the first-pass de novo SPAdes outputs for all 6 trimmed samples.
- Main subdirectories:

| Subdirectory | Purpose |
| --- | --- |
| `assembly/assemblies/` | Sample-specific SPAdes output directories. |
| `assembly/logs/` | Stage logs and SLURM stdout/stderr. |
| `assembly/metrics/` | `spades_parameters.txt` and `assembly_summary.tsv`. |

### `assembly_isolate_rerun/`

- Stores the focused 3-sample SPAdes rerun for the strongest current `Vibrio vulnificus` candidates.
- This stage is intentionally separate from `assembly/` so the first-pass outputs remain available for comparison.

### `kraken2_vibrio_read_filtering/`

- Prepared stage for retaining only read pairs classified by Kraken2 as `Vibrio` genus (`taxid 662`) or below.
- Intended for the 3 strongest current `Vibrio vulnificus` candidates only.
- The stage already has:
  - `README.md`
  - `metrics/filtering_parameters.txt`
  - a manifest
  - the filtering and summary scripts
- The filtering array itself has not yet been run.

### `assembly_filtered_isolate_rerun/`

- Prepared destination for the next focused SPAdes rerun after Kraken2-guided `Vibrio` read filtering.
- This stage is currently prepared but not yet populated with finished assembly outputs.

### `ani/`

- Prepared stage for assembly-level ANI confirmation against the saved reference set.
- Tracked stage files already present:
  - `ani/README.md`
  - `ani/metrics/fastani_parameters.txt`
- The raw ANI outputs and curated ANI summary tables are not present yet because the stage has not been executed.

## Pipeline stages

### 1. Raw FastQC

- Script: `scripts/fastqc.slurm`
- Inputs:
  - `fq_raw/*_1.fq.gz`
  - `fq_raw/*_2.fq.gz`
- Outputs:
  - `fastqc/*_fastqc.html`
  - `fastqc/*_fastqc.zip`
- Status:
  - Complete

### 2. Raw FastQC extraction

- Script: `scripts/extract_fastqc_reports.sh`
- Inputs:
  - `fastqc/*_fastqc.zip`
- Outputs:
  - `fastqc_extracted/<report_dir>/summary.txt`
  - `fastqc_extracted/<report_dir>/fastqc_data.txt`
- Status:
  - Complete

### 3. Raw-read QC interpretation

- Script: `scripts/analyze_fastqc_reports.py`
- Outputs:
  - `fastqc_review/fastqc_interpreted_report.md`
  - `fastqc_review/fastqc_module_status.tsv`
- Main interpretation:
  - Raw reads are generally high quality.
  - Reverse reads showed PolyG / GC-related anomalies and overrepresented-sequence issues that justified trimming.
  - Forward-read tile-quality issues persisted as a likely lane artifact.
- Status:
  - Complete

### 4. Trimmomatic trimming

- Preparation script:
  - `scripts/prepare_trimmomatic_inputs.sh`
- Compute script:
  - `scripts/trimmomatic_array.slurm`
- Convenience submitter:
  - `scripts/submit_trimmomatic_array.sh`
- Outputs:
  - `trimmomatic/metrics/trimmomatic_input_manifest.tsv`
  - `trimmomatic/trimmed_reads/*_paired.fq.gz`
  - `trimmomatic/unpaired_reads/*_unpaired.fq.gz`
- Status:
  - Complete

### 5. Post-trim FastQC

- Script: `scripts/fastqc_trimmed.slurm`
- Outputs:
  - `trimmomatic/fastqc_trimmed/*_fastqc.html`
  - `trimmomatic/fastqc_trimmed/*_fastqc.zip`
- Status:
  - Complete

### 6. Post-trim FastQC extraction and interpretation

- Extraction script:
  - `scripts/extract_fastqc_trimmed_reports.sh`
- Analysis script:
  - `scripts/analyze_fastqc_trimmed_reports.py`
- Outputs:
  - `trimmomatic/fastqc_trimmed_extracted/`
  - `trimmomatic/fastqc_trimmed_review/fastqc_trimmed_interpreted_report.md`
- Main interpretation:
  - Trimming improved the major reverse-read overrepresented-sequence and GC-content issues.
  - Forward-read tile-quality failures and duplication remained.
- Status:
  - Complete

### 7. Single-reference alignment review

- Scripts:
  - `scripts/bwa_align_array.slurm`
  - `scripts/summarize_alignment_metrics.sh`
- Manifest:
  - `configs/alignment_manifest.tsv`
- Reference:
  - `reference/v_vulnificus_ref.fasta`
- Curated output:
  - `alignment/metrics/alignment_summary.tsv`
- Mapped percentages observed:
  - `Buck_BI0607_2...`: `1.05%`
  - `Buck_NB0507_14...`: `10.86%`
  - `Buck_BI0607_1...`: `30.57%`
  - `Buck_CB0707_82...`: `81.57%`
  - `Buck_BS0607_9...`: `87.51%`
  - `Buck_NB0507_8...`: `88.12%`
- Status:
  - Complete

### 8. Multi-reference alignment comparison

- Scripts:
  - `scripts/bwa_align_multiref_array.slurm`
  - `scripts/summarize_multiref_alignment_metrics.py`
- Manifest:
  - `configs/multi_reference_reference_manifest.tsv`
- Curated outputs:
  - `multi_reference_alignment/metrics/multi_reference_alignment_summary.tsv`
  - `multi_reference_alignment/metrics/multi_reference_alignment_mapped_pct_matrix.tsv`
- Main interpretation:
  - `Buck_BS0607_9...`, `Buck_CB0707_82...`, and `Buck_NB0507_8...` still match the `Vibrio vulnificus` reference best.
  - `Buck_BI0607_1...` also maps best to `Vibrio vulnificus`, but Kraken2 now argues it is likely another `Vibrio` species.
  - `Buck_NB0507_14...` maps best to `Vibrio alginolyticus` at `43.84%`.
  - `Buck_BI0607_2...` remains near-background across all tested references.
- Status:
  - Complete

### 9. Kraken2 bacterial database build

- Script:
  - `scripts/kraken2_build_bacterial_db.slurm`
- Stage documentation:
  - `kraken2_db/README.md`
- Main outputs:
  - `kraken2_db/db/hash.k2d`
  - `kraken2_db/db/opts.k2d`
  - `kraken2_db/db/taxo.k2d`
  - `kraken2_db/metadata/*.tsv`
  - `kraken2_db/metadata/kraken2_build_verification_2026-04-17.md`
- Main interpretation:
  - The database build succeeded after earlier failed attempts.
  - The successful run still logged some transient download issues, but the stage is usable.
- Status:
  - Complete

### 10. Kraken2 paired-read classification

- Scripts:
  - `scripts/kraken2_classify_array.slurm`
  - `scripts/summarize_kraken2_classification.py`
- Manifest:
  - `configs/kraken2_classification_manifest.tsv`
- Curated output:
  - `kraken2_classification/metrics/kraken2_classification_summary.tsv`
- Main interpretation:
  - Strong `Vibrio vulnificus` fits:
    - `Buck_BS0607_9...`
    - `Buck_CB0707_82...`
    - `Buck_NB0507_8...`
  - Strong non-`vulnificus Vibrio` fit:
    - `Buck_BI0607_1...` as `Vibrio cidicii`
  - Genus-level `Vibrio` but species-ambiguous:
    - `Buck_NB0507_14...`
  - Likely non-`Vibrio` outlier:
    - `Buck_BI0607_2...` with dominant `Bacillus`
- Status:
  - Complete

### 11. First-pass SPAdes assembly

- Scripts:
  - `scripts/spades_assembly_array.slurm`
  - `scripts/summarize_spades_assemblies.py`
- Manifest:
  - `configs/assembly_manifest.tsv`
- Curated output:
  - `assembly/metrics/assembly_summary.tsv`
- Main interpretation:
  - All 6 samples assembled, but scaffold totals remain inflated at roughly `18.7 Mb` to `65.2 Mb`.
  - These outputs should not yet be treated as clean isolate-scale assemblies for downstream biological conclusions.
- Status:
  - Complete

### 12. Focused isolate-mode SPAdes rerun

- Script:
  - `scripts/spades_assembly_array.slurm`
- Manifest:
  - `configs/assembly_manifest_vulnificus_candidates.tsv`
- Stage:
  - `assembly_isolate_rerun/`
- Curated output:
  - `assembly_isolate_rerun/metrics/assembly_summary.tsv`
- Main interpretation:
  - The rerun remained inflated, with scaffold totals of about `66.5 Mb`, `32.6 Mb`, and `19.0 Mb`.
  - This motivated the next prepared step: Kraken2-guided `Vibrio` read filtering before another rerun.
- Status:
  - Complete

### 13. Kraken2-guided Vibrio read filtering

- Scripts:
  - `scripts/filter_kraken2_vibrio_reads.py`
  - `scripts/summarize_kraken2_vibrio_filtering.py`
  - `scripts/kraken2_vibrio_filter_array.slurm`
- Manifest:
  - `configs/kraken2_vibrio_filter_manifest.tsv`
- Intended outputs:
  - `kraken2_vibrio_read_filtering/filtered_reads/*_paired.fq.gz`
  - `kraken2_vibrio_read_filtering/metrics/*.filtering_metrics.tsv`
  - `kraken2_vibrio_read_filtering/metrics/kraken2_vibrio_filtering_summary.tsv`
- Filtering rule:
  - Retain only read pairs assigned to `Vibrio` genus (`taxid 662`) or a descendant taxid.
- Status:
  - Prepared, not yet run

### 14. Filtered-read isolate-mode SPAdes rerun

- Script:
  - `scripts/spades_assembly_array.slurm`
- Manifest:
  - `configs/assembly_manifest_vulnificus_candidates_filtered.tsv`
- Stage:
  - `assembly_filtered_isolate_rerun/`
- Goal:
  - Compare filtered-read assemblies against both `assembly/` and `assembly_isolate_rerun/` before deciding which assemblies should feed ANI and later annotation.
- Status:
  - Prepared, not yet run

### 15. ANI confirmation

- Scripts:
  - `scripts/fastani_array.slurm`
  - `scripts/summarize_fastani.py`
- Manifests:
  - `configs/ani_query_manifest.tsv`
  - `configs/ani_reference_manifest.tsv`
- Intended outputs:
  - `ani/outputs/<sample_id>.fastani.tsv`
  - `ani/metrics/ani_summary.tsv`
  - `ani/metrics/ani_matrix.tsv`
- Interpretation target:
  - `95-96%` ANI or higher against `v_vulnificus` would support likely `Vibrio vulnificus`.
- Status:
  - Prepared, not yet run

### 16. Annotation, gene mining, and phylogenetics

- These planned downstream stages are still described in `PROJECT_BRIEF.md`, but no repository stage directories, scripts, or tracked outputs for them are present yet.
- Status:
  - Not started

## Script inventory

| Script | Purpose |
| --- | --- |
| `scripts/fastqc.slurm` | Raw-read FastQC batch script. |
| `scripts/extract_fastqc_reports.sh` | Extracts raw FastQC ZIP archives. |
| `scripts/analyze_fastqc_reports.py` | Parses raw FastQC outputs into a curated report. |
| `scripts/prepare_trimmomatic_inputs.sh` | Validates raw read pairs, copies them into the trimming workspace, and writes the trimming manifest. |
| `scripts/submit_trimmomatic_array.sh` | Convenience wrapper for Trimmomatic array submission. |
| `scripts/trimmomatic_array.slurm` | Trims one paired sample per SLURM array task. |
| `scripts/fastqc_trimmed.slurm` | FastQC batch script for trimmed paired reads. |
| `scripts/extract_fastqc_trimmed_reports.sh` | Extracts trimmed-read FastQC ZIP archives. |
| `scripts/analyze_fastqc_trimmed_reports.py` | Parses trimmed FastQC outputs into a curated report. |
| `scripts/bwa_align_array.slurm` | Single-reference BWA-MEM alignment array script. |
| `scripts/summarize_alignment_metrics.sh` | Summarizes single-reference alignment metrics. |
| `scripts/bwa_align_multiref_array.slurm` | Multi-reference BWA-MEM comparison array script. |
| `scripts/summarize_multiref_alignment_metrics.py` | Summarizes multi-reference alignment metrics. |
| `scripts/kraken2_build_bacterial_db.slurm` | Builds the bacteria-focused Kraken2 database with Singularity. |
| `scripts/kraken2_classify_array.slurm` | Runs broad Kraken2 paired-read classification plus summary mode. |
| `scripts/summarize_kraken2_classification.py` | Summarizes Kraken2 classification reports. |
| `scripts/spades_assembly_array.slurm` | Runs SPAdes arrays and supports summary mode for multiple assembly stages. |
| `scripts/summarize_spades_assemblies.py` | Summarizes SPAdes assembly metrics. |
| `scripts/filter_kraken2_vibrio_reads.py` | Filters paired FASTQ reads by Kraken2 `Vibrio` assignments while preserving pairing. |
| `scripts/summarize_kraken2_vibrio_filtering.py` | Summarizes the Kraken2-guided filtering stage. |
| `scripts/kraken2_vibrio_filter_array.slurm` | SLURM array script for Kraken2-guided `Vibrio` read filtering plus summary mode. |
| `scripts/fastani_array.slurm` | ANI array script with summary mode. |
| `scripts/summarize_fastani.py` | Summarizes ANI outputs into long-form and matrix tables. |
| `scripts/fastqc_vibecoded.txt` | Free-text notes related to FastQC workflow development. |

## Key parameters and defaults

### FastQC

- Software:
  - `fastqc/0.12.1`
- Default job resources:
  - `8` CPUs
  - `32G` memory
  - `4:00:00` walltime

### Trimmomatic

- Software:
  - `Trimmomatic 0.39`
  - `OpenJDK 17`
- Adapter FASTA:
  - `/cm/shared/tamucc/apps/trimmomatic/0.39/adapters/TruSeq3-PE.fa`
- Default job resources:
  - `8` CPUs
  - `64G` memory
  - `24:00:00` walltime
- Trimming settings:
  - `ILLUMINACLIP:TruSeq3-PE.fa:2:30:10`
  - `LEADING:3`
  - `TRAILING:3`
  - `SLIDINGWINDOW:4:20`
  - `MINLEN:50`

### BWA-MEM alignment

- Software:
  - `bwa`
  - `samtools`
- Default job resources:
  - `8` CPUs
  - `64G` memory
  - `24:00:00` walltime

### Kraken2 database build

- Runtime:
  - Singularity or Apptainer image containing `kraken2-build`
- Defaults documented in the current stage:
  - `KRAKEN2_DOWNLOAD_PROTOCOL=ftp`
  - `KRAKEN2_DOWNLOAD_MAX_ATTEMPTS=5`
  - `KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC=300`
  - `MIN_PROJECT_FREE_GB=250`
  - `MIN_TMP_FREE_GB=150`
  - `KRAKEN2_CLEAN_AFTER_BUILD=1`

### Kraken2 classification

- Mode:
  - Paired-end
  - `--report`
  - `--use-names`
  - `--memory-mapping`
- Thread count:
  - Derived from `SLURM_CPUS_PER_TASK`

### SPAdes

- Default stage resources:
  - `16` CPUs
  - `128G` memory
  - `48:00:00` walltime
- Default command structure:

```bash
spades.py \
  --pe1-1 <read1> \
  --pe1-2 <read2> \
  -o <stage_dir>/assemblies/<sample_id> \
  -t 16 \
  -m 120 \
  --tmp-dir <tmp_root>/spades_<sample_id>
```

- Rerun behavior:
  - The current reusable script supports `MANIFEST_FILE` and `STAGE_DIR` overrides.
  - It defaults to `--isolate` for rerun stages unless `SPADES_EXTRA_ARGS` is explicitly overridden.

### fastANI

- Default stage resources:
  - `8` CPUs
  - `32G` memory
  - `08:00:00` walltime
- Default command structure:

```bash
fastANI \
  --query assembly/assemblies/<sample_id>/contigs.fasta \
  --rl ani/metrics/fastani_reference_list.txt \
  --output ani/outputs/<sample_id>.fastani.tsv \
  --threads 8 \
  --fragLen 3000 \
  --kmer 16 \
  --minFraction 0.2
```

## Reproducibility notes

- Work from the repository root:

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
```

- Heavy stages should be submitted through SLURM, not run directly on the login node.
- The workflow preserves forward/reverse pairing throughout trimming, filtering, alignment, and assembly stages.
- Stage outputs are intentionally separated so comparisons can be made between:
  - First-pass assembly
  - Isolate rerun
  - Future filtered-read isolate rerun
- The audited repository state shows that `NEXT_STEPS.md`, `IN_PROGRESS.md`, and `WORK_COMPLETED.md` are being used as the project log of record for milestone tracking.

## Current next-run commands

### 1. Run Kraken2-guided `Vibrio` filtering

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
sbatch --array=0-2 scripts/kraken2_vibrio_filter_array.slurm
sbatch --export=ALL,KRAKEN2_VIBRIO_FILTER_MODE=summary scripts/kraken2_vibrio_filter_array.slurm
```

### 2. Run the filtered-read isolate rerun if retained-read counts look reasonable

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
sbatch --export=ALL,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered.tsv,STAGE_DIR=assembly_filtered_isolate_rerun --array=0-2 scripts/spades_assembly_array.slurm
sbatch --export=ALL,SPADES_MODE=summary,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered.tsv,STAGE_DIR=assembly_filtered_isolate_rerun scripts/spades_assembly_array.slurm
```

### 3. Compare assembly summaries before choosing ANI inputs

- Compare:
  - `assembly/metrics/assembly_summary.tsv`
  - `assembly_isolate_rerun/metrics/assembly_summary.tsv`
  - `assembly_filtered_isolate_rerun/metrics/assembly_summary.tsv` once generated

### 4. Run ANI after choosing the preferred assembly set

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
sbatch --array=0-5 scripts/fastani_array.slurm
sbatch --export=ALL,ANI_MODE=summary scripts/fastani_array.slurm
```

## Git tracking summary

### Tracked

- Documentation and project logs
- Reusable scripts
- Saved manifests
- Small parameter records
- Curated markdown reports
- Curated TSV summaries such as:
  - `alignment/metrics/alignment_summary.tsv`
  - `multi_reference_alignment/metrics/multi_reference_alignment_summary.tsv`
  - `multi_reference_alignment/metrics/multi_reference_alignment_mapped_pct_matrix.tsv`
  - `kraken2_classification/metrics/kraken2_classification_summary.tsv`
  - `assembly/metrics/assembly_summary.tsv`
  - `assembly_isolate_rerun/metrics/assembly_summary.tsv`

### Not tracked

- Raw FASTQ files
- Trimmed and filtered FASTQ files
- FastQC HTML and ZIP outputs
- BAM files
- Most large runtime logs
- Kraken2 database files
- SPAdes assembly directories
- Future ANI raw output files
- Singularity images such as `kraken2.sif` and `spades.sif`

## Gaps still remaining relative to the project brief

- No annotation stage is implemented yet.
- No gene-mining stage is implemented yet for targets such as `vcgC`, `vcgE`, `vvhA`, `rpoS`, or `ompU`.
- No phylogenetics stage is implemented yet.
- ANI is prepared but not yet executed, so the repository still lacks assembly-level species confirmation.
