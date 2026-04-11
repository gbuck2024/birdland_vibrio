# Vibrio vulnificus Whole-Genome Sequencing Pipeline

## Project Overview

- This repository documents a reproducible whole-genome sequencing workflow for **Vibrio vulnificus** isolates.
- The pipeline is intended to transform raw paired-end Illumina reads into quality-controlled datasets that can be used for downstream genome assembly, annotation, virulence marker screening, comparative analysis, and phylogenetics.
- The immediate project focus is to evaluate raw read quality, trim low-quality and adapter-contaminated sequence, and verify post-trimming read quality before assembly.
- Based on the project brief, the broader biological goal is to identify genomic features associated with virulence, diversity, and classification, including targets such as `vcgC` and `vcgE`.

## What The Pipeline Produces

- Raw-read FastQC reports for each forward and reverse FASTQ file.
- Extracted FastQC report contents for scripted parsing.
- A curated raw-read QC interpretation report summarizing sample-wide quality trends.
- A Trimmomatic input manifest that records paired samples and validates copied inputs.
- Trimmed paired-end reads for downstream analysis.
- Unpaired reads retained from trimming.
- Post-trim FastQC reports for trimmed paired reads.
- Extracted post-trim FastQC contents for scripted parsing.
- A curated post-trim QC interpretation report and raw-versus-trimmed comparison tables.

## Current Pipeline Status

- Completed:
  - Raw-read FastQC
  - FastQC archive extraction
  - Raw-read QC interpretation
  - Trimmomatic preparation
  - Trimmomatic trimming
  - Post-trim FastQC
  - Post-trim FastQC extraction
  - Post-trim QC interpretation
- Next planned stage:
  - Assembly workflow development on trimmed paired reads

## Repository Structure

| Path | Purpose |
| --- | --- |
| `AGENTS.md` | Project-specific working rules for Codex and repository operations. |
| `PROJECT_BRIEF.md` | Project background, biological goals, planned workflow, and computing constraints. |
| `IN_PROGRESS.md` | Running status notes for active and recently completed work. |
| `WORK_COMPLETED.md` | Milestone log of completed pipeline steps and deliverables. |
| `NEXT_STEPS.md` | Planned upcoming work and submission checkpoints. |
| `README.md` | GitHub-facing summary of the repository and rerun instructions. |
| `fq_raw/` | Raw paired-end input FASTQ files. These must never be modified. |
| `fastqc/` | Raw-read FastQC HTML and ZIP outputs. |
| `fastqc_extracted/` | Extracted contents from raw-read FastQC ZIP archives for downstream parsing. |
| `fastqc_review/` | Curated markdown interpretation of raw-read FastQC plus related generated review outputs. |
| `trimmomatic/` | Trimming workspace containing copied inputs, manifests, trimmed reads, unpaired reads, logs, and post-trim QC outputs. |
| `scripts/` | Reusable shell, SLURM, and Python scripts for the pipeline. |

## Directory Details

### `fastqc/`

- Stores raw-read FastQC outputs generated from `fq_raw/*.fq.gz`.
- Contains one `.html` report and one `.zip` archive per FASTQ file.
- These files are generated outputs and are ignored by Git.

### `fastqc_extracted/`

- Stores extracted contents from each raw-read FastQC ZIP archive.
- Each extracted report directory contains `summary.txt`, `fastqc_data.txt`, and the original FastQC support files.
- Used as the input source for raw-read QC interpretation.

### `fastqc_review/`

- Stores interpreted raw-read QC outputs.
- Key file:
  - `fastqc_interpreted_report.md`: curated markdown summary of raw-read quality findings.
- Generated logs, TSV summaries, and SLURM stdout/stderr in this directory are ignored by Git.

### `trimmomatic/`

- Stores all outputs related to read trimming and post-trim QC.
- Key subdirectories:

| Subdirectory | Purpose |
| --- | --- |
| `trimmomatic/copied_reads/` | Read-only copies of raw FASTQ files used as Trimmomatic inputs. |
| `trimmomatic/trimmed_reads/` | Trimmed paired reads for downstream analysis. |
| `trimmomatic/unpaired_reads/` | Reads retained by Trimmomatic when only one mate passed filters. |
| `trimmomatic/logs/` | Step-level logs, including SLURM stdout/stderr. |
| `trimmomatic/metrics/` | Parameter records and generated manifests. |
| `trimmomatic/fastqc_trimmed/` | Post-trim FastQC reports, metrics, and logs. |
| `trimmomatic/fastqc_trimmed_extracted/` | Extracted contents from post-trim FastQC ZIP archives. |
| `trimmomatic/fastqc_trimmed_review/` | Curated markdown interpretation of trimmed-read QC and raw-versus-trimmed comparisons. |

### `scripts/`

- Stores all reusable pipeline scripts.
- Scripts are written so outputs can be regenerated from the repository rather than by manual terminal history.

