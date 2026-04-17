# Next Steps

## 2026-03-27 FastQC extraction and interpretation

- Build a reusable SLURM array script for paired-end trimming with adapter clipping and quality-tail trimming.
- Preserve read pairing and write trimmed outputs plus stdout/stderr logs into new step-specific directories.
- After trimming, rerun FastQC and compare reverse-read PolyG, GC-content, and overrepresented-sequence behavior before proceeding to SPAdes.

## 2026-03-28 Trimmomatic ready for submission

- Submit `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/trimmomatic_array.slurm` with `sbatch --array=0-5` so each copied sample pair is trimmed once.
- Check job status and the first SLURM stdout/stderr files in `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/logs/slurm` within 1-2 minutes of submission.
- Verify that paired and unpaired outputs are written for each sample under the `trimmomatic` step directory before starting post-trim FastQC.
- Run FastQC on the trimmed paired reads and compare reverse-read PolyG, per-base quality, and adapter content against the pre-trim FastQC review.
## 2026-04-09 Post-trim FastQC extraction and interpretation

- Build a reusable SLURM assembly workflow for the six trimmed paired-end samples, preferably as an array job with per-sample stdout/stderr logs.
- Run SPAdes on `trimmomatic/trimmed_reads/*_paired.fq.gz` and capture assembly metrics into a new step-specific directory.
- Review assembly size, contig count, N50, and coverage-related metrics before proceeding to annotation and gene-target analysis.

## 2026-04-12 Alignment review completed

- Prioritize de novo assembly on all 6 trimmed paired samples because reference-based alignment rates vary sharply across isolates, from `1.05%` to `88.12%`.
- Treat `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` and `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` as reference-mismatch outliers because they show both low mapped-read percentages and very poor proper-pairing rates against the current `Vibrio vulnificus` reference.
- Build additional reference-alignment tests against other candidate Vibrio species, especially `Vibrio alginolyticus` and `Vibrio parahaemolyticus`, to determine whether the poorly paired samples map more cleanly to a different species-level reference.
- Compare mapped percentage, properly paired percentage, and contig-level `idxstats` distributions across the alternative references before deciding whether those samples belong in the same downstream reference-based analysis set.
- If reference-based analysis continues for the strongest current matches, start with `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, which all show high mapping and strong proper-pairing against the present reference.
- Submit or prepare the SPAdes stage next, keeping outputs in a new assembly-specific directory and documenting all parameters used.

## 2026-04-13 Multi-reference alignment review completed

- Use `multi_reference_alignment/metrics/multi_reference_alignment_summary.tsv` and `multi_reference_alignment/metrics/multi_reference_alignment_mapped_pct_matrix.tsv` as the decision point for the next biological split in the workflow.
- Prioritize de novo assembly for all 6 trimmed paired samples so downstream annotation, gene mining, and phylogenetics do not depend on a single reference species assumption.
- Treat `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, and likely `Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` as the strongest current `Vibrio vulnificus` candidates for any optional follow-up reference-based analysis.
- Treat `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` as a likely non-`Vibrio vulnificus` isolate or mixed-signal sample because it maps best to `Vibrio alginolyticus` rather than the current `Vibrio vulnificus` reference.
- Flag `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` for extra scrutiny during assembly and annotation because its mapped-read percentage stays near `1%` across all tested references, consistent with severe reference mismatch, contamination, or low-complexity data.
- Prepare the SPAdes stage next in a new assembly-specific directory with a reusable SLURM script, saved parameters, and an explicit manifest so the step is ready for cluster submission without running heavy work on the login node.

## 2026-04-14 Kraken2 bacteria database prepared for submission

- Stage a Singularity image with `kraken2-build` available and submit `scripts/kraken2_build_bacterial_db.slurm` from the project root when cluster resources and storage quota are confirmed.
- Review `kraken2_db/README.md` before submission and adjust `KRAKEN2_SIF`, `MIN_PROJECT_FREE_GB`, `MIN_TMP_FREE_GB`, or `KRAKEN2_CLEAN_AFTER_BUILD` only if local HPC policy or quota requires different guardrails.
- After the build finishes, confirm that `kraken2_db/db/hash.k2d`, `kraken2_db/db/opts.k2d`, and `kraken2_db/db/taxo.k2d` exist and inspect the small text records in `kraken2_db/metadata/` for recorded parameters and disk-usage snapshots.
- Use the completed Kraken2 database as a broader taxonomic check for the ambiguous isolates, especially `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` and `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7`, while continuing to prepare the SPAdes stage in parallel.

## 2026-04-17 Kraken2 database build verified

- Treat the Kraken2 bacteria database as ready for downstream classification because `kraken2_db/db/hash.k2d`, `kraken2_db/db/opts.k2d`, and `kraken2_db/db/taxo.k2d` now exist and the successful job `1319269` completed end-to-end.
- Use the database first on the ambiguous isolates, especially `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` and `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7`, to test whether a broader bacterial taxonomic screen clarifies the weak or conflicting alignment results.
- Keep `kraken2_db/metadata/kraken2_build_verification_2026-04-17.md` with the run records, because the successful build still logged one transient FTP fetch failure and two gzip-corrupt downloaded genome files during library processing.
- Rebuild the database only if downstream Kraken2 results suggest the missing or corrupt source genomes are likely to affect interpretation; otherwise keep momentum and proceed to sample classification plus assembly preparation.
- Continue preparing the SPAdes assembly stage in parallel so assembly, annotation, and gene-mining work do not wait on further database rebuilding unless the classification results justify it.

## 2026-04-17 Post-Kraken2 summary decision point

- Use `kraken2_classification/metrics/kraken2_classification_summary.tsv` together with `multi_reference_alignment/metrics/multi_reference_alignment_summary.tsv` as the current project-level split point before assembly.
- Prioritize SPAdes preparation for all 6 trimmed paired samples so taxonomic interpretation does not rely only on read-level classifiers or a small reference panel.
- Treat `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7` as the strongest current `Vibrio vulnificus` candidates for downstream annotation and virulence-gene review.
- Carry `Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` forward as a likely non-`vulnificus Vibrio` isolate because Kraken2 now favors `Vibrio cidicii` over `Vibrio vulnificus`.
- Carry `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` forward as a `Vibrio` sample with unresolved species identity because both reference alignment and Kraken2 remain mixed at the species level.
- Carry `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` forward as the highest-priority contamination or mislabeling check because it remains a severe outlier in alignment and now classifies mainly to `Bacillus` rather than `Vibrio`.
- Before assembly submission, add a reusable SPAdes manifest plus SLURM script, define assembly output directories, and record expected metrics to verify completion without running heavy work on the login node.
