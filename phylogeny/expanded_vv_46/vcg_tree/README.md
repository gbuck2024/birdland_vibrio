# Expanded 46-Genome vcg-Marker Tree

This workflow builds a vcg-only marker phylogeny from the genomes listed in `configs/expanded_vv_46_genome_manifest.tsv`. It is separate from the whole-genome Parsnp/RAxML-NG tree and does not rerun Parsnp or RAxML.

## Inputs

- `configs/expanded_vv_46_genome_manifest.tsv`
- `vcg_mining/vcg_reference_alleles.fasta`

The current repo stores the vcg reference at `vcg_mining/references/vcg_reference_alleles.fasta`; `scripts/mine_expanded_vv_vcg.sh` uses that as a fallback if the requested path is absent.

## Run Each Step

Run compute-heavy BLAST, MAFFT, and FastTree work in a SLURM allocation or batch job, not on the login node.

```bash
bash scripts/mine_expanded_vv_vcg.sh
bash scripts/extract_expanded_vv_vcg_sequences.sh
bash scripts/align_expanded_vv_vcg_mafft.sh
bash scripts/build_expanded_vv_vcg_fasttree.sh
module load R/gcc11/4.4.0
Rscript scripts/plot_expanded_vv_vcg_tree.R
```

## Optional Driver

The full workflow can also be run in order with:

```bash
bash scripts/run_expanded_vv_vcg_tree_workflow.sh
```

Use the driver only inside an appropriate compute allocation or as part of a SLURM submission.

For a direct SLURM submission, use:

```bash
sbatch scripts/run_expanded_vv_vcg_tree_workflow.slurm
```

Monitor it with:

```bash
squeue -u "$USER"
tail -f phylogeny/expanded_vv_46/vcg_tree/logs/expanded_vcg_tree_<jobid>.out
tail -f phylogeny/expanded_vv_46/vcg_tree/logs/expanded_vcg_tree_<jobid>.err
```

## Expected Outputs

- `blast/*.vcg.blast.tsv`: per-genome BLAST hits.
- `metadata/expanded_vv_46_vcg_calls.tsv`: one vcg call row per genome with best allele, identity, query coverage, coordinates, strand, and notes.
- `extracted_sequences/*.fasta`: one extracted vcg sequence per genome with an extractable call.
- `extracted_sequences/expanded_vv_46_vcg_sequences.fasta`: combined vcg FASTA.
- `alignment/expanded_vv_46_vcg_mafft.fasta`: MAFFT alignment.
- `tree/expanded_vv_46_vcg.fasttree.nwk`: vcg-only FastTree tree.
- `tree/expanded_vv_46_vcg.fasttree.log`: FastTree log.
- `figures/expanded_vv_46_vcg_tree.pdf`: annotated tree figure.
- `figures/expanded_vv_46_vcg_tree.png`: annotated tree figure.

The call table preserves checks against known Buck vcg calls:

- `BS0607_9 = vcgE`
- `CB0707_82 = vcgC`
- `NB0507_8 = vcgE`

## Comparing With The Whole-Genome Tree

Compare this vcg-marker tree against the whole-genome RAxML-NG tree at:

- `phylogeny/expanded_vv_46/tree/raxmlng/expanded_vv_46.raxml.support`
- `phylogeny/expanded_vv_46/tree/raxmlng/expanded_vv_46_raxml_tree.pdf`
- `phylogeny/expanded_vv_46/tree/raxmlng/expanded_vv_46_raxml_tree.png`

Use the vcg tree to inspect marker-level grouping by `vcgC`, `vcgE`, `ambiguous`, or `not_detected`. Use the RAxML-NG tree for whole-genome relatedness. Discordance between the two is expected when vcg genotype does not track the whole-genome phylogeny.
