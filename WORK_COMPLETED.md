# Work Completed

## 2026-08-15 ANI heatmap alignment-fraction mask added

- Updated `scripts/summarize_fastani_matrix.py` so the rectangular fastANI summary now records `alignment_fraction = fragment_mappings / query_fragments` in `ani/reference_panel_plus_unknown_matrix/metrics/fastani_matrix_long.tsv`.
- Regenerated the lightweight matrix summary for `ani/reference_panel_plus_unknown_matrix`, adding `metrics/fastani_alignment_fraction_matrix.tsv` and `metrics/fastani_genome_matrix_af_ge_0_50.tsv`.
- Updated `scripts/plot_fastani_matrix_heatmap.R` so the genome heatmap reads the AF matrix and grays out cells with `AF < 0.50` or missing AF while leaving ANI colors for cells meeting the threshold.
- Regenerated the heatmap figures with `module load R/gcc11/4.4.0 && Rscript scripts/plot_fastani_matrix_heatmap.R`.
- Verified the long table contains `6,724` pairwise cells: `2,929` have `AF >= 0.50` and `3,795` are below threshold or missing.

## 2026-08-14 reference-panel-plus-unknown ANI heatmaps generated

- Investigated SLURM job `1465438` and confirmed it completed successfully with exit code `0:0`; this was the `ANI_MODE=matrix` summary pass for `ani/reference_panel_plus_unknown_matrix`, not a new fastANI comparison array.
- Verified that the stage contains `82` query rows, `82` reference rows, `82` non-empty raw fastANI output files, and a complete long-form matrix with `6,725` lines (`82 x 82` comparisons plus header).
- Confirmed the summary step wrote `ani/reference_panel_plus_unknown_matrix/metrics/fastani_matrix_long.tsv`, `fastani_genome_matrix.tsv`, `fastani_species_max_matrix.tsv`, and `fastani_species_mean_matrix.tsv`.
- Located and ran `scripts/plot_fastani_matrix_heatmap.R` with `module load R/gcc11/4.4.0 && Rscript scripts/plot_fastani_matrix_heatmap.R`.
- Generated the current heatmap figures under `ani/reference_panel_plus_unknown_matrix/figures/`: `reference_panel_plus_unknown_matrix_genome_heatmap.pdf`, `.png`, `reference_panel_plus_unknown_matrix_species_max_heatmap.pdf`, and `.png`.

## 2026-07-02 unresolved-isolate vcg screen summarized

- Reviewed the completed ambiguous-isolate `vcg_mining` BLAST outputs for `Buck_BI0607_1`, `Buck_BI0607_2`, and `Buck_NB0507_14`; each per-sample BLAST table exists under `ambiguous_isolate_resolution/vcg_mining/results/` and contains zero hit rows.
- Confirmed that job array `1395878_[0-2]` completed successfully with exit code `0:0`, while the later summary job `1395886` failed because it was submitted with an incorrect manifest path.
- Regenerated the lightweight summary directly with `scripts/summarize_vcg_hits.py`, writing `ambiguous_isolate_resolution/vcg_mining/results/vcg_best_hits_summary.tsv`.
- The summary reports `best_hit_found=no` for all three ambiguous isolates, so no `vcgC` or `vcgE` hit was detected under the saved `blastn` settings.
- Updated `ambiguous_isolate_resolution/vcg_mining/README.md` with the interpreted result and retained the conservative interpretation that this single-gene screen supports excluding these unresolved isolates from the confirmed `Vibrio vulnificus` branch but does not replace broader taxonomy or ANI evidence.

## 2026-07-02 unresolved-isolate vcg submission repair

- Checked SLURM accounting for job array `1395856` and confirmed all three `vcg_mining` array tasks failed with exit code `1:0` after 1-2 seconds.
- Reviewed `vcg_mining/logs/slurm/vcg_mining_1395856_*.err` and found the shared failure reason: the redirected ambiguous-isolate run looked for a missing stage-local reference FASTA at `ambiguous_isolate_resolution/vcg_mining/references/vcg_reference_alleles.fasta`.
- Verified that the intended reusable reference FASTA exists and is non-empty at `vcg_mining/references/vcg_reference_alleles.fasta`.
- Updated `scripts/vcg_mining_array.slurm` so redirected stages still prefer a stage-local reference if present, but otherwise fall back to the shared saved `vcg_mining/references/vcg_reference_alleles.fasta` rather than failing before BLAST starts.
- Updated `ambiguous_isolate_resolution/vcg_mining/README.md` and `NEXT_STEPS.md` with corrected `sbatch` commands that pass `-o/-e` paths for ambiguous-stage SLURM logs, since `#SBATCH` output directives are otherwise fixed before the script can apply `STAGE_DIR`.
- Did not resubmit the BLAST job. The workflow is repaired and ready for manual SLURM submission.

## 2026-07-01 unresolved-isolate vcg screening stage prepared

- Reviewed the repo-level project markdown, the existing `vcg_mining` workflow, and the ambiguous-isolate taxonomic-filtering stage before editing so the new work stays isolated from the confirmed `Vibrio vulnificus` branch.
- Added `configs/ambiguous_vcg_mining_manifest.tsv` to define the three unresolved reassemblies for `vcg` screening: `Buck_BI0607_1`, `Buck_BI0607_2`, and `Buck_NB0507_14`, each pointing to its taxon-filtered `scaffolds.fasta` and a stage-local BLAST output path under `ambiguous_isolate_resolution/vcg_mining/results/`.
- Added `ambiguous_isolate_resolution/vcg_mining/README.md` documenting the rationale for screening `vcgC`/`vcgE` in the unresolved reassemblies, the saved assembly-size context (`4.3 Mb`, `4.1 Mb`, and `6.1 Mb`), the intended inputs and outputs, and the exact `sbatch` commands needed to run the BLAST and summary steps through SLURM.
- Relaxed one overly strict check in `scripts/vcg_mining_array.slurm` so the reusable workflow no longer fails when a manifest uses simplified `sample_id` labels that do not exactly match the assembly directory name, which is required for reuse on the ambiguous-isolate reassembly directories.
- Verified only the workflow preparation and syntax in this milestone. No new BLAST searches were run and no new `vcg` results were generated for the unresolved isolates in this turn.

## 2026-05-27 Expanded V. vulnificus RAxML tree plotting added

- Added `scripts/plot_expanded_vv_raxml_tree.R` as the reusable R plotting entry point for `phylogeny/expanded_vv_46/tree/raxmlng/expanded_vv_46.raxml.support`.
- The script reads the expanded 46-genome manifest, matches normalized tree tip labels to `genome_id` values using `reference_id` as the fallback because the current manifest does not contain a `genome_id` column, enriches the three Buck isolates with saved vcg summary calls, and reports unmatched tree tips plus unmatched metadata rows.
- Handled the current RAxML support tree's duplicated ATCC-derived labels, `atcc_27562.fna` and `atcc_27562.fna.ref`, by preserving unique plot labels while mapping both tips back to ATCC metadata.
- Verified the script with `module load R/gcc11/4.4.0 && Rscript scripts/plot_expanded_vv_raxml_tree.R`; it wrote `phylogeny/expanded_vv_46/tree/raxmlng/expanded_vv_46_raxml_tree.pdf` and `phylogeny/expanded_vv_46/tree/raxmlng/expanded_vv_46_raxml_tree.png`.

## 2026-05-26 Expanded V. vulnificus Parsnp phylogeny scaffold prepared

