# SRA SPAdes Assembly Stage

This stage is prepared for de novo SPAdes assembly of the six new SRA isolates. It is required before SRA self-mapping for GC-versus-coverage plots because self-mapping uses each isolate's own `contigs.fasta` as the BWA reference.

## Inputs

- Manifest: `configs/assembly_manifest_sra.tsv`
- Paired trimmed reads: `trimmomatic/trimmed_reads/SRR*_L7_*_paired.fq.gz`

## Submit

```bash
sbatch --export=ALL,MANIFEST_FILE=configs/assembly_manifest_sra.tsv,STAGE_DIR=assembly_sra --array=0-5 scripts/spades_assembly_array.slurm
```

After completion, summarize:

```bash
sbatch --export=ALL,SPADES_MODE=summary,MANIFEST_FILE=configs/assembly_manifest_sra.tsv,STAGE_DIR=assembly_sra scripts/spades_assembly_array.slurm
```

## Expected Outputs

- `assembly_sra/assemblies/<sample_id>/contigs.fasta`
- `assembly_sra/assemblies/<sample_id>/scaffolds.fasta`
- `assembly_sra/assemblies/<sample_id>/assembly_graph.fastg`
- `assembly_sra/metrics/assembly_summary.tsv`

