# Ambiguous Isolate Resolution

This directory summarizes the three isolates that are outside the confirmed `Vibrio vulnificus` SNP phylogeny branch.

Confirmed `V. vulnificus` isolates used for exclusion:

- `Buck_BS0607_9`
- `Buck_CB0707_82`
- `Buck_NB0507_8`

The remaining three isolates identified from the existing manifests, trimmed-read paths, Kraken2 outputs, multi-reference alignment summaries, and assembly folders are:

- `Buck_BI0607_1`
- `Buck_BI0607_2`
- `Buck_NB0507_14`

No new compute-heavy jobs were run, and no `sbatch` jobs were submitted for this summary.

## Files

- `ambiguous_isolate_summary.tsv`: compact evidence table with one row per ambiguous/non-`vulnificus` isolate.
- `ambiguous_isolate_interpretation.md`: conservative interpretation, evidence sources, and missing evidence.

## Evidence Used

- `configs/kraken2_classification_manifest.tsv`
- `trimmomatic/metrics/trimmomatic_input_manifest.tsv`
- `trimmomatic/fastqc_trimmed/metrics/fastqc_trimmed_manifest.tsv`
- `configs/snp_manifest.tsv`
- `configs/assembly_manifest.tsv`
- `configs/ani_query_manifest.tsv`
- `configs/ani_query_manifest_subsampled_best_assemblies.tsv`
- `kraken2_classification/metrics/kraken2_classification_summary.tsv`
- `multi_reference_alignment/metrics/multi_reference_alignment_summary.tsv`
- `multi_reference_alignment/metrics/multi_reference_alignment_mapped_pct_matrix.tsv`
- `assembly/metrics/assembly_summary.tsv`
- `ani/subsampled_best_assemblies/metrics/ani_summary.tsv`
- `README.md`
- `WORK_COMPLETED.md`
- `NEXT_STEPS.md`
- `IN_PROGRESS.md`
- `DETAILED_WORKFLOW.md`
- `assembly/README.md`

## Missing Evidence

- Completed ANI results for `Buck_BI0607_1`, `Buck_BI0607_2`, and `Buck_NB0507_14` were not found in the completed ANI summary files.
- GTDB-Tk, CheckM, and BUSCO-style genome-quality outputs were not found.
- No broad Bacillus ANI or taxonomy confirmation results were found for `Buck_BI0607_2`.