- Added `configs/expanded_vv_46_genome_manifest.tsv` as the requested 46-genome phylogeny manifest, based on the existing Mullis 2019 plus Buck plus ATCC panel manifest.
- Added `scripts/prepare_expanded_vv_parsnp_inputs.sh` to validate that the manifest has 46 genomes plus a header, create `phylogeny/expanded_vv_46/{genomes,alignment,logs,metadata,tree}`, stage Parsnp FASTA inputs, and select ATCC 27562 as the Parsnp reference.
- Added `scripts/parsnp_expanded_vv_46.slurm` to run Parsnp with `singularity exec containers/parsnp_2.1.5.sif parsnp ...`, write outputs under `phylogeny/expanded_vv_46/alignment/parsnp/`, and verify `parsnp.xmfa`, `parsnp.tree`, `parsnp.snps.mblocks`, and `parsnp.ggr`.
- Repaired `scripts/parsnp_expanded_vv_46.slurm` after SLURM job `1325452` failed because Parsnp 2.1.5 rejects a pre-existing output directory. The script now still stops if `phylogeny/expanded_vv_46/alignment/parsnp/` contains files, but removes that directory when it is empty so Parsnp can create it itself.
- Added `scripts/test_phylogeny_containers.sh` to check the Parsnp, IQ-TREE, and RAxML-NG containers without running tree-building analyses.
- Added `phylogeny/expanded_vv_46/README.md` documenting the workflow, expected outputs, and downstream IQ-TREE/RAxML-NG placeholder command location.
- Ran the prep script successfully. It staged 46 FASTA inputs and recorded ATCC 27562 as `phylogeny/expanded_vv_46/genomes/atcc_27562.fna`.
- Ran the container smoke test successfully outside the sandbox after the sandboxed Singularity run failed due local mount restrictions.

## 2026-05-04 vcg single-gene FastTree workflow added and run

- Checked FastTree availability from the project root. `command -v FastTree` and `command -v fasttree` were not available before module loading; `module avail fasttree` reported `fasttree/2.1.11`; `module spider fasttree` is not supported by this module system and returned `ERROR: Invalid command 'spider'`.
- Added `scripts/build_vcg_fasttree.sh` as the reusable vcg single-gene tree builder. The script uses strict Bash mode, resolves the project root from the script location, validates `vcg_mining/alignment/all_vcg_sequences.aligned.fasta`, creates `vcg_mining/tree`, resolves FastTree from `PATH` or the `fasttree/2.1.11` module, writes `vcg_mining/tree/all_vcg_sequences.fasttree.nwk`, saves stderr/runtime details to `vcg_mining/tree/all_vcg_sequences.fasttree.log`, and verifies that the Newick tree is non-empty.
- Added `scripts/plot_vcg_tree.R` to read the FastTree Newick file with `ape` and save `vcg_mining/tree/all_vcg_sequences.fasttree.pdf`.
- Ran `bash scripts/build_vcg_fasttree.sh` successfully. The tree file is non-empty and the log records FastTree `2.1.11`.
- Loaded `R/gcc11/4.4.0`, confirmed that the R package `ape` is available, and ran `Rscript scripts/plot_vcg_tree.R` successfully to create the PDF visualization.
- Audited `.gitignore` for the new tree stage so `vcg_mining/tree/*.log` remains ignored while `.nwk` and `.pdf` tree outputs are explicitly allowed.
- Biological interpretation for this small single-gene tree: the branch lengths are consistent with `Buck_BS0607_9_vcgE` and `Buck_NB0507_8_vcgE` being much closer to each other than either is to `Buck_CB0707_82_vcgC`. The saved Newick is `Buck_CB0707_82_vcgC` on a much longer branch, consistent with separate vcgC branching, but this is a 3-sequence single-gene tree and should not be interpreted as a whole-genome phylogeny.

## 2026-05-04 vcg alignment inspection script added and reviewed

- Added `scripts/review_vcg_alignment.py` as a reusable post-alignment inspection step for `vcg_mining/alignment/all_vcg_sequences.aligned.fasta`.
- The script validates that all aligned FASTA records have equal length, counts per-sequence gap positions, computes pairwise nucleotide differences across the full alignment, identifies all variable alignment columns, and writes both `vcg_mining/alignment_review/vcg_pairwise_differences.tsv` and `vcg_mining/alignment_review/vcg_alignment_review.md`.
- Ran `python3 scripts/review_vcg_alignment.py` with bytecode writing disabled for this environment, which successfully generated the requested review outputs under `vcg_mining/alignment_review/`.
- Verified from the generated outputs that all 3 aligned sequences share a length of `581 bp`, the alignment contains `106` variable columns, `Buck_CB0707_82_vcgC` has `30` gap positions, and the pairwise differences are `103` for `Buck_BS0607_9_vcgE` versus `Buck_CB0707_82_vcgC`, `6` for `Buck_BS0607_9_vcgE` versus `Buck_NB0507_8_vcgE`, and `105` for `Buck_CB0707_82_vcgC` versus `Buck_NB0507_8_vcgE`.

## 2026-05-04 vcg MAFFT alignment script added and verified

- Added `scripts/align_vcg_mafft.sh` as a reusable non-SLURM Bash wrapper for the vcg alignment step, with strict mode enabled, automatic project-root resolution from the script location, stage-directory creation, and validation of the extracted input FASTA, `singularity`, and the saved MAFFT container image at `containers/mafft_7.525.sif`.
- Implemented a container self-test before alignment, routed MAFFT stderr into `vcg_mining/logs/mafft_vcg.err`, wrote the alignment through a temporary file before moving it into place, and made the script fail clearly if MAFFT exits non-zero or produces an empty output FASTA.
- Ran `bash -n scripts/align_vcg_mafft.sh` and then executed `bash scripts/align_vcg_mafft.sh`, which successfully created `vcg_mining/alignment/all_vcg_sequences.aligned.fasta` with 3 aligned records and reported aligned sequence lengths of `581 bp` for `Buck_BS0607_9_vcgE`, `Buck_CB0707_82_vcgC`, and `Buck_NB0507_8_vcgE`.

## 2026-05-04 vcg extraction script repaired for resumable sequence extraction

- Reviewed the saved vcg mining outputs, the reference allele FASTA, and the current `vcg_mining/results/vcg_best_hits_summary.tsv` layout before editing so the extraction script matches the stage that has already been run.
- Rewrote `scripts/extract_vcg.sh` so it now uses the saved summary file `vcg_mining/results/vcg_best_hits_summary.tsv` by default instead of the missing older path `vcg_mining/results/combined_vcg_results.tsv`.
- Removed the hard dependency on `seqkit` and replaced reverse-strand handling with an in-script Python reverse-complement step, which fixes the reported `module load seqkit` failure while keeping the extraction logic reproducible.
- Added explicit project-root resolution, input validation, `samtools` discovery from either `PATH` or a common module name, numeric coordinate checks, conditional FASTA indexing, and atomic temporary-file writes so reruns fail clearly and do not leave partial outputs behind.
- Updated the extraction naming and resume behavior so reruns recognize the legacy sample-level FASTA already present under `vcg_mining/extracted_sequences/` and skip that sample instead of recomputing it unnecessarily.
- Verified the repaired script with `bash -n scripts/extract_vcg.sh` and a light execution check using `bash scripts/extract_vcg.sh`, confirming that the script now runs without `seqkit` and writes the expected extracted FASTA outputs under `vcg_mining/extracted_sequences/`.

## 2026-05-01 vcg mining stage prepared for selected confirmed assemblies

