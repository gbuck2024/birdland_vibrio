# Vibrio vulnificus WGS Pipeline

## Overview

This repository contains a reproducible bioinformatics pipeline for processing *Vibrio vulnificus* whole-genome sequencing data and related candidate *Vibrio* references.

The current tracked workflow takes raw paired-end Illumina reads through:

1. Raw-read FastQC
2. FastQC extraction and QC interpretation
3. Trimmomatic trimming
4. Post-trim FastQC and comparison
5. Single-reference BWA-MEM alignment review
6. Multi-reference BWA-MEM comparison across 5 candidate *Vibrio* references

## Pipeline Summary

1. FastQC on raw reads
2. Extract FastQC reports
3. QC interpretation
4. Trimmomatic trimming
5. FastQC on trimmed reads
6. Post-trim QC analysis
7. BWA-MEM alignment review
8. Multi-reference alignment comparison
9. Planned next stage: SPAdes assembly, followed by annotation and gene mining

## Repository Structure

- `scripts/`: reusable shell, SLURM, and Python workflow scripts
- `configs/`: tracked manifests and reference lists used by batch jobs
- `fastqc_review/`: curated raw-read QC interpretation
- `trimmomatic/`: trimming workspace and post-trim QC outputs
- `alignment/`: single-reference alignment workspace and curated summary table
- `multi_reference_alignment/`: alternative-reference comparison workspace and curated summary tables

## Reproducibility

Detailed workflow, SLURM usage, and rerun notes are documented in `DETAILED_WORKFLOW.md`.

```bash
cd /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
sbatch scripts/fastqc.slurm
bash scripts/extract_fastqc_reports.sh
python3 scripts/analyze_fastqc_reports.py

bash scripts/prepare_trimmomatic_inputs.sh
bash scripts/submit_trimmomatic_array.sh

sbatch scripts/fastqc_trimmed.slurm
bash scripts/extract_fastqc_trimmed_reports.sh
python3 scripts/analyze_fastqc_trimmed_reports.py
```

The heavy compute stages are written for SLURM submission and should not be run on the login node.

## Tracked Information

- Scripts
- Documentation
- QC interpretation reports
- Parameter files
- Curated alignment summary tables

## Untracked Information

- Raw FASTQ files
- FastQC .html/.zip outputs
- Trimmed reads
- Logs

By Gilbert N. Lametrie
