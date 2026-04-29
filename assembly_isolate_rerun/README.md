# Assembly Isolate Rerun Stage

This stage is reserved for the isolate-oriented SPAdes rerun on the three strongest
`Vibrio vulnificus` candidates:

- `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`
- `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`
- `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`

## Intended inputs

- `configs/assembly_manifest_vulnificus_candidates.tsv`
- `trimmomatic/trimmed_reads/*_1_paired.fq.gz`
- `trimmomatic/trimmed_reads/*_2_paired.fq.gz`

## Intended outputs

- `assembly_isolate_rerun/assemblies/<sample_id>/contigs.fasta`
- `assembly_isolate_rerun/assemblies/<sample_id>/scaffolds.fasta`
- `assembly_isolate_rerun/assemblies/<sample_id>/assembly_graph.fastg`
- `assembly_isolate_rerun/assemblies/<sample_id>/params.txt`
- `assembly_isolate_rerun/assemblies/<sample_id>/spades.log`
- `assembly_isolate_rerun/logs/slurm/spades_assembly_<jobid>_<taskid>.out`
- `assembly_isolate_rerun/logs/slurm/spades_assembly_<jobid>_<taskid>.err`
- `assembly_isolate_rerun/metrics/assembly_summary.tsv`

## Submission notes

- Submit the rerun with:
  `sbatch --export=ALL,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates.tsv,STAGE_DIR=assembly_isolate_rerun --array=0-2 scripts/spades_assembly_array.slurm`
- Generate the rerun summary with:
  `sbatch --export=ALL,SPADES_MODE=summary,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates.tsv,STAGE_DIR=assembly_isolate_rerun scripts/spades_assembly_array.slurm`
- The saved script now defaults to `--isolate` unless `SPADES_EXTRA_ARGS` is explicitly overridden at submission time.
- Keep this rerun separate from the original `assembly/` stage so the first-pass outputs remain available for comparison.