- Reviewed the existing manifest-driven SLURM stages, the saved project brief, and the current assembly-selection notes before editing so the new vcg workflow follows the repository’s stage isolation, reproducibility, and documentation rules.
- Added `configs/vcg_mining_manifest.tsv` to define the first 3 confirmed subsampled assemblies for vcg screening: `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7_50x`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7_25x`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7_100x`, each pointing to its saved `scaffolds.fasta`.
- Added the new stage directory `vcg_mining/` with `README.md` plus the requested `references/`, `results/`, `logs/`, and `scripts/` subdirectories so the vcg work is isolated from the earlier assembly and ANI stages.
- Added `scripts/vcg_mining_array.slurm` as a reusable SLURM array workflow that validates the manifest, validates each assembly FASTA, fails clearly if `vcg_mining/references/vcg_reference_alleles.fasta` is missing or empty, tries to resolve `blastn` and `makeblastdb` from `PATH` or a BLAST environment module, builds a local nucleotide BLAST database for each assembly reproducibly under `vcg_mining/results/blast_db/`, and writes the requested tabular BLAST output columns for each sample.
- Added `scripts/summarize_vcg_hits.py` to parse the per-sample BLAST tables and write `vcg_mining/results/vcg_best_hits_summary.tsv` with one best hit per sample chosen by bitscore, then e-value, then percent identity and query coverage.
- Updated `.gitignore`, `NEXT_STEPS.md`, and the stage notes so raw vcg BLAST outputs and logs stay out of Git while the curated summary TSV remains trackable.
- Ran only non-compute preparation in this turn. No BLAST jobs were submitted and no vcg mining outputs were generated yet.

## 2026-05-01 ANI containerization and container-directory cleanup

- Audited the saved container-handling patterns in `scripts/spades_assembly_array.slurm`, `scripts/kraken2_build_bacterial_db.slurm`, `scripts/kraken2_classify_array.slurm`, `scripts/fastani_array.slurm`, and the related stage notes before editing so the new ANI fix follows the same reproducibility model already used elsewhere in the project.
- Updated `scripts/fastani_array.slurm` so ANI now prefers a Singularity image through `FASTANI_SIF` or the canonical default location `containers/fastani_latest.sif`, while still retaining fallback support for a native `FASTANI_BIN` or older module-based environments if the container is absent.
- Updated the SPAdes and Kraken2 SLURM scripts so they now prefer the canonical `containers/` image location first and only fall back to the older project-root `.sif` paths for backward compatibility with earlier saved runs.
- Updated the ANI, assembly, Kraken2, and top-level project documentation so the container search order, reproducible default paths, and the new ANI submission expectation are recorded explicitly.
- Created `containers/README.md` and moved `fastani_latest.sif`, `kraken2.sif`, and `spades.sif` into `containers/` so the repository root no longer accumulates workflow images.
- Extended `.gitignore` so the relocated top-level `fastani_latest.sif` remains untracked if it reappears outside `containers/`.

## 2026-05-01 ANI substage prepared for the 3 best completed subsampled assemblies

- Reviewed the top-level project markdown files again before editing so the ANI updates follow the saved workflow, documentation, stage-isolation, and Git-tracking rules already in force on `2026-05-01`.
- Audited the existing ANI assets under `ani/`, `configs/`, `scripts/`, and `reference/` before patching so the new work reuses the saved reference manifest and does not collide with the older six-sample ANI preparation.
- Reviewed `assembly_filtered_subsampled_isolate/metrics/assembly_summary.tsv` and selected one best subsampled assembly per strong `Vibrio vulnificus` candidate for the next ANI run: `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7_50x`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7_25x`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7_100x`.
- Added `configs/ani_query_manifest_subsampled_best_assemblies.tsv` so the 3 chosen ANI queries are saved explicitly as scaffold-level FASTA paths under `assembly_filtered_subsampled_isolate/assemblies/`.
- Added the new substage directory `ani/subsampled_best_assemblies/` with `README.md` and `metrics/fastani_parameters.txt` documenting why those 3 assemblies were selected, the exact scaffold source paths, the intended tracked reference set, the planned `fastANI` thresholds, and the expected outputs.
- Updated `scripts/fastani_array.slurm` so ANI runs can now be redirected into a new stage with `STAGE_DIR`, can swap query manifests with `QUERY_MANIFEST`, can pin the reference manifest with `REFERENCE_MANIFEST`, and can accept either `contigs.fasta` or `scaffolds.fasta` as the query assembly FASTA.
- Updated `scripts/summarize_fastani.py` so the summary and matrix generation now respect `STAGE_DIR`, `QUERY_MANIFEST`, and `REFERENCE_MANIFEST`, which allows the same summarizer to be reused for the new substage without overwriting any older ANI summary targets.
- Updated `ani/README.md`, `.gitignore`, `README.md`, `NEXT_STEPS.md`, and `IN_PROGRESS.md` so the new ANI substage is documented and its future raw outputs and logs stay out of Git while curated metrics remain trackable.
- Ran only non-compute validation in this turn: manifest path checks, Bash syntax checks, and Python syntax checks for the updated ANI workflow. No SLURM jobs were submitted and no new ANI outputs were generated yet.

## 2026-05-01 Kraken2-filtered subsampling and subsampled-SPAdes stages prepared

- Read the top-level project markdown files again before editing so the new stage follows the saved workflow, documentation, and repo-tracking rules already in force on `2026-05-01`.
- Calculated the fixed target read-pair counts for the new downsampling test assuming a `5.2 Mb` genome and `149 bp` paired-end reads: `436,242` pairs for `25x`, `872,483` pairs for `50x`, and `1,744,966` pairs for `100x`.
- Added `configs/kraken2_vibrio_subsample_manifest.tsv` to define all 9 planned sample-depth subsets from the completed `kraken2_vibrio_read_filtering/filtered_reads/` inputs, including saved seeds, output FASTQ paths, and per-run metrics paths.
- Added `scripts/subsample_paired_fastq.py` as a reusable Python subsampling workflow that validates paired gzipped FASTQ inputs, preserves R1/R2 synchronization by reading both files in lockstep, draws a seeded random subset of pair indexes, and records `sample_id`, `subsample_id`, target depth assumptions, target pair counts, actual pair counts, seeds, and input/output FASTQ paths.
- Added `scripts/summarize_subsampled_reads.py` plus `scripts/subsample_vibrio_reads_array.slurm` so the new subsampling stage can be submitted as a 9-task SLURM array and then summarized into `kraken2_vibrio_subsampled_reads/metrics/subsampling_summary.tsv` without mixing outputs into earlier stages.
- Added the new stage directory `kraken2_vibrio_subsampled_reads/` with `README.md` and `metrics/subsampling_parameters.txt` so the planned fixed-depth FASTQ outputs, recorded fields, and submission form are documented before job submission.
- Added `configs/assembly_manifest_vulnificus_candidates_filtered_subsampled.tsv` for the downstream `SPAdes --isolate` rerun across the 9 planned subsampled paired-read sets.
- Added the new stage directory `assembly_filtered_subsampled_isolate/` with `README.md` and `metrics/spades_parameters.txt` so the fixed-depth assembly rerun can be submitted reproducibly without overwriting `assembly/`, `assembly_isolate_rerun/`, or `assembly_filtered_isolate_rerun/`.
- Updated `README.md`, `.gitignore`, and the milestone notes so the new subsampling-preparation state is documented and the future subsampled FASTQ outputs, runtime logs, and assembly directories stay out of Git while curated metrics remain trackable.
- Ran only non-compute validation in this turn: Python syntax checks, Bash syntax checks, and dry-run/path validation against all 9 planned subsampling rows. No SLURM jobs were submitted and no new FASTQ outputs were generated yet.

## 2026-05-01 Filtered-read assembly comparison and next-step decision

