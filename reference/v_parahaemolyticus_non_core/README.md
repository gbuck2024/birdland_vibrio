# Non-Core Vibrio parahaemolyticus References

This directory stores downloaded *Vibrio parahaemolyticus* genomes beyond the existing core RIMD 2210633 reference at `reference/v_parahaemolyticus_ref.fasta`.

## Directory Structure

- `metadata/`: accession and provenance tables for downloaded genomes.
- `downloads/`: downloaded NCBI genome FASTA files.
- `genomes/`: validated genome entries linked from `downloads/`.

## Current Entries

- `GCF_001558495.2`: *Vibrio parahaemolyticus* strain ATCC 17802, NCBI Assembly `ASM155849v2`, Complete Genome.
- `GCF_057321345.1`: *Vibrio parahaemolyticus* strain vp18, NCBI Assembly `vp18`, Complete Genome.
- `GCF_013393865.1`: *Vibrio parahaemolyticus* strain LVP2, NCBI Assembly `ASM1339386v1`, Complete Genome.
- `GCF_009665495.1`: *Vibrio parahaemolyticus* strain 2012AW-0154, NCBI Assembly `ASM966549v1`, Complete Genome.

Validate project-wide reference availability from the project root:

```bash
bash scripts/validate_reference_manifest.sh
```
