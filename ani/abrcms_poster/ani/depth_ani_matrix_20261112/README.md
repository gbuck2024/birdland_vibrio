# Four comparable Buck depth ANI/AF panels

## Question and input contract

How do six Buck assembly comparisons change between original trimmed-read depth and nominal 25×, 50×, and 100× subsamples? The original 82×82 panel is the completed `ani/reference_panel_plus_unknown_matrix/` run. Its 76 NCBI/Mullis reference genomes and six original Buck SPAdes contig assemblies define the row/column order. Each new condition substitutes the six corresponding contig assemblies from `gc_coverage_kraken_depth_20261111/metrics/assembly_summary.tsv` while retaining those 76 references. The three new `buck_manifest.tsv` files map each depth ID to its exact contigs FASTA. `parameters.tsv` records source hashes and fastANI settings. The labels 25×, 50×, and 100× are nominal downsampling targets, not measured mapped coverage.

All four conditions have **one ANI matrix and one query-direction alignment-fraction (AF) matrix**, each 82×82. The three new depth stages will also generate the same long table, AF-filtered ANI matrix, and species summaries as the original script. A missing fastANI hit is `NA`; it does not establish biological absence. AF is `fragment_mappings / query_fragments`, so reversing query and reference can yield a different value. The full panel includes a same-assembly diagonal and all reference/reference comparisons, as in the original format. The six Buck rows/columns use the same isolate order across conditions but have distinct assembly IDs and FASTAs. No sample is assigned a species by these manifests.

## Status

Manifests and empty output directories were prepared and validated on 2026-11-12. **No new fastANI comparisons or depth matrices have run.** The original matrices remain at `ani/reference_panel_plus_unknown_matrix/metrics/fastani_genome_matrix.tsv` and `fastani_alignment_fraction_matrix.tsv`.

Run the read-only preflight before submitting. It checks all 82 FASTAs in each panel, manifest order and uniqueness, the 76 shared references, each depth's six Buck IDs, the reference list, and empty output destinations:

```bash
python3 scripts/validate_abrcms_depth_ani_matrices.py --mode preflight
```

## Submit the three compute arrays

From the project root, submit the existing `scripts/fastani_matrix_array.slurm` with an isolated stage and stage-specific Slurm logs. The same 76 references and six depth assemblies appear on both axes. Each array has 82 query tasks; `%4` limits concurrency. `PREPARED_MANIFESTS=1` uses the validated immutable manifests, and `SAFE_NEW_STAGE=1` refuses to replace an existing task output.

```bash
for depth in 25x 50x 100x; do
  stage="ani/abrcms_poster/ani/depth_ani_matrix_20261112/${depth}"
  sbatch --array=0-81%4 \
    --output="${stage}/logs/slurm/fastani_%A_%a.out" \
    --error="${stage}/logs/slurm/fastani_%A_%a.err" \
    --export="ALL,STAGE_DIR=${stage},EXTRA_QUERY_MANIFEST=${stage}/buck_manifest.tsv,EXTRA_REFERENCE_MANIFEST=${stage}/buck_manifest.tsv,PREPARED_MANIFESTS=1,SAFE_NEW_STAGE=1" \
    scripts/fastani_matrix_array.slurm
done
```

Verify all 82 tasks in each array exited 0 and each `outputs/<genome_id>.fastani.tsv` exists, including valid empty no-hit files, before summarizing. Check the three log directories separately. Do not resubmit the whole array into an attempted stage; inspect failed tasks and create a new stage for any rerun.

## Summarize after successful arrays

The summary uses the existing `scripts/summarize_fastani_matrix.py` through the same batch wrapper. It writes output only after all 82 raw files exist, and the safe mode refuses an existing matrix. Run after each corresponding array succeeds:

```bash
for depth in 25x 50x 100x; do
  stage="ani/abrcms_poster/ani/depth_ani_matrix_20261112/${depth}"
  sbatch --output="${stage}/logs/slurm/fastani_summary_%j.out" \
    --error="${stage}/logs/slurm/fastani_summary_%j.err" \
    --export="ALL,ANI_MODE=matrix,STAGE_DIR=${stage},EXTRA_QUERY_MANIFEST=${stage}/buck_manifest.tsv,EXTRA_REFERENCE_MANIFEST=${stage}/buck_manifest.tsv,PREPARED_MANIFESTS=1,SAFE_NEW_STAGE=1" \
    scripts/fastani_matrix_array.slurm
done
```

Expected primary files in each depth stage: `metrics/fastani_genome_matrix.tsv`, `metrics/fastani_alignment_fraction_matrix.tsv`, and `metrics/fastani_matrix_long.tsv`. Confirm 82 data rows and 82 value columns, identical row/column IDs within each condition, 76 common reference IDs across all four panels, and six condition-specific Buck IDs. Verify the ANI/AF cells against the long table, including `NA` cells. Compare Buck placements with reciprocal AF and assembly QC before species interpretation; BI0607_2 and NB0507_14 remain especially uncertain. The original full-depth run is preserved as the baseline.

After all three summaries exit 0, run the read-only checker. It validates the original panel and all three new stages: exact raw-output sets, 82×82 layouts, 6,724 long rows per condition, and every ANI/AF matrix value against its long-table value.

```bash
python3 scripts/validate_abrcms_depth_ani_matrices.py --mode complete --depth all
```

To check a single completed depth, replace `all` with `25x`, `50x`, or `100x`. The checker cannot establish that each Slurm task exited 0; review `sacct` and per-task logs separately before declaring a run complete.
