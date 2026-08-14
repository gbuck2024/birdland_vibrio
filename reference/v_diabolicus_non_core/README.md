# Non-Core Vibrio diabolicus References

This directory stores downloaded *Vibrio diabolicus* genomes for comparison against project isolates.

## Directory Structure

- `metadata/`: accession and provenance tables for downloaded genomes.
- `downloads/`: downloaded NCBI genome FASTA files.
- `genomes/`: validated genome entries linked from `downloads/`.

## Current Entries

- `GCF_011801455.1`: *Vibrio diabolicus* strain FA3, NCBI Assembly `ASM1180145v1`, Complete Genome.
- `GCF_002953395.1`: *Vibrio diabolicus* strain FDAARGOS_105, NCBI Assembly `ASM295339v1`, Complete Genome.
- `GCF_054111865.1`: *Vibrio diabolicus* strain ZF102, NCBI Assembly `ASM5411186v1`, Complete Genome.
- `GCF_056531025.1`: *Vibrio diabolicus* strain MZT14, NCBI Assembly `ASM5653102v1`, Complete Genome.
- `GCF_040969975.1`: *Vibrio diabolicus* strain 3098, NCBI Assembly `ASM4096997v1`, Complete Genome.

Validate project-wide reference availability from the project root:

```bash
bash scripts/validate_reference_manifest.sh
```
