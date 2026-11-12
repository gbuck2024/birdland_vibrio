# Multi-species Vibrio genome-distance tree

## Biological question

How do the project Buck and newly sequenced SRR isolates relate to the available NCBI and Mullis Vibrio genome references across species?

## Input contract

`configs/multispecies_mash_panel.tsv` identifies 87 distinct assemblies: 34 other NCBI references, 42 Mullis references, five Buck Vibrio-enriched assemblies, and six SRR assemblies. The reference rows come from `configs/reference_sequence_manifest.tsv`; SRR rows come from `configs/ani_query_manifest_sra.tsv`. Each row retains the exact assembly path and source category. The chosen Buck assembly paths are listed directly in the panel manifest. `Buck_BI0607_2` is excluded because its available taxonomically filtered assembly is Bacillus, and an unfiltered mixed assembly would distort this Vibrio comparison. Do not treat the selected Buck assemblies as independent of other assemblies of the same isolates.

The SRR species assignments are supported by `ani/sra_vs_reference_panel/metrics/sra_reciprocal_ani_af_summary.tsv`. Buck BI0607_1 and NB0507_14 remain provisional or mixed; inspect their placement cautiously.

## Method and limits

The job sketches each complete assembly with Mash 2.3 (`k=21`, `s=10000`) and computes the complete 87-by-87 Mash distance matrix. It validates pair coverage, symmetry, diagonal zeros, and shared-hash distances, then uses `ape::nj` to infer an **unrooted neighbor-joining distance tree**. ATCC 27562 is a labeled NCBI reference tip, not a root. Branch lengths are Mash distance units, not substitutions per site or time. This is an exploratory genome-similarity tree, not a core-gene maximum-likelihood phylogeny. Assembly contamination, completeness, and draft-versus-closed status may affect placement. No bootstrap support is claimed.

Shapes and colors show provenance: gray square = NCBI reference; green diamond = Mullis reference; red circle = Buck isolate; blue triangle = SRR isolate. This provenance classification does not imply distinct biological isolates; check same-isolate metadata before interpreting close pairs.

## Species-colored, sample-labeled view

The completed tree also has a plot-only view in `figures/species_labeled_20261112_v2/`. Reference tip colors encode the species recorded in `configs/reference_sequence_manifest.tsv` (Mullis references are *V. vulnificus*). Squares identify other NCBI references and diamonds identify Mullis references. Buck assemblies are red circles and SRR assemblies are blue triangles; their colors identify the project dataset, **not** an asserted species. Only the 11 Buck/SRR assemblies have name labels. Short leader lines separate nearby names. `tip_style.tsv` gives the exact color, shape, and reference species for every tip.

Open the SVG in a browser or the PDF in a viewer to zoom without pixelation. The PNG is a convenient fixed-resolution preview. This redraw uses the saved Newick tree and does not recalculate Mash distances or change topology. Species labels for references follow the reference manifest; isolate placements remain exploratory, and Buck BI0607_1/NB0507_14 remain provisional or mixed.

To reproduce the view in a **new, empty output directory** from the project root:

```bash
Rscript scripts/plot_multispecies_mash_tree_species.R \
  configs/multispecies_mash_panel.tsv \
  configs/reference_sequence_manifest.tsv \
  phylogeny/multispecies_mash/tree/unrooted_mash_nj.nwk \
  phylogeny/multispecies_mash/figures/species_labeled_NEW_RUN
```

## Run

From the project root, after reviewing the panel manifest:

```bash
sbatch scripts/multispecies_mash_tree.slurm
```

The script creates `run.lock/` when execution starts and refuses to replace any stage output. A failed partial run needs inspection; for a new experiment, create another stage directory and adjust the script rather than reusing this one.

## Expected outputs and QC

- `phylogeny/multispecies_mash/tree/unrooted_mash_nj.nwk`
- `phylogeny/multispecies_mash/figures/unrooted_mash_nj.pdf` and `.png`
- `phylogeny/multispecies_mash/metadata/mash_distance_matrix.tsv` and `tree_qc.tsv`
- `phylogeny/multispecies_mash/metadata/input_checksums.tsv` and software versions
- `phylogeny/multispecies_mash/metadata/manifest.sha256` and `parameters.tsv`
- Mash sketches, combined sketch, and raw `distances.tsv`

A successful run requires 87 distinct tree tips, 7,569 directional distance rows, no missing/duplicate pairs, and nonempty figure and Newick files. Review negative NJ branches, if any, before interpretation. The input checksums make the exact FASTAs traceable. Report biological conclusions only after inspecting the plotted tree and assembly QC.
