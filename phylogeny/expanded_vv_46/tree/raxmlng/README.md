# Expanded V. vulnificus 46-genome RAxML-NG tree

This directory is for the RAxML-NG maximum-likelihood tree and bootstrap-support outputs generated from the completed Parsnp core-SNP alignment.

## Final RAxML-NG Step

Input alignment:

- `phylogeny/expanded_vv_46/alignment/parsnp/parsnp.snps.mblocks`

Submit from the project root:

```bash
sbatch scripts/raxmlng_expanded_vv_46.slurm
```

The main final tree is `expanded_vv_46.raxml.support`. The `parsnp.tree` file from the alignment directory is preliminary; the RAxML-NG support tree is the final maximum-likelihood tree for interpretation.

## Inputs

- Parsnp SNP alignment: `phylogeny/expanded_vv_46/alignment/parsnp/parsnp.snps.mblocks`
- Preliminary Parsnp tree: `phylogeny/expanded_vv_46/alignment/parsnp/parsnp.tree`
- Genome metadata: `configs/expanded_vv_46_genome_manifest.tsv`
- RAxML-NG container: `containers/raxmlng_2.0.0.sif`

The `parsnp.tree` file is a preliminary tree from the alignment stage. The RAxML-NG support tree, `expanded_vv_46.raxml.support`, is the main final tree for downstream interpretation.

## Run RAxML-NG

Submit the SLURM job from the project root:

```bash
sbatch scripts/raxmlng_expanded_vv_46.slurm
```

The job uses:

- `--all`
- `--model GTR+G`
- `--bs-trees 100`
- `--threads ${SLURM_CPUS_PER_TASK}`
- `--seed 12345`
- `--prefix phylogeny/expanded_vv_46/tree/raxmlng/expanded_vv_46`

Existing RAxML-NG outputs for this prefix are not overwritten by default. To intentionally regenerate them, export `FORCE=1` before submission.

## Plot The Tree

After the RAxML-NG job completes, load R and run the plotting script from the project root:

```bash
module load R/gcc11/4.4.0
Rscript scripts/plot_expanded_vv_raxml_tree.R
```

By default, the plotting script leaves the tree unrooted. To root on ATCC 27562 only when that tip is present unambiguously, run:

```bash
Rscript scripts/plot_expanded_vv_raxml_tree.R --root-atcc
```

The script prefers `ggtree`/`ggplot2` when available and falls back to `ape`. It annotates tips with metadata-derived `source`, `group`, and `vcg_status`, and highlights Buck isolates plus the ATCC 27562 reference.

## Key Outputs

- Best maximum-likelihood tree: `expanded_vv_46.raxml.bestTree`
- Bootstrap support tree: `expanded_vv_46.raxml.support`
- Bootstrap replicate trees: `expanded_vv_46.raxml.bootstraps`
- RAxML-NG run log: `expanded_vv_46.raxml.log`
- PDF tree figure: `expanded_vv_46_raxml_tree.pdf`
- PNG tree figure: `expanded_vv_46_raxml_tree.png`