- Audited the completed `assembly_filtered_isolate_rerun/` stage and confirmed that all 3 target samples now have finished SPAdes outputs plus a saved comparison table at `assembly_filtered_isolate_rerun/metrics/assembly_summary.tsv`.
- Confirmed that Kraken2-guided `Vibrio` filtering materially improved the focused `--isolate` rerun relative to the prior isolate-mode rerun, reducing scaffold totals from about `66.5 Mb`, `32.6 Mb`, and `19.0 Mb` to about `13.5 Mb`, `11.0 Mb`, and `10.1 Mb` for `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, respectively.
- Confirmed that the filtered rerun is still too inflated for clean isolate-scale downstream use, because all 3 assemblies remain roughly `2x` or more above an expected `5.2 Mb` `Vibrio vulnificus` genome even after the Kraken2-guided narrowing step.
- Rechecked that these 3 samples remain the strongest current `Vibrio vulnificus` set in the saved project evidence: Kraken2 top-species calls still favor `Vibrio vulnificus`, and the retained filtered-pair percentages remain high at `91.86%`, `98.40%`, and `98.76%`.
- Confirmed from the saved SPAdes logs that the filtered read sets are still extremely deep and likely coverage-skewed for assembly, with SPAdes estimating genome-scale coverages in the thousands for `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7` and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, while `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7` still shows unreliable k-mer model warnings.
- Calculated that the retained filtered read sets still represent roughly `9,300x` to `12,600x` depth assuming a `5.2 Mb` genome and approximately `149 bp` trimmed read length, which makes a controlled downsampling test biologically justified rather than a blind extra rerun.
- Chose the next recommended corrective step as a new stage-specific subsampling experiment on the filtered paired FASTQ inputs, targeting approximate depths of `25x`, `50x`, and `100x`, followed by `SPAdes --isolate` assemblies for each subsampled dataset before ANI, annotation, or gene-mining on these 3 samples.

## 2026-04-30 Assembly rerun audit while filtered-read SPAdes job is running

- Audited the saved project state against `PROJECT_BRIEF.md` and confirmed that the completed stages on disk are raw FastQC, FastQC extraction and interpretation, Trimmomatic trimming, post-trim FastQC interpretation, single-reference alignment review, multi-reference alignment review, Kraken2 broad classification, first-pass SPAdes assembly, the 3-sample isolate-mode rerun, and the new Kraken2-guided Vibrio read-filtering stage.
- Verified that the Kraken2 Vibrio filtering array had already completed successfully for the 3 strongest current `Vibrio vulnificus` candidates and that the summary job `1321574` completed cleanly on `2026-04-30`, writing `kraken2_vibrio_read_filtering/metrics/kraken2_vibrio_filtering_summary.tsv` with no stderr output.
- Confirmed that the filtered-read retention is high enough to justify the current SPAdes rerun: `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7` retained `219,765,787` of `239,251,931` read pairs (`91.86%`), `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7` retained `177,537,029` of `180,420,959` (`98.40%`), and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7` retained `163,105,516` of `165,150,467` (`98.76%`).
- Rechecked that these same 3 samples remain the best-supported `Vibrio vulnificus` set across the saved evidence: Kraken2 top-species calls are `Vibrio vulnificus` for all three, and the best multi-reference alignment fits are also to `v_vulnificus` at `87.51%`, `81.57%`, and `88.12%` mapped, respectively.
- Reconfirmed that the prior isolate-mode rerun did not sufficiently solve assembly inflation, with scaffold totals still at about `66.5 Mb` for `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `32.6 Mb` for `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `19.0 Mb` for `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, so a filtered-read rerun remains a justified corrective step.
- Verified that the current SLURM submission was the correct next move: job array `1321575_[0-2]` is actively running under `scripts/spades_assembly_array.slurm` with `MANIFEST_FILE=configs/assembly_manifest_vulnificus_candidates_filtered.tsv`, `STAGE_DIR=assembly_filtered_isolate_rerun`, and default `--isolate` mode.
- Confirmed from the live SPAdes logs under `assembly_filtered_isolate_rerun/logs/` and the sample assembly directories that all 3 tasks started cleanly, are reading the intended filtered FASTQ pairs, are writing to the intended stage-specific directory, and have progressed into SPAdes `K21` assembly without an immediate startup or input-validation failure.

## 2026-04-28 Kraken2-guided Vibrio read-filtering and filtered-read assembly stage prepared

- Confirmed that QC, trimming, single-reference alignment review, Kraken2 broad classification, first-pass SPAdes assembly, and the 3-sample isolate-mode SPAdes rerun are already completed in the saved project tree.
- Confirmed again that the strongest current `Vibrio vulnificus` candidates remain `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, based on the saved Kraken2 classification summary.
- Confirmed that the isolate-mode rerun still looks inflated, with scaffold totals of about `66.5 Mb`, `32.6 Mb`, and `19.0 Mb` respectively in `assembly_isolate_rerun/metrics/assembly_summary.tsv`, which remains far above an expected isolate-scale `Vibrio vulnificus` genome size.
- Added `configs/kraken2_vibrio_filter_manifest.tsv` for a focused 3-sample Kraken2-guided filtering stage and `configs/assembly_manifest_vulnificus_candidates_filtered.tsv` for the downstream filtered-read rerun.
- Added `scripts/filter_kraken2_vibrio_reads.py`, `scripts/summarize_kraken2_vibrio_filtering.py`, and `scripts/kraken2_vibrio_filter_array.slurm` to reproducibly retain only paired fragments classified by Kraken2 as `Vibrio` genus (`taxid 662`) or below while preserving read-pair synchronization and recording per-sample filtering metrics.
- Added the new stage directories `kraken2_vibrio_read_filtering/` and `assembly_filtered_isolate_rerun/` with README and parameter files so the filtered FASTQ generation and the filtered-read `--isolate` SPAdes rerun can be submitted without overwriting the original trimmed reads or either prior assembly stage.

## 2026-03-27 FastQC extraction and interpretation

- Extracted 12 FastQC zip reports into `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/fastqc_extracted`.
- Parsed every `summary.txt` and `fastqc_data.txt` file and wrote the interpreted report to `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/fastqc_review/fastqc_interpreted_report.md`.
- Confirmed project-wide high raw read quality with persistent tile-quality, duplication, and reverse-read PolyG/GC anomalies that should be addressed during trimming.

## 2026-03-28 Trimmomatic preparation milestone

- Added `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/prepare_trimmomatic_inputs.sh` to validate paired FASTQ inputs, create step directories, copy raw reads into a separate trimming workspace, and append prep actions to `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/logs/prepare_trimmomatic_inputs.log`.
- Ran the prep script successfully and generated `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/metrics/trimmomatic_input_manifest.tsv` covering all 6 paired-end samples.
- Added `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/trimmomatic_array.slurm` as a reusable SLURM array script that trims only the copied reads and writes per-task stdout/stderr logs into the new trimmomatic step directory.
- Confirmed local HPC prerequisites for the batch script: Java is available, `trimmomatic/0.39` is installed on the cluster, `TruSeq3-PE.fa` is present, and both scripts pass `bash -n` syntax checks.
## 2026-04-09 Post-trim FastQC extraction and interpretation

- Added `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/extract_fastqc_trimmed_reports.sh` and `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/analyze_fastqc_trimmed_reports.py` to reproducibly extract and interpret trimmed-read FastQC outputs.
- Extracted 12 trimmed FastQC zip reports into `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/fastqc_trimmed_extracted` and wrote the review outputs to `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/fastqc_trimmed_review`.
- Verified that trimming removed the raw reverse-read overrepresented-sequence failures and resolved the strongest GC-content anomaly, while forward-read tile-quality failures and duplication remained.

## 2026-04-10 BWA-MEM alignment preparation milestone

