# Non-Core Vibrio ostreicida References

This directory stores downloaded *Vibrio ostreicida* genomes beyond the existing PP-203 and r172 top-level references.

## Directory Structure

- `metadata/`: accession and provenance tables for downloaded genomes.
- `downloads/`: downloaded NCBI genome FASTA files.
- `genomes/`: validated genome entries linked from `downloads/`.

## Current Entries

- `GCF_030409575.1`: *Vibrio ostreicida* strain CECT 7398, NCBI Assembly `ASM3040957v1`, Contig.
- `GCF_001957165.1`: *Vibrio ostreicida* strain UCD-KL16, NCBI Assembly `ASM195716v1`, Contig.

Validate project-wide reference availability from the project root:

```bash
bash scripts/validate_reference_manifest.sh
```
