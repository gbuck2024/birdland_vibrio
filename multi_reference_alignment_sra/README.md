# SRA Multi-Reference BWA-MEM Alignment Stage

This optional stage compares the six SRA isolates against the existing reference panel in `configs/multi_reference_reference_manifest.tsv`.

## Inputs

- Sample manifest: `configs/alignment_manifest_sra.tsv`
- Reference manifest: `configs/multi_reference_reference_manifest.tsv`
- Paired trimmed reads: `trimmomatic/trimmed_reads/SRR*_L7_*_paired.fq.gz`

## Submit

There are six samples and the current reference manifest has five references, so the expected array range is `0-29`.

```bash
sbatch \
  -o multi_reference_alignment_sra/logs/slurm/bwa_multiref_%A_%a.out \
  -e multi_reference_alignment_sra/logs/slurm/bwa_multiref_%A_%a.err \
  --export=ALL,SAMPLE_MANIFEST=configs/alignment_manifest_sra.tsv,REFERENCE_MANIFEST=configs/multi_reference_reference_manifest.tsv,STAGE_DIR=multi_reference_alignment_sra \
  --array=0-29 \
  scripts/bwa_align_multiref_array.slurm
```

After completion, summarize:

```bash
SAMPLE_MANIFEST=configs/alignment_manifest_sra.tsv REFERENCE_MANIFEST=configs/multi_reference_reference_manifest.tsv STAGE_DIR=multi_reference_alignment_sra python3 scripts/summarize_multiref_alignment_metrics.py
```

## Expected Outputs

- `multi_reference_alignment_sra/bam/<sample_id>__<reference_id>.sorted.bam`
- `multi_reference_alignment_sra/metrics/<sample_id>__<reference_id>.flagstat.txt`
- `multi_reference_alignment_sra/metrics/<sample_id>__<reference_id>.idxstats.txt`
- `multi_reference_alignment_sra/metrics/multi_reference_alignment_summary.tsv`
- `multi_reference_alignment_sra/metrics/multi_reference_alignment_mapped_pct_matrix.tsv`