- Added `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/configs/alignment_manifest.tsv` listing all 6 trimmed read pairs with relative paths for array-based alignment.
- Added `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/bwa_align_array.slurm` as a reusable SLURM array script that validates paired trimmed reads, loads `bwa` and `samtools`, aligns against `reference/v_vulnificus_ref.fasta`, writes sorted BAM outputs under `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/alignment/bam`, and writes `flagstat` plus `idxstats` reports under `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/alignment/metrics`.
- Created the stage-specific alignment directories `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/alignment/bam`, `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/alignment/logs/slurm`, and `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/alignment/metrics`.
- Updated `.gitignore` so generated alignment BAMs and SLURM logs remain out of Git while alignment manifests, scripts, and the curated TSV summary can be tracked.

## 2026-04-12 Alignment metrics review and documentation update

- Verified that `scripts/summarize_alignment_metrics.sh` passes `bash -n`, runs successfully, and reproduces `alignment/metrics/alignment_summary.tsv` from the per-sample `flagstat` and `idxstats` files.
- Confirmed that `alignment/metrics/alignment_summary.tsv` is internally consistent: `idx_mapped_sum` matches the `flagstat` mapped count for all 6 samples, and each `idxstats` file reports the two expected reference contigs plus the `*` unmapped row.
- Confirmed that the saved alignment SLURM script needed one reproducibility fix: the reference path now matches the checked-in FASTA at `reference/v_vulnificus_ref.fasta`.
- Recorded the observed alignment-rate spread across samples: `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` at `1.05%`, `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` at `10.86%`, `Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` at `30.57%`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7` at `81.57%`, `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7` at `87.51%`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7` at `88.12%`.

## 2026-04-13 Multi-reference alignment preparation milestone

- Added `configs/multi_reference_reference_manifest.tsv` to track the 5 candidate references with relative FASTA paths, reference-format annotations, and notes about how to interpret draft versus closed genomes.
- Added `scripts/bwa_align_multiref_array.slurm` as a reusable SLURM array workflow that expands the saved 6-sample trimming manifest across all 5 references, validates paired reads plus BWA and samtools reference sidecars, and writes stage-specific outputs under `multi_reference_alignment/`.
- Added `scripts/summarize_multiref_alignment_metrics.py` to combine the per-combination `flagstat` and `idxstats` files into a long-form summary table and a mapped-percentage matrix for all 30 sample-reference combinations.
- Verified from the checked-in FASTA indexes that the two `Vibrio ostreicida` references are not a blocking format error for `bwa` or `samtools`, but they are draft multi-contig assemblies (`33` contigs for `v_ostreicida_PP203` and `81` contigs for `v_ostreicida_r172`) rather than two-chromosome closed references.
- Implemented the multi-contig workaround in the new scripts by validating each reference with its `.fai`, recording the reference format from the manifest, and aggregating `idxstats` across all contigs instead of assuming a fixed chromosome count.

## 2026-04-13 Multi-reference alignment review completed

- Confirmed that the full 30-task comparison run completed and produced the curated outputs `multi_reference_alignment/metrics/multi_reference_alignment_summary.tsv` and `multi_reference_alignment/metrics/multi_reference_alignment_mapped_pct_matrix.tsv`.
- Verified the strongest reference match for `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7` (`87.51%`), `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7` (`81.57%`), `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7` (`88.12%`), and `Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` (`30.57%`) remains the current `Vibrio vulnificus` reference.
- Verified that `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` aligns best to the `Vibrio alginolyticus` reference at `43.84%`, exceeding its `Vibrio parahaemolyticus` (`31.18%`) and `Vibrio vulnificus` (`10.86%`) mapping rates.
- Confirmed that `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` remains a low-alignment outlier against all five references, with mapped percentages clustered near `1%`.
- Preserved the per-combination BAMs, `flagstat`, and `idxstats` files under the dedicated `multi_reference_alignment/` stage while keeping only the curated TSV summaries intended for Git tracking.

## 2026-04-14 Kraken2 database preparation milestone

- Added `scripts/kraken2_build_bacterial_db.slurm` as a reusable SLURM script that uses Singularity rather than environment modules to build a bacteria-focused Kraken2 database in the new `kraken2_db/` stage.
- Added `kraken2_db/README.md` to document the intended container input, expected runtime outputs, conservative storage guardrails, and the assumption that a bacteria-only database is the most appropriate next taxonomic screen after the ambiguous multi-reference alignment results.
- Configured the new SLURM workflow to record build parameters plus before/after disk-usage snapshots under `kraken2_db/metadata/` and to abort early if project or temporary free space is below conservative thresholds.
- Updated `.gitignore` so the large Kraken2 database files and SLURM logs remain outside Git while the stage documentation and future small metadata records can remain trackable.
- Did not submit or run the Kraken2 build job.

## 2026-04-16 Kraken2 build troubleshooting and retry hardening

- Reviewed the two saved Kraken2 SLURM runs under `kraken2_db/logs/slurm` and confirmed that job `1319090` failed during taxonomy download because the containerized `rsync` path hit `Unknown module 'pub'`.
- Confirmed that job `1319091` successfully launched Singularity, downloaded taxonomy into `kraken2_db/db/taxonomy`, and then failed during the RefSeq bacteria library transfer because repeated FTP attempts for `GCF_022220625.1_ASM2222062v1_genomic.fna.gz` ended with `Connection closed`.
- Verified that the Kraken2 stage remains incomplete because `kraken2_db/db/hash.k2d`, `kraken2_db/db/opts.k2d`, and `kraken2_db/db/taxo.k2d` are still absent.
- Updated `scripts/kraken2_build_bacterial_db.slurm` so the bacteria-library download step now retries transient failures with configurable `KRAKEN2_DOWNLOAD_MAX_ATTEMPTS` and `KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC` settings, clearer retry logging, and explicit checks for `library/bacteria/assembly_summary.txt` plus `manifest.txt` before the build step.
- Updated `kraken2_db/README.md` and `NEXT_STEPS.md` so the failed job history, FTP recommendation, and resubmission guidance are documented for the next cluster submission.

## 2026-04-17 Kraken2 database build verification completed

- Reviewed all three Kraken2 build jobs under `kraken2_db/logs/slurm` and confirmed that job `1319269` is the first successful end-to-end run, finishing on `2026-04-17 09:50:55 CDT`.
- Verified that the expected final database files now exist at `kraken2_db/db/hash.k2d`, `kraken2_db/db/opts.k2d`, and `kraken2_db/db/taxo.k2d`, with `hash.k2d` occupying about `93G`.
- Confirmed from `kraken2_db/metadata/disk_usage_after_job_1319269.tsv` that the cleaned database footprint is about `100G`, consistent with the completed build log.
- Recorded a stage-specific interpretation in `kraken2_db/metadata/kraken2_build_verification_2026-04-17.md` documenting that the database build succeeded and is usable, but the successful run still logged one transient FTP fetch failure and two gzip-corrupt downloaded genomes during library processing.
- Concluded that the Kraken2 stage is complete enough for downstream classification, while noting that the RefSeq bacteria snapshot used for this build may be missing a very small number of source genomes because the successful run was not perfectly clean at the individual-download level.

## 2026-04-17 Kraken2 sample-classification stage prepared

