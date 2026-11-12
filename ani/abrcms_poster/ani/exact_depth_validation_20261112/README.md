# Exact-depth assembly validation

## Question and inputs

Compare the six Buck original full-trimmed-read assemblies with their 18
nominal 25x/50x/100x subsampled assemblies. Do assembly identity, reciprocal
alignment fraction, reference span, and independent conserved-marker recovery
change with depth? These are 24 assemblies from six isolate labels, not 24
independent biological samples. Input FASTAs and depth labels are recorded in
the prepared ANI manifests under `../depth_ani_matrix_20261112/` and the
original `ani/reference_panel_plus_unknown_matrix/` manifest.

## Methods

The already prepared 82-genome fastANI matrices provide directional ANI and
fragment-based AF for each depth. The original 82-genome matrix is the full-read
baseline. The initial coverage manifest selects one of 76 external *Vibrio* references
per assembly using reciprocal ANI and AF. A reciprocal hit with both AF values
at least 0.5 and both ANI values at least 95% is preferred, then ranked by mean
ANI. If none qualifies, the largest minimum AF is selected and flagged as
provisional. A complete *Bacillus paralicheniformis* ATCC 9945a comparator
(`NC_021362.1`) was added in a separate run for BI0607_2 because its three
depth assemblies had no fastANI hit to the *Vibrio* panel. This comparator is
provisional and does not prove species identity. The 25x choice for each isolate
then defines a fixed-reference manifest; the final cross-depth comparison uses
that same reference across all four conditions. The initial per-condition
best-reference coverage output is preserved separately.

`minimap2 -x asm10 -c --secondary=no` aligns each assembly to the selected
reference. Retained primary PAF records require MAPQ at least 20, aligned
block at least 1 kb, and identity at least 90%. Reference covered fraction is
the union of aligned reference intervals divided by all reference bases.
`reference_exactly_one_alignment_fraction` counts bases covered by exactly one
retained primary alignment. It is a unique-placement coverage measure, not a
measure of unique sequence content. The 1-to-1 reference selection and these
filters can understate divergent, repetitive, or structurally rearranged
sequence. PAF and input hashes are retained for audit.

The first PAF runs omitted `-c`, so their approximate match counts could not
support the 90% identity filter; their coverage TSVs and first combined report
are retained as a failed measurement attempt. The validated CIGAR pass is in
`fixed_reference_coverage_cigar/`, and the corrected table/report use `_v2`
filenames. The BI0607_1 25x pilot changed from 2.30% to 84.05% reference
coverage after base-level alignment, consistent with the identified filter
problem.

BUSCO 6.1.0 with `bacteria_odb12.2` is the independent conserved-marker
assessment for all 24 assemblies. Complete, single-copy, duplicated,
fragmented, and missing marker fractions will be reported. Duplicated-marker
fraction is a **contamination signal**, not an estimated fraction of foreign
genomic sequence: biological duplications and assembly errors can also raise
it, while contaminants may add no duplicated marker. BUSCO does not replace
CheckM2. The lineage is broad so it can be applied consistently to ambiguous
assemblies, but it has limited resolution for isolate-specific completeness.

## Execution order

1. Validate all three new ANI panels after their arrays and summary jobs exit
   0: `python3 scripts/validate_abrcms_depth_ani_matrices.py --mode complete
   --depth all`.
2. Create the immutable 24-row coverage manifest:
   `python3 scripts/prepare_abrcms_reference_coverage.py`.
3. Run `sbatch --array=0-23%4 scripts/abrcms_reference_coverage_array.slurm`
   for the initial per-condition reference pass. Run
   `python3 scripts/prepare_abrcms_fixed_reference_coverage.py`, then submit
   the same wrapper with `COVERAGE_MANIFEST` set to
   `fixed_reference_coverage_manifest.tsv` and `COVERAGE_OUTPUT_ROOT` set to
   `fixed_reference_coverage/`, with separate `--output`/`--error` paths.
4. After `scripts/abrcms_busco_prepare.slurm` exits 0 and its marker is present,
   run `sbatch --array=0-23%4 scripts/abrcms_busco_array.slurm`.
5. Check every array task exit code, completion marker, PAF, coverage TSV, and
   BUSCO summary before running
   `python3 scripts/report_abrcms_exact_depth_validation.py`. Use only its
   `_v2` table/report for coverage interpretation.

Each job has a stage-specific SLURM log. Existing outputs are not replaced;
task locks remain after failed attempts for diagnosis. A new stage name is
required for a changed method or rerun.

## Completed run on 2026-11-12

The three depth fastANI arrays and summaries completed with job IDs
`1566096`/`1566178` (25x), `1566179`/`1566344` (50x), and
`1566184`/`1566345` (100x); the read-only four-panel validator passed.
BUSCO setup `1566231`, pilot `1566361`, and remaining array `1566385` passed.
The separate *Bacillus* comparator array `1566356` passed after the original
`1566352` failed before output because of a CRLF manifest. The final CIGAR
coverage pilot `1566432` and remaining array `1566433` passed all 24 rows.

The reviewed machine-readable comparison is
`metrics/exact_depth_comparison_v2.tsv`; the narrative is
`metrics/exact_depth_report_v2.md`. All source outputs and failed-attempt logs
are retained. No stage should be resubmitted over its existing output paths.
