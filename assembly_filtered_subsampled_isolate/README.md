# Filtered-Read Subsampled Isolate Assembly Stage

This stage is reserved for `SPAdes --isolate` assemblies on the new fixed-depth
subsampled FASTQ pairs derived from the completed Kraken2-filtered `Vibrio`
reads for the same three priority samples.

## Intended inputs

- `configs/assembly_manifest_vulnificus_candidates_filtered_subsampled.tsv`
- `kraken2_vibrio_subsampled_reads/subsampled_reads/*_1_paired.fq.gz`
- `kraken2_vibrio_subsampled_reads/subsampled_reads/*_2_paired.fq.gz`

## Depth-specific subsets

- `25x`
- `50x`
- `100x`

Each manifest row uses a derived sample identifier such as
`Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7_25x` so each assembly remains
traceable to both the original sample and the target depth.

## Intended outputs

- `assembly_filtered_subsampled_isolate/assemblies/<sample_id>/contigs.fasta`
- `assembly_filtered_subsampled_isolate/assemblies/<sample_id>/scaffolds.fasta`
- `assembly_filtered_subsampled_isolate/assemblies/<sample_id>/assembly_graph.fastg`
- `assembly_filtered_subsampled_isolate/assemblies/<sample_id>/params.txt`
- `assembly_filtered_subsampled_isolate/assemblies/<sample_id>/spades.log`
- `assembly_filtered_subsampled_isolate/logs/slurm/spades_assembly_<jobid>_<taskid>.out`
- `assembly_filtered_subsampled_isolate/logs/slurm/spades_assembly_<jobid>_<taskid>.err`
- `assembly_filtered_subsampled_isolate/metrics/assembly_summary.tsv`

## Submission notes

- Submit the 9-task assembly array with:
  `sbatch --export=ALL,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered_subsampled.tsv,STAGE_DIR=assembly_filtered_subsampled_isolate --array=0-8 scripts/spades_assembly_array.slurm`
- Generate the combined assembly summary with:
  `sbatch --export=ALL,SPADES_MODE=summary,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered_subsampled.tsv,STAGE_DIR=assembly_filtered_subsampled_isolate scripts/spades_assembly_array.slurm`
- The saved SPAdes workflow already defaults to `--isolate` unless
  `SPADES_EXTRA_ARGS` is explicitly overridden.
