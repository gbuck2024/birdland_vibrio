# vcg Screening for Unresolved Isolates

This stage reuses the existing `scripts/vcg_mining_array.slurm` workflow to
screen the three unresolved taxon-filtered reassemblies for the saved
`vcgC`/`vcgE` reference alleles.

It is intentionally separate from the confirmed `vcg_mining/` stage so the
results for unresolved isolates do not mix with the confirmed
`Vibrio vulnificus` assemblies.

## Scope

The target reassemblies are the Kraken-guided downsampled assemblies from
`ambiguous_isolate_resolution/taxonomic_filtering/assemblies/`:

- `Buck_BI0607_1_Vibrio`
- `Buck_BI0607_2_Bacillus`
- `Buck_NB0507_14_Vibrio`

Current interpretation motivating this screen:

- `Buck_BI0607_1`: downsampled/taxon-filtered assembly reported at about `4.3 Mb`
- `Buck_BI0607_2`: downsampled/taxon-filtered assembly reported at about `4.1 Mb`
- `Buck_NB0507_14`: downsampled/taxon-filtered assembly reported at about `6.1 Mb`

These sizes are much closer to expected bacterial genome scale than the
inflated original assemblies, so checking for `vcgE` or `vcgC` is a reasonable
follow-up for additional confirmation that they are not true
`Vibrio vulnificus` isolates.

## Inputs

- `configs/ambiguous_vcg_mining_manifest.tsv`
- `ambiguous_isolate_resolution/taxonomic_filtering/assemblies/*/scaffolds.fasta`
- `vcg_mining/references/vcg_reference_alleles.fasta`
- `scripts/vcg_mining_array.slurm`
- `scripts/summarize_vcg_hits.py`

## Outputs

- `ambiguous_isolate_resolution/vcg_mining/results/*.vcg.blast.tsv`
- `ambiguous_isolate_resolution/vcg_mining/results/vcg_best_hits_summary.tsv`
- `ambiguous_isolate_resolution/vcg_mining/results/blast_db/`
- `ambiguous_isolate_resolution/vcg_mining/logs/*.makeblastdb.log`
- `ambiguous_isolate_resolution/vcg_mining/logs/slurm/vcg_mining_<jobid>_<taskid>.out`
- `ambiguous_isolate_resolution/vcg_mining/logs/slurm/vcg_mining_<jobid>_<taskid>.err`

## Submission pattern

Do not run these BLAST searches on the login node.

```bash
sbatch \
  -o ambiguous_isolate_resolution/vcg_mining/logs/slurm/vcg_mining_%A_%a.out \
  -e ambiguous_isolate_resolution/vcg_mining/logs/slurm/vcg_mining_%A_%a.err \
  --export=ALL,MANIFEST_FILE=configs/ambiguous_vcg_mining_manifest.tsv,STAGE_DIR=ambiguous_isolate_resolution/vcg_mining \
  --array=0-2 \
  scripts/vcg_mining_array.slurm
```

After the array completes:

```bash
sbatch \
  -o ambiguous_isolate_resolution/vcg_mining/logs/slurm/vcg_mining_%A_summary.out \
  -e ambiguous_isolate_resolution/vcg_mining/logs/slurm/vcg_mining_%A_summary.err \
  --export=ALL,VCG_MODE=summary,MANIFEST_FILE=configs/ambiguous_vcg_mining_manifest.tsv,STAGE_DIR=ambiguous_isolate_resolution/vcg_mining,SUMMARY_OUT=ambiguous_isolate_resolution/vcg_mining/results/vcg_best_hits_summary.tsv \
  scripts/vcg_mining_array.slurm
```

The reusable script now falls back to
`vcg_mining/references/vcg_reference_alleles.fasta` when `STAGE_DIR` is pointed
at this ambiguous-isolate stage and no stage-local reference FASTA is present.

## Completion checks

Verify:

- three per-sample BLAST output tables exist under `results/`
- `results/vcg_best_hits_summary.tsv` exists
- the summary reports either `vcgC`, `vcgE`, or `no` best-hit status for each
  unresolved sample

Interpretation should stay conservative: a missing `vcg` hit or a weak/non-best
hit supports keeping these isolates out of the confirmed `Vibrio vulnificus`
branch, but this screen alone does not replace broader ANI or taxonomy QC.

## Result

The ambiguous-isolate `vcg` BLAST array completed for the three target
taxon-filtered reassemblies. The per-sample BLAST tables were present but empty,
and `results/vcg_best_hits_summary.tsv` reports `best_hit_found=no` for:

- `Buck_BI0607_1`
- `Buck_BI0607_2`
- `Buck_NB0507_14`

No `vcgC` or `vcgE` hit was detected in these three unresolved assemblies under
the saved `blastn` settings.
