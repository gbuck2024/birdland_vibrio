# Expanded V. vulnificus 46-Genome Parsnp Phylogeny

This stage prepares a reproducible core-genome alignment workflow for the expanded 46-genome *Vibrio vulnificus* panel using Parsnp in Singularity. It stages all FASTA inputs from `configs/expanded_vv_46_genome_manifest.tsv`, uses ATCC 27562 as the Parsnp reference when present, and writes Parsnp outputs under `phylogeny/expanded_vv_46/alignment/parsnp/`.

Tree building with IQ-TREE and RAxML-NG is intentionally not run in this step. Placeholder commands are generated for later use after the Parsnp alignment has been reviewed and converted/prepared as a tree-builder-compatible core-genome alignment.

## Directory Layout

- `genomes/`: staged Parsnp FASTA inputs. Gzipped FASTA files from the manifest are decompressed here; plain FASTA files are symlinked.
- `alignment/parsnp/`: Parsnp alignment output directory.
- `logs/`: preparation and SLURM runtime logs.
- `metadata/`: copied manifests, selected reference record, parameter records, and downstream command placeholders.
- `tree/`: reserved for later IQ-TREE and RAxML-NG outputs.

## Inputs

Required manifest:

```bash
configs/expanded_vv_46_genome_manifest.tsv
```

The workflow validates that this manifest contains exactly 46 genome rows plus one header row. The first column is treated as the genome identifier and the second column as the FASTA path. Additional columns are preserved as notes in the staged Parsnp manifest.

Container images expected in the project `containers/` directory:

```bash
containers/parsnp_2.1.5.sif
containers/iqtree_2.4.0.sif
containers/raxmlng_2.0.0.sif
```

## Container Smoke Test

Run this lightweight check from the project root before submitting the Parsnp job:

```bash
bash scripts/test_phylogeny_containers.sh
```

The script checks:

```bash
singularity exec containers/parsnp_2.1.5.sif parsnp --help
singularity exec containers/iqtree_2.4.0.sif iqtree2 --version
singularity exec containers/raxmlng_2.0.0.sif raxml-ng --help
```

## Prepare Parsnp Inputs

Run from the project root:

```bash
bash scripts/prepare_expanded_vv_parsnp_inputs.sh
```

This creates:

```bash
phylogeny/expanded_vv_46/genomes/
phylogeny/expanded_vv_46/alignment/
phylogeny/expanded_vv_46/logs/
phylogeny/expanded_vv_46/metadata/
phylogeny/expanded_vv_46/tree/
```

Key metadata outputs:

```bash
phylogeny/expanded_vv_46/metadata/parsnp_input_manifest.tsv
phylogeny/expanded_vv_46/metadata/parsnp_reference.txt
phylogeny/expanded_vv_46/metadata/downstream_tree_commands.sh
```

## Run Parsnp With SLURM

Submit only after preparation succeeds:

```bash
sbatch scripts/parsnp_expanded_vv_46.slurm
```

The SLURM script reruns input staging checks, validates the Parsnp container, records parameters, and runs:

```bash
singularity exec containers/parsnp_2.1.5.sif parsnp \
  -r phylogeny/expanded_vv_46/genomes/atcc_27562.fna \
  -d phylogeny/expanded_vv_46/genomes \
  -o phylogeny/expanded_vv_46/alignment/parsnp \
  -p "${SLURM_CPUS_PER_TASK}" \
  -c
```

The actual reference path is read from `phylogeny/expanded_vv_46/metadata/parsnp_reference.txt` and should resolve to the staged ATCC 27562 FASTA.

## Expected Parsnp Outputs

The SLURM job verifies that these files exist and are non-empty:

```bash
phylogeny/expanded_vv_46/alignment/parsnp/parsnp.xmfa
phylogeny/expanded_vv_46/alignment/parsnp/parsnp.tree
phylogeny/expanded_vv_46/alignment/parsnp/parsnp.snps.mblocks
phylogeny/expanded_vv_46/alignment/parsnp/parsnp.ggr
```

## Downstream Tree Placeholders

The prep script writes placeholder commands to:

```bash
phylogeny/expanded_vv_46/metadata/downstream_tree_commands.sh
```

Those commands use:

```bash
singularity exec containers/iqtree_2.4.0.sif iqtree2 ...
singularity exec containers/raxmlng_2.0.0.sif raxml-ng ...
```

Do not run those commands until the Parsnp alignment has been reviewed and converted/prepared as `phylogeny/expanded_vv_46/alignment/core_genome_alignment.fasta` or another explicitly chosen downstream alignment file.