- Added `configs/kraken2_classification_manifest.tsv` so the Kraken2 stage has its own saved manifest of the 6 paired trimmed read sets, using relative paths under `trimmomatic/trimmed_reads/`.
- Added `scripts/kraken2_classify_array.slurm` as a reusable SLURM workflow that classifies one saved sample pair per array task against `kraken2_db/db/`, writes one Kraken2 output file plus one Kraken2 report per sample under `kraken2_classification/`, and supports a `summary` mode for post-run aggregation.
- Added `scripts/summarize_kraken2_classification.py` to parse the saved Kraken2 reports, rank species-level hits before genus-level hits, and write the curated summary table `kraken2_classification/metrics/kraken2_classification_summary.tsv`.
- Added `kraken2_classification/README.md` to document that Kraken2 uses paired trimmed FASTQ inputs rather than FastQC artifacts, to describe expected stage outputs, and to record the interpretation labels `strong species fit`, `genus-level only fit`, `mixed/ambiguous`, and `mostly unclassified`.
- Updated `.gitignore` so per-sample Kraken2 outputs, reports, and SLURM logs stay outside Git while the curated TSV summary can remain trackable.

## 2026-04-17 Kraken2 sample-classification summary completed

- Verified from `kraken2_classification/logs/slurm/kraken2_classify_1319693_*.out` and matching `.err` files that the 6-sample Kraken2 array job completed and wrote one output plus one report for each trimmed paired sample.
- Identified why the original summary submission `1319701` failed: the parser compared the Kraken2 output line count to the report `root` row, but the `root` row records only classified reads, not total reads including the `unclassified` row.
- Corrected `scripts/summarize_kraken2_classification.py` so the summary step now derives total reads from the saved report counts and only uses the Kraken2 output files as non-empty existence checks.
- Regenerated `kraken2_classification/metrics/kraken2_classification_summary.tsv` successfully from the saved reports.
- Confirmed the current taxonomic split across the 6 samples: 3 strong `Vibrio vulnificus` fits (`Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`), 1 strong non-`vulnificus Vibrio` fit (`Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` as `Vibrio cidicii`), 1 genus-level `Vibrio` but species-ambiguous sample (`Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7`), and 1 likely non-`Vibrio` outlier (`Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` with a dominant `Bacillus` genus signal).

## 2026-04-18 SPAdes assembly preparation milestone

- Added `configs/assembly_manifest.tsv` listing all 6 trimmed read pairs with relative paths for the assembly stage.
- Added `scripts/spades_assembly_array.slurm` as a reusable SLURM array script that validates paired trimmed reads, writes one sample-specific assembly directory under `assembly/assemblies/`, records per-task logs under `assembly/logs/`, and supports a `summary` mode for post-run metric collation.
- Added `scripts/summarize_spades_assemblies.py` to compute contig and scaffold counts, total assembled bases, N50, longest sequence, GC percentage, and the number of sequences at least `1000 bp`, then write the curated table `assembly/metrics/assembly_summary.tsv`.
- Added `assembly/README.md` plus `assembly/metrics/spades_parameters.txt` so the assembly stage has documented inputs, outputs, resource defaults, and completion checks before submission.
- Updated `.gitignore` so bulky assembly outputs and runtime logs remain outside Git while the parameter record and curated summary TSV can stay trackable.

## 2026-04-18 ANI preparation milestone

- Added `configs/ani_query_manifest.tsv` so ANI queries come from `assembly/assemblies/<sample_id>/contigs.fasta` in a saved manifest-driven format.
- Added `configs/ani_reference_manifest.tsv` so ANI comparisons use the same tracked reference genomes already used by the alignment stages.
- Added `scripts/fastani_array.slurm` as a reusable SLURM array script that validates assembled query FASTA files, resolves the reference manifest automatically, writes one raw fastANI output file per sample under `ani/outputs/`, and supports a `summary` mode for post-run collation.
- Added `scripts/summarize_fastani.py` to combine the raw fastANI outputs into a long-form summary table plus a sample-by-reference ANI matrix, with threshold-based interpretation labels for likely `Vibrio vulnificus`, likely other species, or outlier status.
- Added `ani/README.md` plus `ani/metrics/fastani_parameters.txt` so the ANI stage has documented dependencies, inputs, outputs, interpretation thresholds, and completion checks before submission.
- Updated `.gitignore` so bulky ANI outputs and runtime logs remain outside Git while the parameter record and curated ANI TSV summaries can stay trackable.

## 2026-04-20 Assembly interpretation review and isolate-rerun preparation

