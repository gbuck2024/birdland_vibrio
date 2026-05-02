# Next Steps

## 2026-05-01 ANI substage prepared for the 3 best subsampled assemblies

- Review `assembly_filtered_subsampled_isolate/metrics/assembly_summary.tsv` one last time if you want to challenge the chosen representatives, but the current planned ANI set is `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7_50x`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7_25x`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7_100x`.
- Submit `scripts/fastani_array.slurm` with `STAGE_DIR=ani/subsampled_best_assemblies` and `QUERY_MANIFEST=configs/ani_query_manifest_subsampled_best_assemblies.tsv` so the 3 selected scaffold assemblies are compared against the intended saved `Vibrio` reference set without touching any prior ANI outputs.
- After the ANI array completes, submit the same script in `ANI_MODE=summary` to write `ani/subsampled_best_assemblies/metrics/ani_summary.tsv` and `ani/subsampled_best_assemblies/metrics/ani_matrix.tsv`.
- Confirm that 3 raw outputs appear under `ani/subsampled_best_assemblies/outputs/` and that the summary and matrix files appear under `ani/subsampled_best_assemblies/metrics/`.
- Interpret `>=95-96% ANI` to `v_vulnificus` as the strongest planned assembly-level confirmation that the selected subsampled representatives are consistent with `Vibrio vulnificus`.

## 2026-05-01 Subsampling stage prepared for submission

- Submit the new fixed-depth subsampling array with `sbatch --array=0-8 scripts/subsample_vibrio_reads_array.slurm` so each of the 3 target samples is downsampled once at `25x`, `50x`, and `100x` from the completed Kraken2-filtered paired FASTQ inputs.
- After the subsampling array completes, submit `sbatch --export=ALL,SUBSAMPLE_MODE=summary scripts/subsample_vibrio_reads_array.slurm` to generate `kraken2_vibrio_subsampled_reads/metrics/subsampling_summary.tsv`.
- Verify that all 9 expected subsampled paired FASTQ outputs exist under `kraken2_vibrio_subsampled_reads/subsampled_reads/` and confirm from the summary TSV that each `actual_read_pairs` value matches its saved `target_read_pairs`.
- If the summary looks clean, submit `sbatch --export=ALL,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered_subsampled.tsv,STAGE_DIR=assembly_filtered_subsampled_isolate --array=0-8 scripts/spades_assembly_array.slurm`.
- After the subsampled SPAdes array completes, submit `sbatch --export=ALL,SPADES_MODE=summary,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered_subsampled.tsv,STAGE_DIR=assembly_filtered_subsampled_isolate scripts/spades_assembly_array.slurm`.
- Compare `assembly_filtered_subsampled_isolate/metrics/assembly_summary.tsv` against `assembly_filtered_isolate_rerun/metrics/assembly_summary.tsv`, `assembly_isolate_rerun/metrics/assembly_summary.tsv`, and `assembly/metrics/assembly_summary.tsv`, focusing on whether the fixed-depth subsets move scaffold totals and fragmentation closer to an expected isolate-scale `5.2 Mb` genome.
- Keep `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` and `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` out of this depth-test path unless later results justify an expanded sample set.

## 2026-05-01 Filtered-read assembly decision point

- Treat the filtered-read `--isolate` rerun as complete and use `assembly_filtered_isolate_rerun/metrics/assembly_summary.tsv` as the current assembly decision point for the 3 strongest `Vibrio vulnificus` candidates.
- Do not move these filtered assemblies directly into ANI, annotation, or virulence-gene mining yet, because scaffold totals remain inflated at about `13.5 Mb`, `11.0 Mb`, and `10.1 Mb`, still well above an isolate-scale `5.2 Mb` genome.
- Prioritize a controlled subsampling test on the filtered paired FASTQ files for `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`.
- Build a new stage-specific workflow that subsamples each filtered read pair set to approximate `25x`, `50x`, and `100x` coverage assuming a `5.2 Mb` genome, while preserving read pairing and writing all outputs into a new dedicated stage directory.
- Use approximate retained-pair targets of about `436,242` pairs for `25x`, `872,483` pairs for `50x`, and `1,744,966` pairs for `100x` if trimmed read lengths stay near `149 bp`.
- After subsampling, run `SPAdes --isolate` separately on each depth level for each of the 3 samples and save all manifests, parameters, and completion checks in the new stage directory rather than reusing `assembly_filtered_isolate_rerun/`.
- Compare the subsampled assembly summaries against `assembly_filtered_isolate_rerun/metrics/assembly_summary.tsv`, `assembly_isolate_rerun/metrics/assembly_summary.tsv`, and `assembly/metrics/assembly_summary.tsv`, focusing on total bases, contig and scaffold counts, N50, longest scaffold, and whether the assemblies move closer to the expected isolate genome size.
- Treat `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7` as the highest-risk sample in the subsampling test, because its filtered SPAdes log still reports unreliable k-mer model warnings even after Kraken2-guided filtering.
- Keep `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` and `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` out of this focused `Vibrio vulnificus` subsampling path, because the saved Kraken2 and alignment evidence still does not support them as comparably clean `Vibrio vulnificus` isolates.

