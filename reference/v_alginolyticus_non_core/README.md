# Non-Core Vibrio alginolyticus References

This directory stores downloaded *Vibrio alginolyticus* genomes beyond the existing core ATCC 17749 reference at `reference/v_alginolyticus_ref.fasta`.

## Directory Structure

- `metadata/`: accession and provenance tables for downloaded genomes.
- `downloads/`: downloaded NCBI genome FASTA files.
- `genomes/`: validated genome entries linked from `downloads/`.

## Current Entries

- `GCF_023650915.1`: *Vibrio alginolyticus* strain E110, NCBI Assembly `ASM2365091v1`, Complete Genome.
- `GCF_029023705.1`: *Vibrio alginolyticus* strain V208, NCBI Assembly `ASM2902370v1`, Complete Genome.
- `GCF_047497145.1`: *Vibrio alginolyticus* strain ZJ-0, NCBI Assembly `ASM4749714v1`, Complete Genome.
- `GCF_023169625.1`: *Vibrio alginolyticus* strain HLBS-07, NCBI Assembly `ASM2316962v1`, Complete Genome.

Validate project-wide reference availability from the project root:

```bash
bash scripts/validate_reference_manifest.sh
```
