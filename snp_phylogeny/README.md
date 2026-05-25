# Within-project whole-genome SNP phylogeny

## Purpose

This branch builds a first-pass whole-genome SNP tree for only the three confirmed *Vibrio vulnificus* isolates:

- `Buck_BS0607_9` - vcgE
- `Buck_CB0707_82` - vcgC
- `Buck_NB0507_8` - vcgE

The immediate question is whether `Buck_BS0607_9` and `Buck_NB0507_8`, both vcgE, are also close genome-wide, and whether `Buck_CB0707_82`, vcgC, separates genome-wide.

This analysis is different from the vcg single-gene tree because it uses genome-wide SNPs from read mapping to the ATCC 27562 reference. The vcg tree summarizes one virulence-associated locus; the SNP tree summarizes many positions across the shared callable reference genome.

Mullis et al. data are intentionally excluded for now. This keeps the first pass focused on within-project sample relationships and avoids mixing external data before reference choice, read processing comparability, metadata, and batch effects are reviewed.

## Workflow

```text
trimmed reads -> BWA -> BAM -> FreeBayes -> SNP filtering -> core SNP alignment -> FastTree
```

## Inputs

- Manifest: `configs/snp_manifest.tsv`
- Trimmed paired reads: `trimmomatic/trimmed_reads/`
- Reference FASTA: `reference/v_vulnificus_ref.fasta`
  - Header identifies it as *Vibrio vulnificus* NBRC 15645 = ATCC 27562 chromosome 1.

## Scripts and Expected Outputs

| Step | Script | Expected output |
| --- | --- | --- |
| Prepare reference indexes | `scripts/prepare_snp_reference.sh` | `reference/v_vulnificus_ref.fasta.{amb,ann,bwt,pac,sa,fai}` and `snp_phylogeny/logs/prepare_snp_reference.log` |
| Align reads | `scripts/bwa_snp_align_array.slurm` | `snp_phylogeny/bam/<sample>.sorted.bam`, `.bai`, and `.flagstat.txt` |
| Call variants/reference sites | `scripts/freebayes_snp_call_array.slurm` | `snp_phylogeny/vcf/<sample>.freebayes.vcf` |
| Build core SNP alignment | `scripts/filter_snps_and_build_alignment.py` | `snp_phylogeny/core_alignment/core_snps.fasta` and `core_snp_summary.tsv` |
| Build tree | `scripts/build_snp_fasttree.sh` | `snp_phylogeny/tree/core_snps.fasttree.nwk` |

## Manual Run Commands

Run from the project root.

1. Validate or prepare reference indexes:

```bash
bash scripts/prepare_snp_reference.sh
```

2. Submit BWA alignment array after confirming the manifest has three samples:

```bash
wc -l configs/snp_manifest.tsv
sbatch --array=0-2 scripts/bwa_snp_align_array.slurm
```

3. After all alignment jobs complete, validate BAM outputs:

```bash
ls -lh snp_phylogeny/bam/*.sorted.bam snp_phylogeny/bam/*.sorted.bam.bai
ls -lh snp_phylogeny/bam/*.flagstat.txt
```

4. Submit FreeBayes array:

```bash
sbatch --array=0-2 scripts/freebayes_snp_call_array.slurm
```

5. After all FreeBayes jobs complete, validate VCF outputs:

```bash
ls -lh snp_phylogeny/vcf/*.freebayes.vcf
grep -L '^#CHROM' snp_phylogeny/vcf/*.freebayes.vcf
```

The second command should print nothing.

6. Build the core SNP alignment:

```bash
python3 scripts/filter_snps_and_build_alignment.py
```

7. Validate alignment before tree building:

```bash
grep -c '^>' snp_phylogeny/core_alignment/core_snps.fasta
wc -l snp_phylogeny/core_alignment/core_snp_summary.tsv
```

The FASTA should contain three sequences. The summary should contain at least one data row for a meaningful SNP tree.

8. Build the FastTree tree:

```bash
bash scripts/build_snp_fasttree.sh
```

## Validation Checkpoints

Before alignment:

- `configs/snp_manifest.tsv` contains exactly the three confirmed *V. vulnificus* isolates.
- Every `r1`, `r2`, and `reference_fasta` path in the manifest exists and is non-empty.
- The reference has BWA indexes and a samtools `.fai` index.

Before FreeBayes:

- Each sample has a sorted BAM and BAM index in `snp_phylogeny/bam/`.
- Each BAM passes `samtools quickcheck`.
- Alignment metrics are present in `snp_phylogeny/bam/*.flagstat.txt`.

Before SNP filtering:

- Each sample has a non-empty `snp_phylogeny/vcf/<sample>.freebayes.vcf`.
- VCFs were generated with `--report-monomorphic`; otherwise the Python script cannot distinguish reference calls from missing data at sites variable in another sample.

Before tree building:

- `snp_phylogeny/core_alignment/core_snps.fasta` contains all three samples.
- `snp_phylogeny/core_alignment/core_snp_summary.tsv` has retained SNP positions.

## Notes

This is a first-pass, within-project tree. It is not a global phylogeny and not a Mullis et al. comparative analysis. The FreeBayes script uses haploid bacterial settings, minimum coverage 10, minimum base quality 20, and minimum mapping quality 30. Filtering is intentionally simple at this stage and can be tightened after inspecting mapping and SNP counts.