## 2026-04-28 Kraken2-guided Vibrio filtering prepared

- Submit `sbatch --array=0-2 scripts/kraken2_vibrio_filter_array.slurm` to retain only Kraken2-classified `Vibrio` genus-or-below read pairs for `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`.
- After the filtering array completes, submit `sbatch --export=ALL,KRAKEN2_VIBRIO_FILTER_MODE=summary scripts/kraken2_vibrio_filter_array.slurm` to generate `kraken2_vibrio_read_filtering/metrics/kraken2_vibrio_filtering_summary.tsv`.
- Review retained-pair counts and retained percentages before rerunning SPAdes, because a very low retained fraction would indicate that the Kraken2-guided narrowing step may be too aggressive for one or more samples.
- If the retained-read summary looks reasonable, submit `sbatch --export=ALL,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered.tsv,STAGE_DIR=assembly_filtered_isolate_rerun --array=0-2 scripts/spades_assembly_array.slurm`.
- After the filtered-read assembly array completes, submit `sbatch --export=ALL,SPADES_MODE=summary,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered.tsv,STAGE_DIR=assembly_filtered_isolate_rerun scripts/spades_assembly_array.slurm`.
- Compare `assembly_filtered_isolate_rerun/metrics/assembly_summary.tsv` against both `assembly/metrics/assembly_summary.tsv` and `assembly_isolate_rerun/metrics/assembly_summary.tsv`, focusing on total assembly size, contig count, scaffold count, and N50 before deciding which assemblies should feed ANI and downstream annotation.

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

## 2026-04-18 SPAdes stage prepared for submission

- Submit `scripts/spades_assembly_array.slurm` with `sbatch --array=0-5` so each trimmed paired sample assembles once into `assembly/assemblies/<sample_id>/`.
- Confirm within 1-2 minutes that the array has started cleanly by checking `assembly/logs/slurm/` for the first stdout/stderr files and verifying that each task resolved the SPAdes executable correctly on the cluster.
- After the array completes, submit `sbatch --export=ALL,SPADES_MODE=summary scripts/spades_assembly_array.slurm` to generate `assembly/metrics/assembly_summary.tsv`.
- Review assembly size, contig count, scaffold count, N50, longest contig, and GC percentage before moving into annotation and gene-target analysis.
- Keep `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` flagged as the highest-scrutiny assembly for contamination or non-target biology during post-assembly interpretation.

## 2026-04-18 ANI stage prepared for submission

- After `assembly/assemblies/<sample_id>/contigs.fasta` exists for all 6 samples, submit `scripts/fastani_array.slurm` with `sbatch --array=0-5` so each assembled genome is compared once against the saved reference set.
- Confirm within 1-2 minutes that the ANI array has started cleanly by checking `ani/logs/slurm/` and verifying that each task resolved the `fastANI` executable correctly on the cluster.
- After the array completes, submit `sbatch --export=ALL,ANI_MODE=summary scripts/fastani_array.slurm` to generate `ani/metrics/ani_summary.tsv` and `ani/metrics/ani_matrix.tsv`.
- Use ANI values near or above `95-96%` against `v_vulnificus` as the strongest assembly-level support for likely `Vibrio vulnificus`.
- Treat samples with species-level ANI to a different reference as likely other `Vibrio` species, and treat sub-threshold or no-hit samples as outliers or unresolved pending broader post-assembly review.

## 2026-04-20 Assembly rerun decision point

- Prioritize an isolate-oriented SPAdes rerun for only `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, because they remain the strongest current `Vibrio vulnificus` candidates across Kraken2 and reference alignment.
- Keep `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` out of the main `Vibrio vulnificus` rerun path because the combined Kraken2 and alignment evidence still supports contamination, mislabeling, or non-target biology.
- Keep `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` out of the focused rerun because it remains a mixed or unresolved `Vibrio` sample with stronger support for non-`vulnificus` identity than for `Vibrio vulnificus`.
- Submit the rerun with `sbatch --export=ALL,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates.tsv,STAGE_DIR=assembly_isolate_rerun --array=0-2 scripts/spades_assembly_array.slurm`.
- Confirm within 1-2 minutes that `assembly_isolate_rerun/logs/slurm/` contains clean startup logs showing the intended manifest, stage directory, and `--isolate` extra argument.
- After the rerun completes, submit `sbatch --export=ALL,SPADES_MODE=summary,MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates.tsv,STAGE_DIR=assembly_isolate_rerun scripts/spades_assembly_array.slurm`.
- Compare `assembly_isolate_rerun/metrics/assembly_summary.tsv` against the original `assembly/metrics/assembly_summary.tsv`, focusing on total assembly size, contig count, scaffold count, N50, and the number of sequences at least `1000 bp` before deciding whether ANI and annotation should use the rerun outputs.