## Pipeline Steps

The workflow currently implemented in this repository follows this order:

1. **FastQC on raw reads**
   - Run FastQC on all raw paired-end FASTQ files in `fq_raw/`.
   - Output directory: `fastqc/`
2. **Extraction of raw FastQC reports**
   - Unzip FastQC archives and verify required files.
   - Output directory: `fastqc_extracted/`
3. **Raw-read QC analysis**
   - Parse `summary.txt` and `fastqc_data.txt` across all samples.
   - Output directory: `fastqc_review/`
4. **Trimmomatic trimming**
   - Validate mate pairs, create a manifest, copy inputs into a non-destructive trimming workspace, and trim paired reads.
   - Output directory: `trimmomatic/`
5. **Post-trim FastQC**
   - Run FastQC on the trimmed paired reads.
   - Output directory: `trimmomatic/fastqc_trimmed/`
6. **Post-trim QC analysis**
   - Extract trimmed FastQC archives and compare trimmed quality metrics against the raw-read baseline.
   - Output directories:
     - `trimmomatic/fastqc_trimmed_extracted/`
     - `trimmomatic/fastqc_trimmed_review/`

## Script Descriptions

| Script | Description |
| --- | --- |
| `scripts/fastqc.slurm` | SLURM batch script that runs FastQC on all raw `fq_raw/*.fq.gz` files and writes outputs to `fastqc/`. |
| `scripts/extract_fastqc_reports.sh` | Shell script that extracts each raw-read FastQC ZIP archive into `fastqc_extracted/` and verifies `summary.txt` and `fastqc_data.txt`. |
| `scripts/analyze_fastqc_reports.py` | Python script that parses extracted raw FastQC reports, summarizes module statuses, and writes `fastqc_review/fastqc_interpreted_report.md` plus a TSV status table. |
| `scripts/prepare_trimmomatic_inputs.sh` | Shell script that validates read pairing, copies raw reads into `trimmomatic/copied_reads/`, checks byte-size consistency, and writes `trimmomatic/metrics/trimmomatic_input_manifest.tsv`. |
| `scripts/submit_trimmomatic_array.sh` | Convenience wrapper that reads the manifest and submits the Trimmomatic SLURM array across all samples. |
| `scripts/trimmomatic_array.slurm` | SLURM array script that trims one paired sample per task using Trimmomatic, writes paired and unpaired outputs, and records per-task stdout/stderr logs. |
| `scripts/fastqc_trimmed.slurm` | SLURM batch script that validates trimmed paired reads, builds a post-trim manifest, and runs FastQC on trimmed paired samples. |
| `scripts/extract_fastqc_trimmed_reports.sh` | Shell script that extracts post-trim FastQC ZIP archives into `trimmomatic/fastqc_trimmed_extracted/` and verifies required files. |
| `scripts/analyze_fastqc_trimmed_reports.py` | Python script that parses extracted trimmed FastQC reports, compares trimmed versus raw module outcomes, and writes `trimmomatic/fastqc_trimmed_review/fastqc_trimmed_interpreted_report.md` plus TSV summaries. |
| `scripts/fastqc_vibecoded.txt` | Free-text notes related to FastQC scripting and workflow context. |

## Key Parameters Used

### FastQC

- Software: `fastqc/0.12.1`
- Raw-read job resources:
  - `8` CPUs
  - `32G` memory
  - `4:00:00` walltime
- Post-trim FastQC job resources:
  - `8` CPUs
  - `32G` memory
  - `4:00:00` walltime

### Trimmomatic

- Software: `trimmomatic/0.39`
- Java runtime: `OpenJDK 17`
- Adapter FASTA: `/cm/shared/tamucc/apps/trimmomatic/0.39/adapters/TruSeq3-PE.fa`
- Job resources:
  - `8` CPUs
  - `64G` memory
  - `24:00:00` walltime
- Trimming settings:
  - `ILLUMINACLIP:TruSeq3-PE.fa:2:30:10`
  - `LEADING:3`
  - `TRAILING:3`
  - `SLIDINGWINDOW:4:20`
  - `MINLEN:50`

## Reproducibility

### Requirements

- HPC environment with SLURM.
- Access to the TAMU-CC CREST software modules used by the scripts.
- Raw reads present in `fq_raw/`.
- Execution from the repository root:

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
```

### Step-By-Step Rerun Commands

#### 1. Run FastQC on raw reads

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
sbatch scripts/fastqc.slurm
```

#### 2. Check the FastQC SLURM job within 1 to 2 minutes

```bash
squeue -u "$USER"
ls -1 fastqc/logs/slurm
```

#### 3. Extract raw FastQC reports

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
bash scripts/extract_fastqc_reports.sh
```

#### 4. Analyze raw FastQC reports

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
python3 scripts/analyze_fastqc_reports.py
```

