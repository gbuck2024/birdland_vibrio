# Kraken2 classification stage

This stage classifies the 6 paired-end trimmed read sets against the finished bacteria-focused Kraken2 database in `kraken2_db/db/`.

## Important input note

Kraken2 classifies sequence reads, not FastQC reports. The runtime inputs for this stage are the paired trimmed FASTQ files listed in `configs/kraken2_classification_manifest.tsv`.

## Files prepared now

- `configs/kraken2_classification_manifest.tsv`: sample manifest for the 6 paired trimmed read pairs.
- `scripts/kraken2_classify_array.slurm`: reusable SLURM script for array-based Kraken2 classification plus a summary mode.
- `scripts/summarize_kraken2_classification.py`: parser that combines the saved per-sample reports into one curated TSV summary.
- `kraken2_classification/README.md`: stage note for expected inputs, outputs, and interpretation rules.

## Current stage status

- The 6-sample classification array job has already been run and produced per-sample outputs under `kraken2_classification/outputs/` plus per-sample reports under `kraken2_classification/reports/`.
- The curated summary table is now present at `kraken2_classification/metrics/kraken2_classification_summary.tsv`.
- The first submitted summary job failed because the parser treated the Kraken2 `root` row as total reads. The parser has since been corrected to derive totals from `classified + unclassified` counts in the saved report.

## Expected runtime outputs

- `kraken2_classification/outputs/`: one Kraken2 output file per sample.
- `kraken2_classification/reports/`: one Kraken2 report file per sample.
- `kraken2_classification/metrics/kraken2_classification_summary.tsv`: curated summary across all 6 samples.
- `kraken2_classification/logs/slurm/`: SLURM stdout and stderr logs from submitted jobs.

## Classification behavior

- Paired-end mode is used.
- `--report` and `--use-names` are enabled.
- Thread count comes from `SLURM_CPUS_PER_TASK`.
- The script defaults to `--memory-mapping` because the finished Kraken2 database is large and this reduces node-memory pressure.

## Summary behavior

The parser ranks species-level hits before genus-level hits and writes a final TSV with:

- `sample_id`
- `total_reads`
- `classified_reads`
- `percent_classified`
- `top_species_hit`
- `top_species_percent`
- `top_genus_hit`
- `top_genus_percent`
- `second_best_species_hit`
- `second_best_species_percent`
- `top_hit_is_vibrio`
- `classification_flag`
- `short_interpretation`

The interpretation logic assigns one of these labels:

- `strong species fit`
- `genus-level only fit`
- `mixed/ambiguous`
- `mostly unclassified`

## Submission example

Do not run this classification on the login node.

Classify the 6 saved samples:

```bash
sbatch --array=0-5 scripts/kraken2_classify_array.slurm
```

After the array finishes, build the summary table:

```bash
sbatch --export=ALL,KRAKEN2_CLASSIFICATION_MODE=summary scripts/kraken2_classify_array.slurm
```
