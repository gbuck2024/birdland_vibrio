# BI0607_2 BlobToolKit Coverage Mapping

This stage prepares a self-contig read-mapping BAM for BlobToolKit coverage analysis of `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7`.

## Inputs

- Trimmed paired reads:
  - `trimmomatic/trimmed_reads/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7_1_paired.fq.gz`
  - `trimmomatic/trimmed_reads/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7_2_paired.fq.gz`
- Self assembly reference:
  - `assembly/assemblies/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7/contigs.fasta`

The BAM is intentionally mapped to the sample's own SPAdes `contigs.fasta`, not to an external reference genome. The script verifies this by comparing the coordinate-sorted BAM reference names from `samtools idxstats` against the SPAdes contig FASTA headers.

## Run

Submit from the project root:

```bash
sbatch scripts/blobtoolkit_bi0607_2_self_mapping.slurm
```

The script activates the existing BlobToolKit conda environment at `/home/glametrie1/.conda/envs/blobtoolkit`. It then loads the cluster `bwa/0.7.17` module only if `bwa` is not already available inside the active environment.

## Expected Outputs

- `bam/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7.self_contigs.mapped.bam`
- `bam/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7.self_contigs.sorted.bam`
- `bam/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7.self_contigs.sorted.bam.bai`
- `metrics/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7.self_contigs.quickcheck.txt`
- `metrics/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7.self_contigs.sorted.flagstat.txt`
- `metrics/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7.self_contigs.sorted.idxstats.txt`
- `metrics/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7.self_contigs.reference_name_check.txt`
- `metadata/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7.self_contigs.parameters.txt`

Do not interpret the stage as complete until `samtools quickcheck`, `samtools flagstat`, `samtools idxstats`, and the reference-name check all finish successfully.

## GC-Coverage Plots

The per-contig GC-content versus self-mapping coverage plots combine:

- `blobdir/identifiers.json`
- `blobdir/gc.json`
- `blobdir/length.json`
- `blobdir/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7.self_contigs.sorted_cov.json`
- `taxonomy/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7.spades_contigs.kraken2.tsv`

Regenerate from the project root with:

```bash
module load R/gcc11/4.4.0
Rscript scripts/plot_bi0607_2_gc_coverage.R
```

Expected outputs:

- `metrics/BI0607_2_gc_coverage_plot_data.tsv`
- `metrics/BI0607_2_gc_coverage_summary.tsv`
- `metrics/BI0607_2_gc_coverage_taxon_summary.tsv`
- `figures/BI0607_2_gc_coverage_linear.pdf`
- `figures/BI0607_2_gc_coverage_linear.png`
- `figures/BI0607_2_gc_coverage_log10.pdf`
- `figures/BI0607_2_gc_coverage_log10.png`

Use the log-scaled coverage plot as the primary view for population separation because the current coverage distribution spans several orders of magnitude.
