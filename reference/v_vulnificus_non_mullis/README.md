# Non-Mullis Vibrio vulnificus References

This directory stores downloaded *Vibrio vulnificus* reference genomes that are not part of the Mullis et al. 2019 expanded environmental isolate set.

## Directory Structure

- `metadata/`: accession and provenance tables for downloaded genomes.
- `downloads/`: downloaded NCBI genome FASTA files.
- `genomes/`: validated genome entries linked from `downloads/`.

## Current Entries

- `GCF_003047125.1`: *Vibrio vulnificus* strain Env1, NCBI Assembly `ASM304712v1`, Complete Genome.
- `GCF_046581405.1`: *Vibrio vulnificus* strain 7356, NCBI Assembly `NHRI_VV7356_1.0`, Complete Genome.
- `GCF_009665475.1`: *Vibrio vulnificus* strain 2142-77, NCBI Assembly `ASM966547v1`, Complete Genome. NCBI reports taxonomy-check status as `Inconclusive`.
- `GCF_056820805.1`: *Vibrio vulnificus* strain 24-VB00699, NCBI Assembly `ASM5682080v1`, Complete Genome.

Validate project-wide reference availability from the project root:

```bash
bash scripts/validate_reference_manifest.sh
```
