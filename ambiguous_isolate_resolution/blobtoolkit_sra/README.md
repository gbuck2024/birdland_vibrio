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
sbatch --export=ALL,MANIFEST_FILE=configs/blobtoolkit_self_mapping_manifest_sra.tsv,STAGE_ROOT=ambiguous_isolate_resolution/blobtoolkit_sra --array=0-5 scripts/blobtoolkit_self_mapping_array.slurm
```

## Expected Outputs

- `ambiguous_isolate_resolution/blobtoolkit_sra/<short_id>/bam/<sample_id>.self_contigs.sorted.bam`
- `ambiguous_isolate_resolution/blobtoolkit_sra/<short_id>/metrics/<sample_id>.self_contigs.sorted.flagstat.txt`
- `ambiguous_isolate_resolution/blobtoolkit_sra/<short_id>/metrics/<sample_id>.self_contigs.sorted.idxstats.txt`
- `ambiguous_isolate_resolution/blobtoolkit_sra/<short_id>/metadata/<sample_id>.self_contigs.parameters.txt`

