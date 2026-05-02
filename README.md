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
8. SPAdes assembly preparation
9. ANI preparation against the existing reference genomes
10. Kraken2-filtered Vibrio read subsampling preparation
11. SPAdes filtered-subsampled isolate rerun preparation
12. ANI substage preparation for the 3 best completed subsampled assemblies

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
10. SPAdes assembly preparation
11. ANI-based species confirmation against the reference set
12. Kraken2-filtered Vibrio read subsampling
13. SPAdes filtered-subsampled isolate rerun
14. ANI run for the 3 best completed subsampled assemblies
15. Planned next stage after ANI: annotation, gene mining, and phylogenetics

## Current Status

As of 2026-05-01, the project has completed the QC, trimming, alignment-review, multi-reference comparison, Kraken2 database, Kraken2 classification-summary, first SPAdes preparation, ANI stage-preparation, Kraken2-guided Vibrio read filtering, the filtered-read `--isolate` rerun review, the fixed-depth subsampled assembly review, and the new ANI substage preparation for the three strongest current `Vibrio vulnificus` candidates. The ANI execution path now expects the saved fastANI container image under `containers/` by default.

The current decision point is no longer subsampling or assembly preparation. The current decision point is when to submit the new ANI substage for the 3 selected best completed subsampled assemblies:

- `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7_50x`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7_25x`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7_100x` are the selected best completed subsampled assemblies for the next ANI run.
- `Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` classifies strongly as *Vibrio cidicii*, so it should be treated as a likely non-*vulnificus Vibrio* isolate unless assembly or annotation contradicts that.
- `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` remains genus-level *Vibrio* but species-ambiguous.
- `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` no longer looks primarily *Vibrio*; Kraken2 points instead toward a strong *Bacillus* genus signal.

The assembly stage is prepared with:

- `configs/assembly_manifest.tsv`
- `scripts/spades_assembly_array.slurm`
- `scripts/summarize_spades_assemblies.py`
- `assembly/README.md`
- `assembly/metrics/spades_parameters.txt`

The ANI stage is prepared with:

- `configs/ani_query_manifest.tsv`
- `configs/ani_reference_manifest.tsv`
- `scripts/fastani_array.slurm`
- `scripts/summarize_fastani.py`
- `ani/README.md`
- `ani/metrics/fastani_parameters.txt`

The best-subsampled ANI substage is prepared with:

- `configs/ani_query_manifest_subsampled_best_assemblies.tsv`
- `ani/subsampled_best_assemblies/README.md`
- `ani/subsampled_best_assemblies/metrics/fastani_parameters.txt`

The new subsampling stage is prepared with:

- `configs/kraken2_vibrio_subsample_manifest.tsv`
- `scripts/subsample_paired_fastq.py`
- `scripts/summarize_subsampled_reads.py`
- `scripts/subsample_vibrio_reads_array.slurm`
- `kraken2_vibrio_subsampled_reads/README.md`
- `kraken2_vibrio_subsampled_reads/metrics/subsampling_parameters.txt`

The new subsampled-assembly rerun stage is prepared with:

- `configs/assembly_manifest_vulnificus_candidates_filtered_subsampled.tsv`
- `assembly_filtered_subsampled_isolate/README.md`
- `assembly_filtered_subsampled_isolate/metrics/spades_parameters.txt`

## Repository Structure

- `scripts/`: reusable shell, SLURM, and Python workflow scripts
- `configs/`: tracked manifests and reference lists used by batch jobs
- `containers/`: local Singularity images used by reproducible compute stages
- `fastqc_review/`: curated raw-read QC interpretation
- `trimmomatic/`: trimming workspace and post-trim QC outputs
- `alignment/`: single-reference alignment workspace and curated summary table
- `multi_reference_alignment/`: alternative-reference comparison workspace and curated summary tables
- `kraken2_db/`: bacteria-focused Kraken2 database build records and metadata
- `kraken2_classification/`: per-sample Kraken2 outputs plus the curated classification summary
- `kraken2_vibrio_read_filtering/`: Kraken2-guided retained `Vibrio` read pairs plus filtering metrics
- `kraken2_vibrio_subsampled_reads/`: planned `25x`, `50x`, and `100x` subsampled paired FASTQ stage for the filtered `Vibrio` candidates
- `assembly/`: SPAdes assembly workspace, parameter record, and curated assembly-summary target
- `assembly_filtered_isolate_rerun/`: completed filtered-read `--isolate` rerun used as the pre-subsampling decision point
- `assembly_filtered_subsampled_isolate/`: prepared `--isolate` rerun stage for the fixed-depth subsampled read sets
- `ani/`: ANI workspace for raw fastANI outputs plus curated ANI summary and matrix tables
- `ani/subsampled_best_assemblies/`: new isolated ANI substage for the 3 selected scaffold assemblies from the completed subsampled assembly review

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
- Assembly parameter records and future curated assembly summary tables
- ANI parameter records and future curated ANI summary tables

## Untracked Information

- Raw FASTQ files
- FastQC .html/.zip outputs
- Trimmed reads
- Logs
- Local Singularity container images such as `containers/kraken2.sif`, `containers/spades.sif`, and `containers/fastani_latest.sif`

By Gilbert N. Lametrie
