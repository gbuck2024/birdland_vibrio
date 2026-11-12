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

The assembly array `1564986` completed on 2026-11-11: all 18 tasks exited 0, and all 18 conditions have nonempty `contigs.fasta`, `scaffolds.fasta`, `params.txt`, and SPAdes logs. Its completed submission was `sbatch --array=0-17 scripts/abrcms_poster_assemble.slurm`. Those checks establish output presence; they do not yet establish assembly quality.

## Prepared post-assembly coverage, taxonomy, and QC stage

The biological question is which depth gives a useful assembly and a defensible GC-by-self-coverage/Kraken2 view for each isolate. `configs/abrcms_poster_depth_20261111_blob.tsv` maps each condition to its own sampled read pair and SPAdes contigs. The next array reuses the established BlobToolKit self-mapping, Kraken2 contig-classification, and BlobToolKit coverage scripts, with an isolated `postassembly/<short_id>/` output. It self-maps each condition's reads only to its own contigs. Kraken2 uses the existing `kraken2_db/db` database with memory mapping. Per-condition directories are exclusive locks: the array refuses to replace any prior output.

The Slurm log directory is prepared. Submit from the project root, throttling to four concurrent tasks to limit shared database and storage load:

```bash
sbatch --array=0-17%4 scripts/abrcms_poster_postassembly_array.slurm
```

The first submission, array `1565059`, failed all 18 tasks during wrapper preflight because the script rejected the valid hyphen in the sequencing-run token `WKDL250009588-1A`. No per-condition output directory was created. The validator was corrected, and the failed job's Slurm logs remain preserved.

The corrected array `1565077` completed all 18 tasks at exit 0 on 2026-11-11. All 18 per-condition completion markers, sorted BAMs, reference-name checks, Kraken2 contig outputs and reports, and BlobToolKit self-coverage JSON files are nonempty. Finalization is now the next unsubmitted stage.

After all 18 array tasks exited 0 and each `postassembly/<short_id>/COMPLETE` existed, the finalization job was submitted with:

```bash
sbatch scripts/abrcms_poster_postassembly_finalize.slurm
```

Finalization job `1565565` completed at exit 0 on 2026-11-12. Verified 18 rows in each assembly and read-base summary, 18 nonempty per-condition master tables, and 142,493 rows in the combined table. The next decision is the depth choice for each isolate; no selected-depth plot has been generated.

Finalization creates `metrics/assembly_summary.tsv`, `metrics/read_bases_and_depth.tsv`, and `metrics/all_conditions.master_contig_table.tsv`, plus per-condition master tables under `postassembly/<short_id>/metrics/`. The read-bases table scans and validates both gzipped mates and counts actual sequenced bases; its `sequenced_bases_per_assumed_genome` column divides by the configured 5.2 Mb assumption and is **not** measured mapped coverage. The assembly summary reports span, contig/scaffold count, N50, longest sequence, and GC. The master tables join BlobToolKit contig length/GC/self-mapping coverage with Kraken2 contig labels by exact contig ID. A finalization lock prevents replacing partial or completed output.

Check all 18 per-condition completion markers, summary row counts (18 plus header for the assembly and read-bases tables), Kraken2/master contig counts, and plots before choosing any depth. Self-mapping coverage is assembly-derived and cannot prove biological purity. Kraken2 labels are provisional. Compare assembly span and fragmentation, mapped fraction and breadth where available, taxon composition, and actual read bases; do not select a depth from N50 alone.

## Reviewed depth comparison (2026-11-12)

`scripts/compare_abrcms_poster_depths.py` joined the 18 assembly summaries, read-base counts, samtools flagstats, and per-condition master tables. It verified each master table against its assembly contig count and total assembled bp. The curated judgments and their rationales are in `configs/abrcms_poster_depth_decisions_20261112.tsv`. The script produced:

- `metrics/depth_comparison.tsv`: 18 condition rows with length, GC, and self-coverage quantiles, assembled-bp fractions by Kraken2 broad class, primary mapping, and assembly metrics.
- `metrics/kraken_broad_composition.tsv` and `metrics/kraken_taxon_composition.tsv`: contig-count and assembled-bp composition, including named Kraken2 labels.
- `metrics/selected_depth.tsv`: one provisional choice per isolate, confidence, reasons, ambiguities, and the exact assembly/master-table paths.
- `metrics/depth_comparison_report.md`: review summary and provenance limits.
- `figures/depth_comparison_reviewed/`: six per-isolate PDF/PNG distributions of contig length, GC, self-mapping coverage, and assembled-bp Kraken2 broad composition, generated by `scripts/plot_abrcms_poster_depth_comparison.R`.

Selections are BI0607_1 25× (medium), BI0607_2 25× (low), BS0607_9 25× (medium), CB0707_82 25× (medium), NB0507_14 25× (low), and NB0507_8 50× (medium). The first five were selected for better long-contig and taxonomic composition balance, not a fixed genome-size cutoff; NB0507_8 at 50× improves continuity with little added fragmentation. Read-mapping breadth and independent completeness estimates are unavailable. No ANI or reciprocal aligned fraction has been calculated for these exact 18 assemblies. Prior full-depth ANI is shown separately in the selection table as context, not as evidence ranking the depth assemblies. Taxonomic labels remain provisional, particularly for BI0607_2 and NB0507_14.

The 8.2 MB contig distribution plotting table and the 63 MB combined master table remain reproducible intermediates outside Git; the source per-condition tables are retained on disk. The first figure render was retained separately because rounded stacked-bar percentages produced a clipping warning. The `depth_comparison_reviewed/` figures correct that display issue and render without warnings.

The six provisional selected-depth GC-versus-coverage scatterplots are in `figures/selected_gc_coverage_20261112/` as PNG/PDF pairs. `configs/abrcms_poster_gc_coverage_selected_20261112.tsv` maps each figure to its exact per-condition master table. `scripts/plot_poster_gc_coverage_kraken.R` plots one contig per point, GC percent on x, self-mapping coverage on a log10 y scale, point size by contig length, and broad Kraken2 class by color. Titles and filenames follow `[isolate] at [nominal depth]`. It omits zero-coverage contigs because log10(0) is undefined. The six figures include, respectively, 3,774/3,903, 5,523/5,563, 6,062/6,146, 415/473, 6,095/6,113, and 340/377 positive-coverage contigs in manifest order. Regenerate into a new empty directory with:

```bash
Rscript scripts/plot_poster_gc_coverage_kraken.R configs/abrcms_poster_gc_coverage_selected_20261112.tsv ani/abrcms_poster/ani/NEW_EMPTY_FIGURE_DIRECTORY
```

The selected depths remain provisional. Review the six plots and run reciprocal ANI/AF and independent QC on the exact selected assemblies before treating species assignments or depth choices as final. Nominal depth in each title is a downsampling target, not measured mapped coverage.
