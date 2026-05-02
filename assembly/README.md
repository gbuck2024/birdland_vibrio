# Assembly Stage

This stage holds de novo SPAdes assemblies generated from the paired trimmed reads in `trimmomatic/trimmed_reads/`.

## Intended inputs

- `configs/assembly_manifest.tsv`
- `trimmomatic/trimmed_reads/*_1_paired.fq.gz`
- `trimmomatic/trimmed_reads/*_2_paired.fq.gz`

## Intended outputs

- `assembly/assemblies/<sample_id>/contigs.fasta`
- `assembly/assemblies/<sample_id>/scaffolds.fasta`
- `assembly/assemblies/<sample_id>/assembly_graph.fastg`
- `assembly/assemblies/<sample_id>/params.txt`
- `assembly/assemblies/<sample_id>/spades.log`
- `assembly/logs/slurm/spades_assembly_<jobid>_<taskid>.out`
- `assembly/logs/slurm/spades_assembly_<jobid>_<taskid>.err`
- `assembly/metrics/assembly_summary.tsv`

## Submission notes

- Submit one array task per manifest row with `sbatch --array=0-5 scripts/spades_assembly_array.slurm`.
- After the array finishes, generate the curated summary with `sbatch --export=ALL,SPADES_MODE=summary scripts/spades_assembly_array.slurm`.
- The array script uses paired trimmed reads only. Unpaired reads are intentionally excluded from the default workflow.
- The script now tries `SPADES_BIN` first, then common executable names (`spades.py`, `spades`), and then common module names (`spades`, `SPAdes`) after initializing environment modules in a non-interactive SLURM shell.
- If your HPC uses a different wrapper command, submit with an explicit override such as `sbatch --export=ALL,SPADES_BIN=/path/to/spades.py --array=0-5 scripts/spades_assembly_array.slurm`.
- The script can use a SPAdes Singularity or Apptainer image if one is available. Set `SPADES_SIF=/path/to/spades.sif` and optionally `CONTAINER_RUNTIME=apptainer` at submission time.
- If `SPADES_SIF` is unset, the script checks `containers/spades.sif` first and then falls back to `spades.sif` in the project root for older runs.

## Interpretation notes

- Assemble all 6 samples so species identity can be confirmed downstream from genome-level evidence.
- Review `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` with extra caution because earlier alignment and Kraken2 steps marked it as the strongest outlier for contamination, mislabeling, or non-target biology.
