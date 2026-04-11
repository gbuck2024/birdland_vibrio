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

