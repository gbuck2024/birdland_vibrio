# SRA BlobToolKit Self-Mapping Preparation

This stage is prepared for self-contig BWA-MEM mapping of the six new SRA isolates for later GC-versus-coverage plots.

Self-mapping is not runnable until SRA SPAdes assemblies exist under `assembly_sra/assemblies/<sample_id>/contigs.fasta`.

## Inputs

- Manifest: `configs/blobtoolkit_self_mapping_manifest_sra.tsv`
- Paired trimmed reads: `trimmomatic/trimmed_reads/SRR*_L7_*_paired.fq.gz`
- Self references: `assembly_sra/assemblies/<sample_id>/contigs.fasta`

## Submit

After `assembly_sra` contigs exist, submit from the project root:

```bash
sbatch \
  -o ambiguous_isolate_resolution/blobtoolkit_sra/logs/slurm/self_mapping_%A_%a.out \
  -e ambiguous_isolate_resolution/blobtoolkit_sra/logs/slurm/self_mapping_%A_%a.err \
  --export=ALL,MANIFEST_FILE=configs/blobtoolkit_self_mapping_manifest_sra.tsv,STAGE_ROOT=ambiguous_isolate_resolution/blobtoolkit_sra \
  --array=0-5 \
  scripts/blobtoolkit_self_mapping_array.slurm
```

## Expected Outputs

- `ambiguous_isolate_resolution/blobtoolkit_sra/<short_id>/bam/<sample_id>.self_contigs.sorted.bam`
- `ambiguous_isolate_resolution/blobtoolkit_sra/<short_id>/metrics/<sample_id>.self_contigs.sorted.flagstat.txt`
- `ambiguous_isolate_resolution/blobtoolkit_sra/<short_id>/metrics/<sample_id>.self_contigs.sorted.idxstats.txt`
- `ambiguous_isolate_resolution/blobtoolkit_sra/<short_id>/metadata/<sample_id>.self_contigs.parameters.txt`

## Add BlobToolKit Coverage Values

After self-mapping completes, create BlobToolKit blobdirs and add per-contig coverage:

```bash
sbatch \
  -o ambiguous_isolate_resolution/blobtoolkit_sra/logs/slurm/add_self_coverage_%A_%a.out \
  -e ambiguous_isolate_resolution/blobtoolkit_sra/logs/slurm/add_self_coverage_%A_%a.err \
  --export=ALL,MANIFEST_FILE=configs/blobtoolkit_self_mapping_manifest_sra.tsv,STAGE_ROOT=ambiguous_isolate_resolution/blobtoolkit_sra \
  --array=0-5 \
  scripts/blobtoolkit_add_self_coverage_array.slurm
```

## Classify SPAdes Contigs With Kraken2

```bash
sbatch \
  -o ambiguous_isolate_resolution/blobtoolkit_sra/logs/slurm/kraken2_contigs_%A_%a.out \
  -e ambiguous_isolate_resolution/blobtoolkit_sra/logs/slurm/kraken2_contigs_%A_%a.err \
  --export=ALL,MANIFEST_FILE=configs/blobtoolkit_self_mapping_manifest_sra.tsv,STAGE_ROOT=ambiguous_isolate_resolution/blobtoolkit_sra \
  --array=0-5 \
  scripts/kraken2_contig_classify_array.slurm
```

## Build Master Contig Tables

After coverage JSON and contig Kraken2 outputs exist:

```bash
python3 scripts/build_blobtoolkit_master_contig_tables.py \
  --manifest configs/blobtoolkit_self_mapping_manifest_sra.tsv \
  --stage-root ambiguous_isolate_resolution/blobtoolkit_sra \
  --combined-output ambiguous_isolate_resolution/blobtoolkit_sra/metrics/all_samples.master_contig_table.tsv
```

## Plot GC x Coverage

Broad taxon plots:

```bash
module load R/gcc11/4.4.0
MASTER_CONTIG_TABLE=ambiguous_isolate_resolution/blobtoolkit_sra/metrics/all_samples.master_contig_table.tsv \
BLOBTOOLKIT_DIR=ambiguous_isolate_resolution/blobtoolkit_sra \
Rscript scripts/plot_blobtoolkit_gc_coverage_all_samples.R
```

Top species-highlight plots:

```bash
module load R/gcc11/4.4.0
MASTER_CONTIG_TABLE=ambiguous_isolate_resolution/blobtoolkit_sra/metrics/all_samples.master_contig_table.tsv \
BLOBTOOLKIT_DIR=ambiguous_isolate_resolution/blobtoolkit_sra \
Rscript scripts/plot_blobtoolkit_gc_coverage_top_species.R
```
