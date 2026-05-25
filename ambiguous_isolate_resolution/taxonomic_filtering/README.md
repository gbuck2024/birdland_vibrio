# Taxonomic Filtering and Reassembly for Ambiguous Isolates

This branch tests whether the three ambiguous/non-vulnificus isolates can be resolved by keeping read pairs with Kraken2 evidence for the dominant target genus, then reassembling only those reads. It is intentionally separate from the confirmed `V. vulnificus` SNP phylogeny branch and does not modify `snp_phylogeny/`.

## Rationale

The original assemblies for these samples are far larger and more fragmented than expected for a clean bacterial isolate:

- `Buck_BI0607_1`: about 49.6 Mb and about 84,400 contigs
- `Buck_BI0607_2`: about 34.2 Mb and about 49,312 contigs
- `Buck_NB0507_14`: about 46.4 Mb and about 72,565 contigs

A clean `Vibrio` or `Bacillus` isolate assembly is usually roughly 4-6 Mb. Kraken-guided filtering is more appropriate than random 50% downsampling for mixed samples because it preferentially retains reads associated with the biological target instead of preserving the same mixed taxonomic proportions at lower depth.

## Targets

| Sample | Target taxon | Target taxid | Filter mode | Downsample pairs |
| --- | --- | ---: | --- | ---: |
| `Buck_BI0607_1` | `Vibrio` | 662 | genus | 1000000 |
| `Buck_NB0507_14` | `Vibrio` | 662 | genus | 1000000 |
| `Buck_BI0607_2` | `Bacillus` | 1386 | genus | 1000000 |

## Workflow

Trimmed paired reads:

`trimmomatic/trimmed_reads/*_1_paired.fq.gz`
`trimmomatic/trimmed_reads/*_2_paired.fq.gz`

Existing Kraken2 per-read classifications:

`kraken2_classification/outputs/*.kraken2.tsv`

Processing:

1. Extract read IDs with target-taxon evidence from the existing Kraken2 output.
2. Keep a read pair if the shared pair ID has target evidence.
3. Downsample retained pairs to `downsample_pairs` with a fixed random seed if needed.
4. Reassemble downsampled pairs with SPAdes.
5. Summarize assembly size, fragmentation, N50, largest contig, and GC percentage.
6. Interpret whether the reassembly collapses toward a plausible bacterial genome size.

## Scripts

- `configs/taxon_filter_manifest.tsv`: manifest for the three ambiguous isolates.
- `scripts/filter_fastq_by_kraken_taxon.py`: streams paired FASTQ files and keeps pairs with Kraken2 target-taxid evidence.
- `scripts/filter_taxon_reads_array.slurm`: SLURM array wrapper for taxon filtering.
- `scripts/downsample_paired_fastq.py`: Python fallback for reproducible paired downsampling.
- `scripts/downsample_taxon_filtered_reads_array.slurm`: SLURM array wrapper for downsampling.
- `scripts/spades_taxon_filtered_array.slurm`: SLURM array wrapper for SPAdes reassembly using `containers/spades.sif` when present.
- `scripts/summarize_taxon_filtered_assemblies.py`: creates the final assembly metrics table.

## Expected Outputs

- `read_ids/{sample}.{taxon}.read_ids.txt`
- `filtered_reads/{sample}.{taxon}.R1.filtered.fq.gz`
- `filtered_reads/{sample}.{taxon}.R2.filtered.fq.gz`
- `downsampled_reads/{sample}.{taxon}.R1.downsampled.fq.gz`
- `downsampled_reads/{sample}.{taxon}.R2.downsampled.fq.gz`
- `assemblies/{sample}_{taxon}/contigs.fasta`
- `assemblies/{sample}_{taxon}/scaffolds.fasta`
- `metrics/{sample}.{taxon}.filter_summary.tsv`
- `metrics/taxon_filtered_assembly_summary.tsv`

## Manual Commands

Do not submit these until ready.

```bash
sbatch --array=0-2 scripts/filter_taxon_reads_array.slurm
```

After filtering finishes:

```bash
ls -lh ambiguous_isolate_resolution/taxonomic_filtering/filtered_reads/
cat ambiguous_isolate_resolution/taxonomic_filtering/metrics/*.filter_summary.tsv
```

Then:

```bash
sbatch --array=0-2 scripts/downsample_taxon_filtered_reads_array.slurm
sbatch --array=0-2 scripts/spades_taxon_filtered_array.slurm
python3 scripts/summarize_taxon_filtered_assemblies.py
```

## Interpretation

The final summary labels an assembly as near expected bacterial genome size when total assembly length is 4-6.5 Mb and contig count is substantially lower than the original inflated assembly. Assemblies still above 10 Mb or still highly fragmented are interpreted as likely mixed or contaminated. Very small assemblies suggest that too few target reads were retained or that target recovery was incomplete.

## Limitations

- Kraken2 classifications depend on database content and database age.
- Genus-level filtering can still retain mixed species within the same genus.
- The filter uses conservative target evidence from exact assigned taxid labels and target taxid tokens in the Kraken2 k-mer field; it does not reconstruct a full NCBI taxonomy tree.
- This branch does not prove pure isolate identity by itself.
- Follow-up ANI, GTDB-Tk, CheckM, or additional contamination screening may still be needed.
