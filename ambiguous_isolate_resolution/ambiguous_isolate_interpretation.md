# Ambiguous Isolate Interpretation

## Scope

This report keeps `Buck_BI0607_1`, `Buck_BI0607_2`, and `Buck_NB0507_14` separate from the confirmed `Vibrio vulnificus` SNP phylogeny branch. The confirmed branch is defined by `configs/snp_manifest.tsv` and contains only `Buck_BS0607_9`, `Buck_CB0707_82`, and `Buck_NB0507_8`.

All interpretations below use existing evidence only. No new classification, assembly, ANI, or SLURM jobs were run.

## Summary Interpretation

`Buck_BI0607_1` is best treated as a likely non-`vulnificus Vibrio` isolate with possible mixed-sample or contamination signal. Kraken2 reports `Vibrio` as the top genus at `92.11%` and `Vibrio cidicii` as the top species at `60.85%`. Multi-reference mapping is not a clean species confirmation: the best tested reference is `v_vulnificus` at only `30.57%`. The primary SPAdes assembly is extremely inflated (`49,561,016 bp`) and fragmented (`84,400` contigs, N50 `695`), which is not consistent with a clean single Vibrio isolate assembly.

`Buck_BI0607_2` is best treated as likely non-Vibrio or a contaminated/mislabeled sample. Kraken2 reports `Bacillus` as the top genus at `90.73%`, while the top species call, `Bacillus paralicheniformis`, is only `19.90%`, indicating a strong genus-level Bacillus signal but weak species resolution. Multi-reference mapping to the tested Vibrio references is essentially background, with the best value only `1.07%` to `v_parahaemolyticus`. Its assembly is also inflated and fragmented (`34,165,342 bp`, `49,312` contigs), supporting contamination, mixed sample, or non-target biology.

`Buck_NB0507_14` remains an ambiguous Vibrio isolate. Kraken2 reports `Vibrio` as the top genus at `52.08%`, but the top species, `Vibrio diabolicus`, is only `14.03%`, with prior summaries flagging weak species-level support. Multi-reference mapping favors `v_alginolyticus` at `43.84%`, followed by `v_parahaemolyticus` at `31.18%`, and only `10.86%` to `v_vulnificus`. Its assembly is inflated and fragmented (`46,406,154 bp`, `72,565` contigs), so a mixed sample or contamination remains plausible.

## Evidence Used

Sample identity and separation from the SNP branch:

- `configs/snp_manifest.tsv`: contains only `Buck_BS0607_9`, `Buck_CB0707_82`, and `Buck_NB0507_8`.
- `configs/kraken2_classification_manifest.tsv`: lists all six post-trim read pairs, including the three ambiguous isolates.
- `configs/assembly_manifest.tsv`: lists all six primary SPAdes assembly inputs, including the three ambiguous isolates.
- `trimmomatic/metrics/trimmomatic_input_manifest.tsv` and `trimmomatic/fastqc_trimmed/metrics/fastqc_trimmed_manifest.tsv`: confirm paired read organization for the three ambiguous isolates.

Taxonomy and alignment:

- `kraken2_classification/metrics/kraken2_classification_summary.tsv`: source for top genus, top species, percentages, classification flags, and short interpretations.
- `multi_reference_alignment/metrics/multi_reference_alignment_summary.tsv`: source for per-reference mapped read percentages and detailed mapping metrics.
- `multi_reference_alignment/metrics/multi_reference_alignment_mapped_pct_matrix.tsv`: compact source for best tested mapping reference and percentage.

Assembly:

- `assembly/metrics/assembly_summary.tsv`: source for total assembly length, contig count, N50, and GC percentage.
- `assembly/assemblies/Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7/`
- `assembly/assemblies/Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7/`
- `assembly/assemblies/Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7/`

Previous reports:

- `README.md`: already records `Buck_BI0607_1` as likely non-`vulnificus Vibrio`, `Buck_NB0507_14` as genus-level species-ambiguous Vibrio, and `Buck_BI0607_2` as Bacillus-dominated.
- `WORK_COMPLETED.md`, `NEXT_STEPS.md`, `IN_PROGRESS.md`, and `DETAILED_WORKFLOW.md`: contain prior conservative notes consistent with the evidence summarized here.

ANI:

- `configs/ani_query_manifest.tsv` includes all six primary assemblies as planned ANI queries.
- `ani/subsampled_best_assemblies/metrics/ani_summary.tsv` contains completed ANI summaries only for `Buck_BS0607_9`, `Buck_CB0707_82`, and `Buck_NB0507_8`.
- No completed ANI summary rows were found for `Buck_BI0607_1`, `Buck_BI0607_2`, or `Buck_NB0507_14`; ANI fields are therefore recorded as `NA` in `ambiguous_isolate_summary.tsv`.

## Recommended Next Steps

Keep all three isolates out of the confirmed `V. vulnificus` SNP phylogeny branch unless independent evidence changes their status.

For `Buck_BI0607_1` and `Buck_NB0507_14`, run ANI against a broader Vibrio reference set and pair it with GTDB-Tk plus CheckM or BUSCO-style QC to assess both taxonomy and genome quality.

For `Buck_BI0607_2`, first verify sample provenance and treat it as a likely non-Vibrio or contaminated/mislabeled sample. If it remains analytically relevant, run broad taxonomy/genome-quality QC rather than Vibrio-focused phylogenetics.
