# ANI Substage: Best Subsampled Assemblies

This ANI substage is reserved for the 3 best completed subsampled assemblies from `assembly_filtered_subsampled_isolate/`. It is separate from the original `ani/` stage so the new fastANI outputs and summaries do not overwrite the earlier six-sample ANI preparation.

## Why these 3 assemblies were selected

The selected assembly for each of the 3 strongest current `Vibrio vulnificus` candidates was chosen from `assembly_filtered_subsampled_isolate/metrics/assembly_summary.tsv` using the saved scaffold metrics that matter most for isolate-scale downstream comparison:

- `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7_50x`: best scaffold-count tradeoff for this sample at `419` scaffolds, with scaffold total `4,807,214 bp` and scaffold `N50 = 180,783 bp`.
- `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7_25x`: lowest scaffold count for this sample at `360` scaffolds and scaffold total `5,120,787 bp`, closest to the expected isolate-scale genome size among its 3 depth tests.
- `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7_100x`: strongest assembly for this sample with only `292` scaffolds and the highest scaffold `N50 = 437,877 bp`.

Together these 3 assemblies provide one best subsampled representative per high-confidence candidate sample while avoiding the more fragmented or less size-consistent alternatives.

## Source scaffold paths

- `assembly_filtered_subsampled_isolate/assemblies/Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7_50x/scaffolds.fasta`
- `assembly_filtered_subsampled_isolate/assemblies/Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7_25x/scaffolds.fasta`
- `assembly_filtered_subsampled_isolate/assemblies/Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7_100x/scaffolds.fasta`

The saved query manifest for this substage is `configs/ani_query_manifest_subsampled_best_assemblies.tsv`.

## Reference set

This substage uses the same intended tracked reference set as the earlier ANI preparation:

- `reference/v_vulnificus_ref.fasta`
- `reference/v_alginolyticus_ref.fasta`
- `reference/v_parahaemolyticus_ref.fasta`
- `reference/v_ostreicida_PP203_ref.fasta`
- `reference/v_ostreicida_r172_ref.fasta`

Primary manifest: `configs/ani_reference_manifest.tsv`

## Planned ANI tool and thresholds

- Tool: `fastANI`
- Query FASTA type: assembled `scaffolds.fasta`
- Default parameters: `--fragLen 3000 --kmer 16 --minFraction 0.2 --threads 8`
- Species-level interpretation target: about `95-96% ANI`
- Primary expected confirmation: best ANI hit at or above about `95-96%` to `v_vulnificus`

## Expected outputs

- `ani/subsampled_best_assemblies/outputs/<sample_id>.fastani.tsv`
- `ani/subsampled_best_assemblies/metrics/ani_summary.tsv`
- `ani/subsampled_best_assemblies/metrics/ani_matrix.tsv`
- `ani/subsampled_best_assemblies/metrics/fastani_reference_list.txt`

SLURM stdout and stderr should be written under `ani/subsampled_best_assemblies/logs/slurm/`.

## Planned submission pattern

```bash
sbatch --export=ALL,STAGE_DIR=ani/subsampled_best_assemblies,QUERY_MANIFEST=configs/ani_query_manifest_subsampled_best_assemblies.tsv,REFERENCE_MANIFEST=configs/ani_reference_manifest.tsv --array=0-2 scripts/fastani_array.slurm
sbatch --export=ALL,ANI_MODE=summary,STAGE_DIR=ani/subsampled_best_assemblies,QUERY_MANIFEST=configs/ani_query_manifest_subsampled_best_assemblies.tsv,REFERENCE_MANIFEST=configs/ani_reference_manifest.tsv scripts/fastani_array.slurm
```
