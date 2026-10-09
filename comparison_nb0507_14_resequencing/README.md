# NB0507-14 resequencing comparison

This stage compares `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` and `SRR37852095_L7` as a matched biological isolate sequenced in two runs.

Existing raw/post-trim FastQC, Trimmomatic, SPAdes, self-mapping, BlobToolKit-style contig tables, and Kraken2 outputs are parsed without modifying earlier stages. Heavy follow-up jobs are isolated under `comparison_nb0507_14_resequencing/`.

## Current lightweight summary

```bash
python3 scripts/summarize_nb0507_14_resequencing.py
module load R/gcc11/4.4.0
Rscript scripts/plot_nb0507_14_resequencing.R
```

Primary outputs:

- `metrics/matched_isolate_comparison.tsv`
- `metrics/matched_isolate_comparison.md`
- `metrics/assembly_comparison.tsv`
- `metrics/coverage_comparison.tsv`
- `metrics/taxonomy_comparison.tsv`
- `metrics/old_vs_new_ani.tsv`
- `figures/`

## Matched-depth downsample control

Submit the old-read downsampling job. It uses fixed seed `20261009` unless `SEED=` is overridden.

```bash
sbatch scripts/nb0507_14_resequencing_downsample.slurm
```

After downsampled reads exist, run SPAdes into the comparison stage:

```bash
sbatch \
  -o comparison_nb0507_14_resequencing/logs/slurm/downsampled_spades_%A_%a.out \
  -e comparison_nb0507_14_resequencing/logs/slurm/downsampled_spades_%A_%a.err \
  --export=ALL,MANIFEST_FILE=comparison_nb0507_14_resequencing/manifests/downsampled_old_assembly_manifest.tsv,STAGE_DIR=comparison_nb0507_14_resequencing/downsampled_old_assembly \
  --array=0-0 \
  scripts/spades_assembly_array.slurm

sbatch \
  -o comparison_nb0507_14_resequencing/logs/slurm/downsampled_spades_summary_%j.out \
  -e comparison_nb0507_14_resequencing/logs/slurm/downsampled_spades_summary_%j.err \
  --export=ALL,SPADES_MODE=summary,MANIFEST_FILE=comparison_nb0507_14_resequencing/manifests/downsampled_old_assembly_manifest.tsv,STAGE_DIR=comparison_nb0507_14_resequencing/downsampled_old_assembly \
  scripts/spades_assembly_array.slurm
```

Run downsampled old self-mapping and contig-level coverage/taxonomy:

```bash
sbatch \
  -o comparison_nb0507_14_resequencing/logs/slurm/downsampled_selfmap_%A_%a.out \
  -e comparison_nb0507_14_resequencing/logs/slurm/downsampled_selfmap_%A_%a.err \
  --export=ALL,MANIFEST_FILE=comparison_nb0507_14_resequencing/manifests/downsampled_old_self_mapping_manifest.tsv,STAGE_ROOT=comparison_nb0507_14_resequencing/downsampled_old_self_mapping \
  --array=0-0 \
  scripts/blobtoolkit_self_mapping_array.slurm

sbatch \
  -o comparison_nb0507_14_resequencing/logs/slurm/downsampled_addcov_%A_%a.out \
  -e comparison_nb0507_14_resequencing/logs/slurm/downsampled_addcov_%A_%a.err \
  --export=ALL,MANIFEST_FILE=comparison_nb0507_14_resequencing/manifests/downsampled_old_self_mapping_manifest.tsv,STAGE_ROOT=comparison_nb0507_14_resequencing/downsampled_old_self_mapping \
  --array=0-0 \
  scripts/blobtoolkit_add_self_coverage_array.slurm

sbatch \
  -o comparison_nb0507_14_resequencing/logs/slurm/downsampled_contig_kraken_%A_%a.out \
  -e comparison_nb0507_14_resequencing/logs/slurm/downsampled_contig_kraken_%A_%a.err \
  --export=ALL,MANIFEST_FILE=comparison_nb0507_14_resequencing/manifests/downsampled_old_self_mapping_manifest.tsv,STAGE_ROOT=comparison_nb0507_14_resequencing/downsampled_old_self_mapping \
  --array=0-0 \
  scripts/kraken2_contig_classify_array.slurm

python3 scripts/build_blobtoolkit_master_contig_tables.py \
  --manifest comparison_nb0507_14_resequencing/manifests/downsampled_old_self_mapping_manifest.tsv \
  --stage-root comparison_nb0507_14_resequencing/downsampled_old_self_mapping \
  --combined-output comparison_nb0507_14_resequencing/metrics/downsampled_old.master_contig_table.tsv
```

Optionally classify the downsampled read pair with Kraken2:

```bash
sbatch \
  -o comparison_nb0507_14_resequencing/logs/slurm/downsampled_read_kraken_%A_%a.out \
  -e comparison_nb0507_14_resequencing/logs/slurm/downsampled_read_kraken_%A_%a.err \
  --export=ALL,MANIFEST_FILE=comparison_nb0507_14_resequencing/manifests/downsampled_old_kraken2_manifest.tsv,STAGE_DIR=comparison_nb0507_14_resequencing/kraken2_downsampled_old \
  --array=0-0 \
  scripts/kraken2_classify_array.slurm

sbatch \
  -o comparison_nb0507_14_resequencing/logs/slurm/downsampled_read_kraken_summary_%j.out \
  -e comparison_nb0507_14_resequencing/logs/slurm/downsampled_read_kraken_summary_%j.err \
  --export=ALL,KRAKEN2_CLASSIFICATION_MODE=summary,MANIFEST_FILE=comparison_nb0507_14_resequencing/manifests/downsampled_old_kraken2_manifest.tsv,STAGE_DIR=comparison_nb0507_14_resequencing/kraken2_downsampled_old \
  scripts/kraken2_classify_array.slurm
```

## Old-vs-new assembly comparison

```bash
sbatch scripts/nb0507_14_resequencing_fastani.slurm
sbatch scripts/nb0507_14_resequencing_snp.slurm
```

After all jobs finish:

```bash
python3 scripts/summarize_nb0507_14_resequencing.py
module load R/gcc11/4.4.0
Rscript scripts/plot_nb0507_14_resequencing.R
```
