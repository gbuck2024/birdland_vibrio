# Vibrio vulnificus WGS Pipeline.

## Overview

This repository contains reproducible bioinformatics pipeline for processing *Vibrio vulnificus* whole-genome sequencing (WGS) data.

The pipeline transforms raw paired-end Illumina reads into quality-controlled, trimmed datasets suitable for:

- Genome assembly
- Alignment
- Gene mining
- Phylogenetic analysis

---

## Pipeline Summary

1. FastQC on raw reads
2. Extract FastQC reports
3. QC interpretation
4. Trimmomatic trimming
5. FastQC on trimmed reads
6. Post-trim QC analysis

---

## Repository Structure

scripts/ # Pipeline scripts
fastqc_review/ # Raw QC interpretation
trimmomatic/ #Trimming + post-QC summaries.

---

## Reproducibility

Detailed workflow, SLURM usage and explanations located within DETAILED_WORKFLOW.md
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs

sbatch scripts/fastqc.slurm
bash scripts/extract_fastqc_reports.sh
python3 scripts/analyze_fastqc_reports.py

bash scripts/prepare_trimmomatic_inputs.sh
bash scripts/submit_trimmomatic_array.sh

sbatch scripts/fastqc_trimmed.slurm
bash scripts/extract_fastqc_trimmed_reports.sh
python3 scripts/analyze_fastqc_trimmed_reports.py

---

## Tracked Information

- Scripts
- Documentation
- QC interpretation reports
- Parameter files

---

## Untracked Information

- Raw FASTQ files
- FastQC .html/.zip outputs
- Trimmed reads
- Logs



By Gilbert N. Lametrie
