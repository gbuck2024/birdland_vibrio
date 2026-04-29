# Kraken2 Vibrio Read-Filtering Stage

This stage keeps only paired fragments classified by Kraken2 as `Vibrio` genus
or below for the three strongest current `Vibrio vulnificus` candidates:

- `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`
- `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`
- `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`

## Rationale

- The broad Kraken2 screen already supports these three samples as the strongest
  current `Vibrio vulnificus` candidates.
- The first-pass SPAdes assemblies and the 3-sample `--isolate` rerun remain
  inflated and fragmented, so the next comparison should reduce non-target read
  carry-through before reassembly.
- This stage preserves the original trimmed reads and writes filtered FASTQ
  files into a separate stage for reproducible reruns.

## Intended inputs

- `configs/kraken2_vibrio_filter_manifest.tsv`
- `trimmomatic/trimmed_reads/*_1_paired.fq.gz`
- `trimmomatic/trimmed_reads/*_2_paired.fq.gz`
- `kraken2_classification/outputs/*.kraken2.tsv`
- `kraken2_classification/reports/*.kreport.tsv`

## Filtering rule

- Retain paired fragments whose Kraken2 assigned taxid is `Vibrio` genus
  (`taxid 662`) or a descendant taxid under that genus in the saved sample
  report.
- Exclude unclassified pairs and any assignments above genus level, including
  broader `Vibrionaceae` calls that do not resolve to `Vibrio`.

## Intended outputs

- `kraken2_vibrio_read_filtering/filtered_reads/<sample_id>_1_paired.fq.gz`
- `kraken2_vibrio_read_filtering/filtered_reads/<sample_id>_2_paired.fq.gz`
- `kraken2_vibrio_read_filtering/metrics/<sample_id>.filtering_metrics.tsv`
- `kraken2_vibrio_read_filtering/metrics/kraken2_vibrio_filtering_summary.tsv`
- `kraken2_vibrio_read_filtering/logs/slurm/kraken2_vibrio_filter_<jobid>_<taskid>.out`
- `kraken2_vibrio_read_filtering/logs/slurm/kraken2_vibrio_filter_<jobid>_<taskid>.err`

## Submission notes

- Submit the filtering array with:
  `sbatch --array=0-2 scripts/kraken2_vibrio_filter_array.slurm`
- Generate the combined summary with:
  `sbatch --export=ALL,KRAKEN2_VIBRIO_FILTER_MODE=summary scripts/kraken2_vibrio_filter_array.slurm`
- The new stage intentionally does not overwrite `trimmomatic/trimmed_reads/`.
