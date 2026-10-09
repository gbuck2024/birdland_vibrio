# NB0507-14 matched-isolate resequencing comparison

This comparison treats `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` and `SRR37852095_L7` as the same biological isolate sequenced in different runs. Existing raw/post-trim FastQC, Trimmomatic, SPAdes, self-contig mapping, BlobToolKit-style contig tables, and Kraken2 outputs were summarized without overwriting prior stages.

## Current interpretation

- Same-isolate identity remains provisional because the stage-specific reciprocal FastANI and whole-genome SNP jobs are prepared but not yet run.
- The matched-depth control is pending SLURM execution; current A-vs-C differences still confound sequencing depth with run quality.
- Read taxonomy reproduces the same broad identity: old dominant genus `Vibrio` at `52.08%`; new dominant genus `Vibrio` at `98.66%`.
- The new run is much smaller but cleaner by Kraken2 read purity: old unclassified `43.09%`; new unclassified `0.63%`.
- Assembly contiguity is much stronger for the new run before depth control: old N50 `874` bp with `72565` contigs; new N50 `556107` bp with `102` contigs.
- Coverage uniformity by contig mean favors the lower-CV condition: old CV `3.4898`; new CV `1.6761`.

Per-base low/high coverage percentages were not inferred from external BWA reference mappings. They are contig-length-weighted summaries from each sample's self-mapping master contig table and should be interpreted as contig-mean coverage diagnostics, not pileup-level breadth.

## Required follow-up before final biological conclusion

Run `scripts/nb0507_14_resequencing_downsample.slurm` for the matched-depth old control, `scripts/nb0507_14_resequencing_fastani.slurm` for reciprocal FastANI, and `scripts/nb0507_14_resequencing_snp.slurm` for whole-genome alignment/SNP counting. Then rerun this summarizer.
