# NB0507-14 original versus nominal 25×: Fig. 2 source review

## Biological question and inputs

How do contig GC, self-mapping coverage, and provisional Kraken2 assignments differ between the original full trimmed-read assembly and a nominal 25× subset of that same old Buck sequencing run? These are correlated assemblies, not biological replicates. No heavy computation was rerun for this review.

| Condition | Existing plot (PDF; matching PNG beside it) | Contig-level source |
|---|---|---|
| Original full trimmed reads | `ani/abrcms_poster/ani/gc_coverage_kraken_full_20261111/NB0507_14 at full depth.pdf` | `ambiguous_isolate_resolution/blobtoolkit/NB0507_14/metrics/NB0507_14.master_contig_table.tsv` |
| Nominal 25× | `ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111/figures/selected_gc_coverage_20261112/NB0507_14 at 25x.pdf` | `ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111/postassembly/NB0507_14_25x/metrics/NB0507_14_25x.master_contig_table.tsv` |

The two plot manifests are `configs/abrcms_poster_gc_coverage_full_manifest.tsv` and `configs/abrcms_poster_gc_coverage_selected_20261112.tsv`. Both use `scripts/plot_poster_gc_coverage_kraken.R`. The 25× source reads are the paired files named in `configs/abrcms_poster_depth_20261111_blob.tsv`, sampled from the original trimmed reads with seed 20261111. The audited 25× input has 436,242 read pairs and 130,516,674 sequenced bases, or 25.0994 bases per assumed 5.2 Mb genome (`metrics/read_bases_and_depth.tsv`). This ratio is not mapped depth.

## Method comparability and limits

Both master tables were built with `scripts/build_blobtoolkit_master_contig_tables.py` from BlobToolKit contig GC/length and `blobtools add --cov` on a BWA-MEM self-mapped BAM. The original maps its full trimmed read pair to its original SPAdes contigs; 25× maps its sampled pair to its 25× SPAdes contigs. Thus coverage has the same calculation and units, but different read depth and reference contigs. It is assembly-derived support, not a fixed-reference measure or independent validation. Plot y is log10-scaled **coverage** (not the table's `log10(coverage + 1)` field); zero-coverage contigs are omitted. Point size maps to contig length.

Both Kraken2 parameter records specify `kraken2_db/db`, `containers/kraken2.sif`, eight threads, memory mapping, and no extra arguments. Both classify SPAdes contigs and use the same broad-label parsing code. Database checksums or a version snapshot are not recorded in those parameter files, so exact database identity across run dates cannot be independently verified from this provenance. Kraken2 labels are provisional, and the categories are contig labels weighted below by assembled bases, not read-level abundance.

## Observations

The following values were recalculated by grouping every row of the two source master tables by `broad_taxon` and `taxon_label`, summing `length_bp`, and dividing by each table's total assembled bp. All contigs are included in the composition denominators, including those omitted from the scatterplots for zero coverage.

| Measure | Original | Nominal 25× |
|---|---:|---:|
| Contigs / assembled bp | 72,565 / 46,406,154 bp | 6,113 / 8,012,250 bp |
| Positive-coverage contigs plotted | 72,155 | 6,095 |
| Zero-coverage contigs omitted | 410 | 18 |
| Positive self-coverage range | 0.2208–8,018.6937× | 0.5263–642.359× |
| Vibrio | 19,066,399 bp (41.086%) | 6,479,686 bp (80.872%) |
| Reyranella | 5,668,309 bp (12.215%) | 285,079 bp (3.558%) |
| Bacillus | 1,807,080 bp (3.894%) | 2,094 bp (0.026%) |
| Other classified | 10,746,188 bp (23.157%) | 699,894 bp (8.735%) |
| Unclassified | 9,118,178 bp (19.649%) | 545,497 bp (6.808%) |

| Kraken2 contig label | Original assembled bp (% of original) | 25× assembled bp (% of 25×) |
|---|---:|---:|
| *Vibrio diabolicus* (taxid 50719) | 4,587,529 (9.886%) | 4,854,121 (60.584%) |
| *Reyranella* sp. (taxid 1929291) | 5,668,309 (12.215%) | 285,079 (3.558%) |
| *Vibrio vulnificus* (taxid 672) | 3,741,050 (8.062%) | 11,998 (0.150%) |
| Unclassified (taxid 0) | 8,639,292 (18.617%) | 517,031 (6.453%) |
| *Vibrio natriegens* (taxid 691) | 101,613 (0.219%) | 533,026 (6.653%) |

The original top named classified label by assembled bp is *Reyranella* sp.; the 25× top label is *V. diabolicus*. The original unclassified taxid-0 label has more bp than any named label. The original assembly contains more *V. diabolicus*-labeled bp in the 25× condition than in the original despite much smaller total span, showing that assembler fragmentation and label assignment can change non-monotonically. These results do not demonstrate contaminant removal, species identity, or biological absence.

## Fig. 2 recommendation

Use the two existing per-contig master tables as the source for one new two-panel vector figure, with the original at left and nominal 25× at right. Use one shared GC axis and one shared log10 coverage axis (for example 0.1–10,000×) so positions mean the same thing in both panels; keep the five broad Kraken2 colors fixed. The current individual PDFs use automatic per-plot scales, so placing them together unchanged would not establish identical scales. The full common range will compress the 25× points near the lower end and the original has severe overplotting (72,155 versus 6,095 points); use smaller transparent points or a density treatment, and consider a labeled low-coverage inset if poster legibility requires it. Give the two panels separate contig-count and assembled-bp annotations, and define nominal 25× in the caption as sampled bases per assumed genome. State that both y values are self-mapping coverage to different assemblies, and that Kraken2 colors are provisional. Do not infer contaminant removal from the apparent composition shift.

Next validation before species or cleaning claims: pin the Kraken2 database checksum/version, examine alternative reference and independent read evidence, and compare assembly-aware and fixed-reference coverage. The existing exact-depth validation report should be consulted for independent assembly QC.