- Reviewed the completed SPAdes outputs under `assembly/assemblies/` together with `kraken2_classification/metrics/kraken2_classification_summary.tsv`, `alignment/metrics/alignment_summary.tsv`, and `multi_reference_alignment/metrics/multi_reference_alignment_summary.tsv`.
- Confirmed that the original 6-sample assembly run completed only after three failed SPAdes-resolution attempts and one successful container-backed submission (`1319742`), then regenerated the missing curated file `assembly/metrics/assembly_summary.tsv` from the saved assembly outputs.
- Interpreted the first-pass assembly metrics as poor for isolate-scale downstream use: all 6 assemblies are highly fragmented and inflated in total size, with scaffold totals from about `18.7 Mb` to `65.2 Mb`, indicating that the current outputs should not be treated as strong finished genomes.
- Confirmed that `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` is the strongest non-target or contamination candidate because Kraken2 is dominated by `Bacillus` and all tested Vibrio references map at only about `1%`.
- Confirmed that `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` remains a mixed or unresolved `Vibrio` sample because Kraken2 species calls are split and the best tested reference fit is `Vibrio alginolyticus` rather than `Vibrio vulnificus`.
- Confirmed that the best current `Vibrio vulnificus` candidates remain `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, because they have strong Kraken2 `Vibrio vulnificus` calls and strong `Vibrio vulnificus` alignment rates even though their first-pass assemblies still look poor.
- Updated `scripts/spades_assembly_array.slurm` so the workflow now supports `MANIFEST_FILE` and `STAGE_DIR` overrides, logs the chosen stage and extra arguments, defaults to `--isolate` for bacterial isolate reruns unless explicitly overridden, and uses `bash -c` rather than `bash -lc` inside the containerized execution path to reduce shell-init noise in SLURM logs.
- Added `configs/assembly_manifest_vulnificus_candidates.tsv` to define a focused 3-sample rerun set for the strongest current `Vibrio vulnificus` candidates.
- Added the new comparison stage `assembly_isolate_rerun/` with `README.md` and `metrics/spades_parameters.txt` so the isolate-oriented rerun can be submitted reproducibly without overwriting the original `assembly/` outputs.
## 2026-05-05 SNP phylogeny branch scaffolded

- Audited the confirmed *Vibrio vulnificus* isolate inputs and located paired trimmed reads for `Buck_BS0607_9`, `Buck_CB0707_82`, and `Buck_NB0507_8` under `trimmomatic/trimmed_reads/`.
- Confirmed the existing ATCC 27562 reference FASTA at `reference/v_vulnificus_ref.fasta`; the FASTA header identifies *Vibrio vulnificus* NBRC 15645 = ATCC 27562 chromosome 1.
- Confirmed the reference already has BWA index sidecars and a samtools FASTA index: `.amb`, `.ann`, `.bwt`, `.pac`, `.sa`, and `.fai`.
- Added the manifest-driven SNP phylogeny scaffold: `configs/snp_manifest.tsv`, `snp_phylogeny/README.md`, and stage-specific output directories for logs, BAM, VCF, core alignment, and tree outputs.
- Added reusable scripts for reference preparation, BWA alignment, FreeBayes calling with monomorphic-site reporting, core SNP alignment construction, and FastTree tree building.
- Added scoped `.gitignore` rules so future SNP BAM, VCF, and runtime logs remain out of Git while interpreted core alignment and tree outputs can be tracked if desired.

## 2026-05-05 Ambiguous isolate taxonomic-filtering branch scaffolded

- Added `configs/taxon_filter_manifest.tsv` for `Buck_BI0607_1`, `Buck_NB0507_14`, and `Buck_BI0607_2`, using the existing trimmed read paths plus existing Kraken2 output/report paths.
- Created the separate `ambiguous_isolate_resolution/taxonomic_filtering/` stage with directories for logs, read IDs, filtered reads, downsampled reads, assemblies, and metrics.
- Added `scripts/filter_fastq_by_kraken_taxon.py` and `scripts/filter_taxon_reads_array.slurm` to retain read pairs with target genus evidence from existing Kraken2 per-read classifications.
- Added `scripts/downsample_paired_fastq.py` and `scripts/downsample_taxon_filtered_reads_array.slurm` for reproducible paired downsampling to 1,000,000 pairs when needed.
- Added `scripts/spades_taxon_filtered_array.slurm` to reassemble downsampled target-taxon reads using the existing SPAdes Singularity image at `containers/spades.sif` when available.
- Added `scripts/summarize_taxon_filtered_assemblies.py` and `ambiguous_isolate_resolution/taxonomic_filtering/README.md` to document the workflow and summarize whether assemblies move toward expected bacterial genome size.

## 2026-05-05 Mullis 2019 expanded reference scaffolded

- Resolved all 42 Mullis et al. 2019 Table 1 WGS accessions to corresponding NCBI Assembly accessions and genome FASTA FTP URLs using NCBI Assembly E-utilities for BioProject `PRJNA475262`.
- Added `reference/expanded_vv/metadata/mullis2019_genome_downloads.tsv` with isolate, WGS accession, Assembly accession, download URL, local filename, provenance, and notes fields.
- Added `scripts/download_mullis2019_genomes.sh` to perform resumable downloads into `reference/expanded_vv/downloads/`, validate gzip files, and link valid genomes into `reference/expanded_vv/genomes/`.
- Added `scripts/validate_mullis2019_genomes.sh` to report metadata counts, resolved URLs, downloaded genome files, gzip status, and missing resolved genomes.
- Updated `reference/expanded_vv/README.md` with purpose, citation, WGS-to-Assembly handling, directory structure, exact commands, and the warning not to use this expanded set in the current 3-isolate SNP pipeline.
- Confirmed the metadata table has 42 data rows, 42 resolved FTP URLs, 0 unresolved rows, and valid 7-column formatting; did not submit jobs or run the full download script.

## 2026-05-26 Mullis 2019 FastANI reference manifest prepared

- Added `configs/ani_reference_manifest_mullis2019.tsv` for the existing `scripts/fastani_array.slurm` workflow, with 42 `mullis2019_<isolate>` reference rows pointing to the downloaded genomes under `reference/expanded_vv/genomes/`.
- Added `configs/ani_reference_manifest_mullis2019_plus_buck_atcc.tsv` with the 42 Mullis genomes plus the 3 selected Buck *Vibrio vulnificus* subsampled scaffold assemblies and the ATCC 27562 project reference, for 46 reference rows plus the header.
- Preserved the expanded-reference separation by keeping the Mullis genomes in `reference/expanded_vv/` and not mixing them into the default `configs/ani_reference_manifest.tsv` or the active SNP phylogeny reference set.
- Validated the new manifest structure: 42 data rows, 4 non-empty tab-delimited fields per row, and all listed genome paths present.
- Validated the expanded plus manifest structure: 46 data rows, 4 non-empty tab-delimited fields per row, all listed reference paths present, gzip-valid compressed genomes, and FASTA-like uncompressed Buck/ATCC references.
- Re-ran `bash scripts/validate_mullis2019_genomes.sh`; validation passed with 42 metadata rows, 0 unresolved rows, 42 expected downloadable genomes, 42 valid downloads, and 42 valid genome entries.

## 2026-05-27 Expanded RAxML-NG tree figure refreshed

- Updated `scripts/plot_expanded_vv_raxml_tree.R` to simplify the three selected Buck isolate labels in the figure while preserving the full tree and metadata IDs for matching.
- Added explicit evolutionary-distance x-axis labeling and comments documenting that branch lengths represent expected substitutions per site.
- Expanded the plotting x-range, right margin, legend spacing, and export dimensions so right-side tip labels and legends remain readable in the final static figure.
- Regenerated `phylogeny/expanded_vv_46/tree/raxmlng/expanded_vv_46_raxml_tree.pdf` and `phylogeny/expanded_vv_46/tree/raxmlng/expanded_vv_46_raxml_tree.png`; the PNG export is now `4500 x 3000` pixels.

## 2026-05-27 Expanded 46-genome vcg-marker workflow scaffolded

- Added a separate vcg-only phylogeny stage under `phylogeny/expanded_vv_46/vcg_tree/` with `blast/`, `extracted_sequences/`, `alignment/`, `tree/`, `metadata/`, `figures/`, and `logs/` subdirectories.
- Added reusable scripts for expanded-set vcg mining, best-hit sequence extraction, MAFFT alignment, FastTree tree building, R plotting, and an optional ordered driver script.
- Added `scripts/run_expanded_vv_vcg_tree_workflow.slurm` so the full workflow can be submitted safely as a compute job instead of run on the login node.
- Kept this workflow separate from the whole-genome Parsnp/RAxML-NG tree; no Parsnp, RAxML-NG, raw reads, original assemblies, or existing RAxML outputs were modified.
- Added `phylogeny/expanded_vv_46/vcg_tree/README.md` documenting step-by-step execution, expected outputs, and how to compare the vcg-marker tree with the whole-genome RAxML-NG tree.
- Validated the new shell scripts with `bash -n`; R plotting syntax was not executed because `Rscript` is not currently available in the active shell.

## 2026-08-14 Project-wide reference manifest initialized

- Added `configs/reference_sequence_manifest.tsv` as the current project-wide dictionary of available reference sequences, using the same four-column schema consumed by existing alignment and ANI scripts: `reference_id`, `reference_fasta`, `reference_format`, and `notes`.
- Included all currently available reference files under `reference/`: 5 top-level species FASTA references and 42 Mullis et al. 2019 expanded *Vibrio vulnificus* draft genomes under `reference/expanded_vv/genomes/`.
- Added `scripts/validate_reference_manifest.sh` to verify manifest structure, listed file presence, gzip integrity for compressed genomes, and `.fai` sidecar indexes for plain FASTA references.
- Ran `bash scripts/validate_reference_manifest.sh`; validation passed with 47 rows, 5 plain FASTA rows, 5 indexed plain FASTA rows, and 42 gzip FASTA rows.

## 2026-08-14 Added non-Mullis Vibrio vulnificus strain 24-VB00699

- Confirmed NCBI Assembly `GCF_056820805.1` as *Vibrio vulnificus* strain `24-VB00699`, assembly name `ASM5682080v1`, Complete Genome, RefSeq/GenBank identical, with BioSample `SAMN57199157`.
- Downloaded the RefSeq genomic FASTA from NCBI into `reference/v_vulnificus_non_mullis/downloads/GCF_056820805.1_ASM5682080v1_genomic.fna.gz`.
- Validated the downloaded gzip and linked it into `reference/v_vulnificus_non_mullis/genomes/`.
- Added provenance metadata in `reference/v_vulnificus_non_mullis/metadata/reference_downloads.tsv` and documented the new non-Mullis reference directory in `reference/v_vulnificus_non_mullis/README.md`.
- Updated `configs/reference_sequence_manifest.tsv` with `vv_24_vb00699` so existing manifest-driven scripts can discover the new reference.

## 2026-08-14 Added non-Mullis Vibrio vulnificus strain 2142-77

- Confirmed NCBI Assembly `GCF_009665475.1` as *Vibrio vulnificus* strain `2142-77`, assembly name `ASM966547v1`, Complete Genome, RefSeq/GenBank identical, with BioSample `SAMN10702673`.
- Noted that NCBI reports taxonomy-check status `Inconclusive` for this assembly, even though the Assembly organism and species fields are *Vibrio vulnificus*.
- Downloaded the RefSeq genomic FASTA from NCBI into `reference/v_vulnificus_non_mullis/downloads/GCF_009665475.1_ASM966547v1_genomic.fna.gz`.
- Validated the downloaded gzip and confirmed the FASTA contains chromosome records `NZ_CP035731.1` and `NZ_CP035732.1`.
- Linked the validated genome into `reference/v_vulnificus_non_mullis/genomes/`, updated `reference/v_vulnificus_non_mullis/metadata/reference_downloads.tsv`, and added `vv_2142_77` to `configs/reference_sequence_manifest.tsv`.

## 2026-08-14 Added batch of non-Mullis Vibrio reference genomes

- Confirmed 12 requested NCBI Assembly accessions with E-utilities and found one Assembly record for each accession.
- Added two additional non-Mullis *Vibrio vulnificus* genomes: `vv_7356` from `GCF_046581405.1` and `vv_env1` from `GCF_003047125.1`.
- Added five *Vibrio cidicii* genomes under `reference/v_cidicii_non_mullis/`: `vcidicii_2423_01`, `vcidicii_vc01`, `vcidicii_2020rz130`, `vcidicii_pnusav005519`, and `vcidicii_2538_88`.
- Added five *Vibrio navarrensis* genomes under `reference/v_navarrensis_non_mullis/`: `vnavarrensis_atcc_51183`, `vnavarrensis_20_vb00237`, `vnavarrensis_2462_79`, `vnavarrensis_08_2462`, and `vnavarrensis_pnusav006652`.
- Downloaded RefSeq FASTA files for the `GCF` accessions and GenBank FASTA files for `GCA_052253365.2` and `GCA_048162665.1`, which NCBI ESummary reported as GenBank-only in this intake.
- Validated gzip integrity for all 12 downloaded FASTA files, linked them into species-specific `genomes/` directories, updated species metadata tables and README files, and added all 12 references to `configs/reference_sequence_manifest.tsv`.
- Recorded NCBI taxonomy-check caveats for `GCF_015767675.1` as `Inconclusive`; all other batch accessions were reported as taxonomy-check `OK`.

## 2026-08-14 Confirmed existing Vibrio parahaemolyticus RIMD 2210633 reference accession

- Confirmed NCBI Assembly `GCF_000196095.1` as *Vibrio parahaemolyticus* RIMD 2210633 substr. RIMD 2210633, assembly name `ASM19609v1`, Complete Genome, with BioSample `SAMD00058707`.
- Verified from the NCBI assembly report that the assembly RefSeq chromosome records are `NC_004603.1` and `NC_004605.1`, matching the existing local FASTA headers in `reference/v_parahaemolyticus_ref.fasta`.
- Updated `configs/reference_sequence_manifest.tsv` so `v_parahaemolyticus` records Assembly accession `GCF_000196095.1` directly.
- Added `reference/metadata/core_reference_accessions.tsv` to track accession provenance for top-level core references without duplicating already-present reference FASTA files.

## 2026-08-14 Added non-core Vibrio parahaemolyticus reference genomes

- Confirmed four requested *Vibrio parahaemolyticus* NCBI Assembly accessions with E-utilities: `GCF_001558495.2` strain ATCC 17802, `GCF_057321345.1` strain vp18, `GCF_013393865.1` strain LVP2, and `GCF_009665495.1` strain 2012AW-0154.
- Downloaded the RefSeq genomic FASTA files into `reference/v_parahaemolyticus_non_core/downloads/`, validated gzip integrity, and linked valid genomes into `reference/v_parahaemolyticus_non_core/genomes/`.
- Added `reference/v_parahaemolyticus_non_core/README.md` and `reference/v_parahaemolyticus_non_core/metadata/reference_downloads.tsv` to document accession provenance and local filenames.
- Added manifest rows `vpara_atcc_17802`, `vpara_vp18`, `vpara_lvp2`, and `vpara_2012aw_0154` to `configs/reference_sequence_manifest.tsv`.
- Noted that all four NCBI Assembly summaries reported taxonomy-check status `OK`; `vp18` includes chromosome and plasmid FASTA records.

## 2026-08-14 Added alginolyticus, diabolicus, and ostreicida reference batch

- Confirmed 12 requested NCBI Assembly accessions with E-utilities for *Vibrio diabolicus*, *Vibrio alginolyticus*, and *Vibrio ostreicida*; all exact requested accessions resolved and reported taxonomy-check status `OK`.
- Verified `GCF_000354175.2` as the existing top-level *Vibrio alginolyticus* ATCC 17749 reference because the NCBI assembly report maps to local chromosomes `NC_022349.1` and `NC_022359.1`; no duplicate FASTA was downloaded for that assembly.
- Downloaded 11 non-duplicate RefSeq genomic FASTA files into species-specific directories: `reference/v_alginolyticus_non_core/`, `reference/v_diabolicus_non_core/`, and `reference/v_ostreicida_non_core/`.
- Validated gzip integrity for all 11 new downloads and linked them into the corresponding `genomes/` directories.
- Added accession metadata and README files for the three new species-specific directories, updated `reference/metadata/core_reference_accessions.tsv` for `v_alginolyticus`, and added 11 new rows to `configs/reference_sequence_manifest.tsv`.
- Recorded that `GCF_047497145.1` and `GCF_040969975.1` had blank NCBI infraspecies strain fields in ESummary, but FASTA headers identify strains `ZJ-0` and `3098`, respectively.

## 2026-08-14 ANI matrix heatmap workflow scaffolded

- Added `configs/ani_unknown_query_manifest.tsv` with all 6 Buck assemblies as the unknown query set.
- Added `scripts/fastani_matrix_array.slurm` for rectangular FastANI runs where any normalized manifest can be used as the query set and any normalized manifest can be used as the reference set.
- Added `scripts/summarize_fastani_matrix.py` to write a long ANI table, a genome-by-genome matrix, a species max-ANI matrix, and a species mean-ANI matrix from completed FastANI outputs.
- Added `scripts/plot_fastani_matrix_heatmap.R` to render blue-to-red ANI heatmaps and highlight the six Buck assemblies with bold labels and black outlines.
- Added `ani/reference_panel_matrix/README.md` with commands for both the full reference-panel-plus-Buck matrix and the focused Buck-vs-reference-panel heatmap.
- Prepared stage directories for `ani/reference_panel_matrix/`, `ani/reference_panel_plus_unknown_matrix/`, and `ani/unknown_vs_reference_panel/`; no FastANI jobs were submitted or run on the login node.

## 2026-08-14 Diagnosed and repaired FastANI matrix array job 1465273

- Queried SLURM accounting for job `1465273` and confirmed all `fastani_matrix` array tasks failed in 0-2 seconds with exit code `1:0`, consistent with startup/script failure rather than memory or FastANI runtime failure.
- Inspected representative logs under `ani/reference_panel_matrix/logs/slurm/`; task stderr reported `reference_list_file: unbound variable` before FastANI launched.
- Repaired `scripts/fastani_matrix_array.slurm` so the containerized FastANI call uses the defined uppercase `REFERENCE_LIST_FILE` variable when passing `--rl`.
- Verified `scripts/fastani_matrix_array.slurm` with `bash -n`.
- Ran a non-compute dry run for array task 0 using `CONTAINER_RUNTIME=printf`; the script now reaches the container command construction without the previous unbound-variable failure and stops only because the dry-run runtime does not create a FastANI output file.
