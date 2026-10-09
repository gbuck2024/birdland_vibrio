# SRA Kraken2 Classification Stage

This stage classifies the six SRA trimmed paired-read sets against the saved Kraken2 bacterial database without mixing outputs with the original Buck read-classification stage.

## Inputs

- Manifest: `configs/kraken2_classification_manifest_sra.tsv`
- Paired trimmed reads: `trimmomatic/trimmed_reads/SRR*_L7_*_paired.fq.gz`
- Kraken2 database: `kraken2_db/db`
- Container: `containers/kraken2.sif`

## Submit

```bash
sbatch \
  -o kraken2_classification_sra/logs/slurm/kraken2_classify_%A_%a.out \
  -e kraken2_classification_sra/logs/slurm/kraken2_classify_%A_%a.err \
  --export=ALL,MANIFEST_FILE=configs/kraken2_classification_manifest_sra.tsv,STAGE_DIR=kraken2_classification_sra \
  --array=0-5 \
  scripts/kraken2_classify_array.slurm
```

After the array completes, summarize with:

```bash
sbatch \
  -o kraken2_classification_sra/logs/slurm/kraken2_summary_%j.out \
  -e kraken2_classification_sra/logs/slurm/kraken2_summary_%j.err \
  --export=ALL,KRAKEN2_CLASSIFICATION_MODE=summary,MANIFEST_FILE=configs/kraken2_classification_manifest_sra.tsv,STAGE_DIR=kraken2_classification_sra \
  scripts/kraken2_classify_array.slurm
```

## Expected Outputs

- `kraken2_classification_sra/outputs/<sample_id>.kraken2.tsv`
- `kraken2_classification_sra/reports/<sample_id>.kreport.tsv`
- `kraken2_classification_sra/metrics/kraken2_classification_summary.tsv`
