# Kraken2 build verification report

Date reviewed: 2026-04-17

## Question

Did the completed Kraken2 database-build job download the bacterial genomes cleanly and finish with a usable database?

## Files reviewed

- `kraken2_db/logs/slurm/kraken2_bact_db_1319090.out`
- `kraken2_db/logs/slurm/kraken2_bact_db_1319090.err`
- `kraken2_db/logs/slurm/kraken2_bact_db_1319091.out`
- `kraken2_db/logs/slurm/kraken2_bact_db_1319091.err`
- `kraken2_db/logs/slurm/kraken2_bact_db_1319269.out`
- `kraken2_db/logs/slurm/kraken2_bact_db_1319269.err`
- `kraken2_db/metadata/build_parameters_job_1319269.tsv`
- `kraken2_db/metadata/disk_usage_after_job_1319269.tsv`

## Result

The final retry-hardened job `1319269` completed successfully and produced the expected Kraken2 database files:

- `kraken2_db/db/hash.k2d`
- `kraken2_db/db/opts.k2d`
- `kraken2_db/db/taxo.k2d`

The final database is usable for downstream `kraken2` classification. The saved files are non-empty and the post-build disk snapshot records a final database size of about `100G` after cleanup.

## Important caveat

The answer to "did everything download okay" is not a strict yes.

During the successful job `1319269`, the stderr log still recorded:

- one transient FTP download failure for `GCF_000954115.1_ASM95411v1_genomic.fna.gz` on try `1 of 5`
- two downloaded genome files that later failed gzip validation:
  - `GCF_021474345.1_ASM2147434v1_genomic.fna.gz`
  - `GCF_041508025.1_ASM4150802v1_genomic.fna.gz`

Despite those messages, Kraken2 continued and reported:

- `All files processed, cleaning up extra sequence files... done, library complete.`
- `Completed processing of 159048 sequences, 284410994564 bp`
- `Database disk usage: 369G`
- `After cleaning, database uses 100G`

## Interpretation

- Job `1319090` failed and should be ignored for completeness checks because taxonomy download failed through the old rsync path.
- Job `1319091` also failed and should be ignored for completeness checks because the bacteria-library FTP download stopped on a repeated connection-closed error.
- Job `1319269` is the first completed build and is the run that produced the current database.
- The current database should be treated as successfully built but not perfectly clean at the individual-download level, because a small number of source genome fetches or decompressions were problematic during the successful run.

## Practical conclusion

- Safe conclusion: the Kraken2 bacteria database build completed successfully and is ready to use.
- Conservative conclusion: not every individual RefSeq genome download was clean, so the database is usable but may be missing a very small number of bacterial library entries from the NCBI snapshot used during job `1319269`.

## Recommended next step

Use the completed database for taxonomic screening of the ambiguous isolates first. Rebuild only if later classification results suggest the missing or corrupt source genomes are likely to matter biologically.
