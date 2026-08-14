# Non-Mullis Vibrio cidicii References

This directory stores downloaded *Vibrio cidicii* reference genomes for comparison against project isolates.

## Directory Structure

- `metadata/`: accession and provenance tables for downloaded genomes.
- `downloads/`: downloaded NCBI genome FASTA files.
- `genomes/`: validated genome entries linked from `downloads/`.

## Current Entries

- `GCF_009665415.1`: *Vibrio cidicii* strain 2423-01, NCBI Assembly `ASM966541v1`, Complete Genome.
- `GCF_051352415.1`: *Vibrio cidicii* strain VC01, NCBI Assembly `ASM5135241v1`, Complete Genome.
- `GCF_043840705.1`: *Vibrio cidicii* strain 2020RZ130, NCBI Assembly `ASM4384070v1`, Contig.
- `GCA_052253365.2`: *Vibrio cidicii* strain PNUSAV005519, NCBI Assembly `PDT002897843.3`, Contig; GenBank-only accession in this intake.
- `GCF_001597935.1`: *Vibrio cidicii* strain 2538-88, NCBI Assembly `ASM159793v1`, Scaffold.

Validate project-wide reference availability from the project root:

```bash
bash scripts/validate_reference_manifest.sh
```
