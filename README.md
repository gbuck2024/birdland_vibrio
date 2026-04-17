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
7. Kraken2 bacterial database build and paired-read taxonomic classification summary

## Pipeline Summary

1. FastQC on raw reads
2. Extract FastQC reports
3. QC interpretation
4. Trimmomatic trimming
5. FastQC on trimmed reads
6. Post-trim QC analysis
7. BWA-MEM alignment review
8. Multi-reference alignment comparison
9. Kraken2 bacteria-focused taxonomic screen
10. Planned next stage: SPAdes assembly, followed by annotation, gene mining, and phylogenetics

## Current Status

As of 2026-04-17, the project has completed the QC, trimming, alignment-review, multi-reference comparison, Kraken2 database, and Kraken2 classification-summary milestones for all 6 samples.

The current decision point is no longer whether the Kraken2 stage ran; it did. The current decision point is how to carry the taxonomic split forward into assembly and downstream interpretation:

- `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7` now look like strong *Vibrio vulnificus* candidates.
- `Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` classifies strongly as *Vibrio cidicii*, so it should be treated as a likely non-*vulnificus Vibrio* isolate unless assembly or annotation contradicts that.
- `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` remains genus-level *Vibrio* but species-ambiguous.
- `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` no longer looks primarily *Vibrio*; Kraken2 points instead toward a strong *Bacillus* genus signal.

## Repository Structure

- `scripts/`: reusable shell, SLURM, and Python workflow scripts
- `configs/`: tracked manifests and reference lists used by batch jobs
- `fastqc_review/`: curated raw-read QC interpretation
- `trimmomatic/`: trimming workspace and post-trim QC outputs
- `alignment/`: single-reference alignment workspace and curated summary table
- `multi_reference_alignment/`: alternative-reference comparison workspace and curated summary tables
- `kraken2_db/`: bacteria-focused Kraken2 database build records and metadata
- `kraken2_classification/`: per-sample Kraken2 outputs plus the curated classification summary

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
- Curated Kraken2 classification summary tables

## Untracked Information

- Raw FASTQ files
- FastQC .html/.zip outputs
- Trimmed reads
- Logs
- Local Singularity container images such as `kraken2.sif`

By Gilbert N. Lametrie
