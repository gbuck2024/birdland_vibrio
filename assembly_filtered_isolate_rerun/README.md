# Filtered-Read Assembly Isolate Rerun Stage

This stage is reserved for the `--isolate` SPAdes rerun on the same three
priority samples after Kraken2-guided Vibrio read filtering:

- `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`
- `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`
- `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`

## Intended inputs

- `configs/assembly_manifest_vulnificus_candidates_filtered.tsv`
- `kraken2_vibrio_read_filtering/filtered_reads/*_1_paired.fq.gz`
- `kraken2_vibrio_read_filtering/filtered_reads/*_2_paired.fq.gz`

## Intended outputs

- `assembly_filtered_isolate_rerun/assemblies/<sample_id>/contigs.fasta`
- `assembly_filtered_isolate_rerun/assemblies/<sample_id>/scaffolds.fasta`
- `assembly_filtered_isolate_rerun/assemblies/<sample_id>/assembly_graph.fastg`
- `assembly_filtered_isolate_rerun/assemblies/<sample_id>/params.txt`
- `assembly_filtered_isolate_rerun/assemblies/<sample_id>/spades.log`
- `assembly_filtered_isolate_rerun/logs/slurm/spades_assembly_<jobid>_<taskid>.out`
- `assembly_filtered_isolate_rerun/logs/slurm/spades_assembly_<jobid>_<taskid>.err`
- `assembly_filtered_isolate_rerun/metrics/assembly_summary.tsv`

## Submission notes

- Submit the filtered-read rerun with:
  `sbatch --export=ALL,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered.tsv,STAGE_DIR=assembly_filtered_isolate_rerun --array=0-2 scripts/spades_assembly_array.slurm`
- Generate the filtered-read rerun summary with:
  `sbatch --export=ALL,SPADES_MODE=summary,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered.tsv,STAGE_DIR=assembly_filtered_isolate_rerun scripts/spades_assembly_array.slurm`
- The saved SPAdes script already defaults to `--isolate` unless `SPADES_EXTRA_ARGS` is explicitly overridden.
- Keep this stage separate from both `assembly/` and `assembly_isolate_rerun/` so all three assembly variants remain comparable.
