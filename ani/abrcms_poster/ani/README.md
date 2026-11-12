# ABRCMS poster GC × log10(coverage) × Kraken2 figures

## Completed full-depth figures

`gc_coverage_kraken_full_20261111/` contains seven PNG/PDF pairs: six original Buck assemblies and the separate `SRR37852095_L7` run. Filenames use `[isolate] at [depth]`; `full depth` means all retained paired reads from that run, **not** a measured numeric depth. These plots use the existing per-contig BlobToolKit master tables listed in `configs/abrcms_poster_gc_coverage_full_manifest.tsv`, including self-mapping coverage and broad Kraken2 contig labels. Zero-coverage contigs are omitted because log10(0) is undefined. Reproduce only into a new empty output directory with:

```bash
Rscript scripts/plot_poster_gc_coverage_kraken.R configs/abrcms_poster_gc_coverage_full_manifest.tsv ani/abrcms_poster/ani/NEW_EMPTY_FIGURE_DIRECTORY
```

## Six-isolate depth comparison

The existing three-isolate 25×/50×/100× assemblies came from Kraken2-filtered reads. This new comparison starts from each of the **six original trimmed paired-read sets** so it matches the full-depth plots' source material. It does not reuse or replace any earlier subset or assembly. `configs/abrcms_poster_depth_20261111_{subsample,assembly,blob}.tsv` map every condition to its source read pair and future output. The nominal targets assume a 5.2 Mb genome and two 149 bp mates; actual sequenced bases and realized coverage must be computed from the output reads. Paired records are sampled with seed `20261111`.

The downsampling array `1564907` completed on 2026-11-11 with all 18 tasks at exit code 0. All 18 paired output sets and metrics files are present. The completed submission was:

```bash
sbatch --array=0-17 scripts/abrcms_poster_downsample.slurm
```

Expected outputs are under `gc_coverage_kraken_depth_20261111/subsampled_reads/<run_id>/` and `metrics/<run_id>.subsampling_metrics.tsv`; SLURM logs go to `logs/slurm/`. The script's exclusive per-run directory creation prevents replacement on resubmission. Before assembly, verify each task completed with exit code zero, gzip integrity, synchronized read names, exact pair counts, and actual usable bases. Then assemble all 18 conditions in an isolated stage, self-map each condition's own reads to its own contigs, classify each contig with the pinned Kraken2 database, and build master tables. No selected-depth figure is valid until those outputs are checked.

The next prepared job is `sbatch --array=0-17 scripts/abrcms_poster_assemble.slurm` from the project root. Its stage-specific Slurm log directory already exists. Each batch task rescans both gzipped FASTQs for paired-read synchronization and checks the exact target count against the saved metrics before starting SPAdes. The assembly outputs are not present yet; submit only once and verify each task and its `contigs.fasta`, `scaffolds.fasta`, `params.txt`, and SPAdes log afterward.

Select one depth per isolate using a recorded comparison of total assembly span, contig count, N50, read mapping and breadth, Kraken2 composition, and where possible reciprocal ANI with aligned fraction. Treat these as different measurements; a larger N50 alone is not sufficient. Record any ambiguous choice and the realized read bases. Plot the six selected master tables with `scripts/plot_poster_gc_coverage_kraken.R` using a new three-column `isolate/depth/master_table` manifest and a new empty directory. Do not label a nominal target as measured coverage.
