# Non-Mullis Vibrio navarrensis References

This directory stores downloaded *Vibrio navarrensis* reference genomes for comparison against project isolates.

## Directory Structure

- `metadata/`: accession and provenance tables for downloaded genomes.
- `downloads/`: downloaded NCBI genome FASTA files.
- `genomes/`: validated genome entries linked from `downloads/`.

## Current Entries

- `GCF_000764325.1`: *Vibrio navarrensis* strain ATCC 51183, NCBI Assembly `2540-90v1.0`, Contig.
- `GCF_015767675.1`: *Vibrio navarrensis* strain 20-VB00237, NCBI Assembly `ASM1576767v1`, Complete Genome. NCBI reports taxonomy-check status as `Inconclusive`.
- `GCF_009763725.1`: *Vibrio navarrensis* strain 2462-79, NCBI Assembly `ASM976372v1`, Complete Genome.
- `GCF_009665215.1`: *Vibrio navarrensis* strain 08-2462, NCBI Assembly `ASM966521v1`, Complete Genome.
- `GCA_048162665.1`: *Vibrio navarrensis* strain PNUSAV006652, NCBI Assembly `PDT002644466.1`, Contig; GenBank-only accession in this intake.

Validate project-wide reference availability from the project root:

```bash
bash scripts/validate_reference_manifest.sh
```
