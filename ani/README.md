# ANI Stage

This stage compares assembled query genomes against the existing reference genomes to confirm species identity from assembly-level evidence.

The original top-level `ani/` stage remains in place for the earlier six-sample preparation. New ANI runs that should not overwrite earlier outputs must use a dedicated substage, for example `ani/subsampled_best_assemblies/`.

## Intended inputs

- `configs/ani_query_manifest.tsv`
- `configs/ani_reference_manifest.tsv`
- `assembly/assemblies/<sample_id>/contigs.fasta`
- Existing reference genomes under `reference/`

Reusable overrides now supported by `scripts/fastani_array.slurm`:

- `STAGE_DIR` to redirect outputs, metrics, and logs into a new ANI substage
- `QUERY_MANIFEST` to swap in a stage-specific set of query assemblies
- `REFERENCE_MANIFEST` to pin the intended saved reference set explicitly

## Dependency

- Preferred tool: `fastANI`
- The workflow is written around `fastANI`. If it is not already available on the cluster, set `FASTANI_BIN` to the correct executable path or install/load `fastANI` before submission.
- The SLURM script will first try `FASTANI_BIN`, then `fastANI` on `PATH`, then environment modules named `fastani` or `FastANI`.

## Intended outputs

- `ani/outputs/<sample_id>.fastani.tsv`
- `ani/metrics/ani_summary.tsv`
- `ani/metrics/ani_matrix.tsv`

Substage example:

- `ani/subsampled_best_assemblies/outputs/<sample_id>.fastani.tsv`
- `ani/subsampled_best_assemblies/metrics/ani_summary.tsv`
- `ani/subsampled_best_assemblies/metrics/ani_matrix.tsv`

An outlier sample may still produce an empty raw `fastANI` output file if no reportable ANI hits are found. The summary script treats that as a valid no-hit case rather than a workflow failure.

## Submission notes

- Submit one array task per assembled sample with `sbatch --array=0-5 scripts/fastani_array.slurm`.
- After the array finishes, generate the curated ANI summaries with `sbatch --export=ALL,ANI_MODE=summary scripts/fastani_array.slurm`.
- The ANI stage is separate from assembly and does not modify assembly outputs.
- The script prefers `configs/ani_reference_manifest.tsv`, falls back to `configs/multi_reference_reference_manifest.tsv`, and only autodetects `reference/*.fasta` if no saved ANI reference manifest is present.
- For the best completed subsampled assemblies, use `configs/ani_query_manifest_subsampled_best_assemblies.tsv` together with `STAGE_DIR=ani/subsampled_best_assemblies` so the new outputs stay isolated from the earlier ANI preparation.

## Interpretation goal

- `ANI >= 95-96%` against `v_vulnificus` supports likely `Vibrio vulnificus`.
- `ANI >= 95-96%` against a different reference supports likely another species.
- Samples without a species-level ANI match should be treated as outliers or unresolved and reviewed alongside assembly quality, Kraken2, and alignment context.