#### 5. Prepare Trimmomatic inputs

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
bash scripts/prepare_trimmomatic_inputs.sh
```

#### 6. Submit the Trimmomatic array

Use the wrapper:

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
bash scripts/submit_trimmomatic_array.sh
```

Or submit directly after confirming the manifest:

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
sbatch --array=0-5 scripts/trimmomatic_array.slurm
```

#### 7. Check the Trimmomatic array within 1 to 2 minutes

```bash
squeue -u "$USER"
ls -1 trimmomatic/logs/slurm
```

#### 8. Run FastQC on trimmed paired reads

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
sbatch scripts/fastqc_trimmed.slurm
```

#### 9. Check the post-trim FastQC job within 1 to 2 minutes

```bash
squeue -u "$USER"
ls -1 trimmomatic/logs/slurm
```

#### 10. Extract post-trim FastQC reports

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
bash scripts/extract_fastqc_trimmed_reports.sh
```

#### 11. Analyze post-trim FastQC reports

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
python3 scripts/analyze_fastqc_trimmed_reports.py
```

### Expected Primary Outputs

| Step | Primary outputs |
| --- | --- |
| Raw FastQC | `fastqc/*.html`, `fastqc/*.zip` |
| Raw FastQC extraction | `fastqc_extracted/*/summary.txt`, `fastqc_extracted/*/fastqc_data.txt` |
| Raw QC analysis | `fastqc_review/fastqc_interpreted_report.md` |
| Trimmomatic prep | `trimmomatic/metrics/trimmomatic_input_manifest.tsv` |
| Trimmomatic trimming | `trimmomatic/trimmed_reads/*_paired.fq.gz`, `trimmomatic/unpaired_reads/*_unpaired.fq.gz` |
| Post-trim FastQC | `trimmomatic/fastqc_trimmed/reports/*/*.html`, `trimmomatic/fastqc_trimmed/reports/*/*.zip` |
| Post-trim extraction | `trimmomatic/fastqc_trimmed_extracted/*/summary.txt`, `trimmomatic/fastqc_trimmed_extracted/*/fastqc_data.txt` |
| Post-trim QC analysis | `trimmomatic/fastqc_trimmed_review/fastqc_trimmed_interpreted_report.md` |

## What Was Tracked

The repository currently tracks lightweight documentation, scripts, and curated markdown outputs, including:

- Project documentation:
  - `AGENTS.md`
  - `PROJECT_BRIEF.md`
  - `IN_PROGRESS.md`
  - `WORK_COMPLETED.md`
  - `NEXT_STEPS.md`
  - `README.md`
- Reusable scripts in `scripts/`
- Curated markdown QC summaries:
  - `fastqc_review/fastqc_interpreted_report.md`
  - `trimmomatic/fastqc_trimmed_review/fastqc_trimmed_interpreted_report.md`
- Trimmomatic parameter documentation:
  - `trimmomatic/metrics/trimmomatic_parameters.txt`

## What Was Not Tracked

Large inputs, bulky generated outputs, runtime logs, and transient artifacts are intentionally not tracked. Based on `.gitignore`, this includes:

- Raw reads:
  - `fq_raw/`
- Generated FastQC outputs:
  - `fastqc/`
  - `fastqc_extracted/`
  - `trimmomatic/fastqc_trimmed/`
  - `trimmomatic/fastqc_trimmed_extracted/`
- Generated read files:
  - `trimmomatic/copied_reads/`
  - `trimmomatic/trimmed_reads/`
  - `trimmomatic/unpaired_reads/`
  - `*.fastq`
  - `*.fastq.gz`
  - `*.fq`
  - `*.fq.gz`
- Generated logs and tables:
  - `fastqc_review/logs/`
  - `fastqc_review/*.tsv`
  - `fastqc_review/*.out`
  - `fastqc_review/*.err`
  - `trimmomatic/fastqc_trimmed_review/logs/`
  - `trimmomatic/fastqc_trimmed_review/*.tsv`
  - `trimmomatic/logs/`
  - `fastqc/logs/`
  - `slurm-*.out`
  - `slurm-*.err`
- Generated manifests:
  - `trimmomatic/metrics/trimmomatic_input_manifest.tsv`
- Local cache and interpreter artifacts:
  - `__pycache__/`
  - `*.py[cod]`
  - `.ipynb_checkpoints/`
  - temporary files and OS-specific junk

## Notes

- The repository is organized to keep raw data unchanged and to write each processing stage into a separate output directory.
- Compute-heavy steps are designed for SLURM submission rather than execution on the login node.
- All paired-end operations preserve forward and reverse read pairing.
- The current QC checkpoint indicates that trimming improved the major reverse-read PolyG and GC-content issues, while forward-read per-tile failures remain as a likely lane artifact to monitor during assembly.
