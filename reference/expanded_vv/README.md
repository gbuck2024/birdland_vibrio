# Expanded Vibrio vulnificus Reference Set

This directory contains the reproducible scaffold for the Mullis et al. 2019 environmental Vibrio vulnificus genome set. It is kept separate from the main `reference/` directory so these genomes are not mixed into the current 3-isolate SNP pipeline.

Do not use this expanded set in the current 3-isolate SNP pipeline until a separate expanded-reference analysis plan has been reviewed.

## Citation

Mullis MM, Huang I-S, Planas-Costas GM, Pray R, Buck GW, Nassiri A, Fuentes C, Turner L, Ramirez GD, Mott JB, Turner JW. 2019. Draft genome sequences of 42 environmental Vibrio vulnificus strains isolated from the northern Gulf of Mexico. Microbiol Resour Announc. 8:e00200-19. doi:10.1128/MRA.00200-19.

## Accession Handling

Mullis et al. 2019 Table 1 reports WGS GenBank accessions. Those WGS/master accessions are not directly downloadable as genome FASTA files by simple `efetch`. Downloadable genome FASTA files are retrieved through the corresponding NCBI Assembly FTP URLs.

The metadata table `metadata/mullis2019_genome_downloads.tsv` maps each Table 1 isolate and WGS accession to its resolved NCBI Assembly accession, FTP URL, expected local filename, provenance, and notes. Assembly metadata was resolved through NCBI Assembly E-utilities for BioProject `PRJNA475262` on 2026-05-05.

## Directory Structure

- `metadata/`: accession lists and the resolved download metadata table.
- `downloads/`: downloaded `*_genomic.fna.gz` files and the download log.
- `genomes/`: valid downloaded genomes copied or symlinked from `downloads/`.

## Commands

Run downloads only when ready to retrieve the expanded genome set:

```bash
bash scripts/download_mullis2019_genomes.sh
```

Validate the scaffold and downloaded files:

```bash
bash scripts/validate_mullis2019_genomes.sh
```

The download script skips unresolved rows, resumes partial downloads with `curl -L -C -` or `wget -c`, validates each gzip with `gzip -t`, and does not redownload files that are already present and gzip-valid.
