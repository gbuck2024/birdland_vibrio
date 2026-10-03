# SRA BWA-MEM Alignment Stage

This stage is prepared for single-reference BWA-MEM alignment of the six new SRA isolates against `reference/v_vulnificus_ref.fasta`.

## Inputs

- Manifest: `configs/alignment_manifest_sra.tsv`
- Paired trimmed reads: `trimmomatic/trimmed_reads/SRR*_L7_*_paired.fq.gz`
- Indexed reference: `reference/v_vulnificus_ref.fasta`

## Submit

Submit from the project root after confirming the manifest has six rows:

```bash
sbatch --export=ALL,MANIFEST_FILE=configs/alignment_manifest_sra.tsv,ALIGNMENT_DIR=alignment_sra --array=0-5 scripts/bwa_align_array.slurm
```

After the array completes, summarize the SRA stage:

```bash
ALIGNMENT_DIR=alignment_sra bash scripts/summarize_alignment_metrics.sh
```

## Expected Outputs

- `alignment_sra/bam/<sample_id>.sorted.bam`
- `alignment_sra/bam/<sample_id>.sorted.bam.bai`
- `alignment_sra/metrics/<sample_id>.flagstat.txt`
- `alignment_sra/metrics/<sample_id>.idxstats.txt`
- `alignment_sra/metrics/alignment_summary.tsv`

