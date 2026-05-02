# Kraken2-Filtered Vibrio Subsampled-Read Stage

This stage is reserved for fixed-depth paired-read subsets from the completed
Kraken2-filtered `Vibrio` read sets for the three strongest current
`Vibrio vulnificus` candidates:

- `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`
- `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`
- `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`

## Rationale

- The filtered-read `--isolate` rerun still produced inflated assemblies
  relative to an expected `5.2 Mb` isolate genome.
- The retained filtered read sets remain extremely deep, so a controlled
  downsampling test is justified before moving into ANI, annotation, or gene
  mining.
- This stage keeps the original filtered FASTQ files untouched and writes each
  subsampled pair set into its own new stage-specific directory.

## Target coverage assumptions

- Genome size assumption: `5,200,000 bp`
- Read length assumption: `149 bp` per mate
- Paired-end bases per read pair: `298 bp`
- Target read pairs:
  - `25x`: `436,242`
  - `50x`: `872,483`
  - `100x`: `1,744,966`

## Intended inputs

- `configs/kraken2_vibrio_subsample_manifest.tsv`
- `kraken2_vibrio_read_filtering/filtered_reads/*_1_paired.fq.gz`
- `kraken2_vibrio_read_filtering/filtered_reads/*_2_paired.fq.gz`

## Intended outputs

- `kraken2_vibrio_subsampled_reads/subsampled_reads/<subsample_id>_1_paired.fq.gz`
- `kraken2_vibrio_subsampled_reads/subsampled_reads/<subsample_id>_2_paired.fq.gz`
- `kraken2_vibrio_subsampled_reads/metrics/<subsample_id>.subsampling_metrics.tsv`
- `kraken2_vibrio_subsampled_reads/metrics/subsampling_summary.tsv`
- `kraken2_vibrio_subsampled_reads/logs/slurm/vibrio_subsample_<jobid>_<taskid>.out`
- `kraken2_vibrio_subsampled_reads/logs/slurm/vibrio_subsample_<jobid>_<taskid>.err`

## Recorded fields

- `sample_id`
- `subsample_id`
- `target_coverage`
- `genome_size_assumption`
- `read_length_assumption`
- `target_read_pairs`
- `actual_read_pairs`
- `seed`
- `input_read1`
- `input_read2`
- `output_read1`
- `output_read2`

## Submission notes

- Submit the 9-task subsampling array with:
  `sbatch --array=0-8 scripts/subsample_vibrio_reads_array.slurm`
- Generate the combined metrics summary with:
  `sbatch --export=ALL,SUBSAMPLE_MODE=summary scripts/subsample_vibrio_reads_array.slurm`
- The reusable subsampling script preserves R1/R2 synchronization by reading
  both FASTQ files in lockstep and writing only matched pair indexes selected
  from a seeded random sample.
