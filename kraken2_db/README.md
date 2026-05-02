# Kraken2 bacterial database stage

This stage prepares a bacteria-focused Kraken2 database in a dedicated project subdirectory so the ambiguous multi-reference alignment results can be followed with a broader taxonomic screen.

## Files prepared now

- `scripts/kraken2_build_bacterial_db.slurm`: reusable SLURM job script for database download and build.
- `kraken2_db/README.md`: stage note for expected inputs, outputs, and storage assumptions.

## Expected runtime inputs

- A Singularity image containing `kraken2-build`.
- Submit from the project root so relative paths resolve cleanly.
- Sufficient free space on both the project filesystem and node-local temporary storage.

Default container path search order:

- `containers/kraken2.sif`
- `kraken2.sif`

Override at submission time if needed:

```bash
sbatch --export=ALL,KRAKEN2_SIF=/path/to/kraken2.sif scripts/kraken2_build_bacterial_db.slurm
```

The script now defaults to `KRAKEN2_DOWNLOAD_PROTOCOL=ftp` to avoid the rsync endpoint failure seen in job `1319090`. Set `KRAKEN2_DOWNLOAD_PROTOCOL=rsync` only if your local Kraken2/container combination is known to work with rsync.
The bacteria-library download step now retries transient failures by default with `KRAKEN2_DOWNLOAD_MAX_ATTEMPTS=5` and `KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC=300`.

## Expected runtime outputs

- `kraken2_db/db/`: final Kraken2 database files such as `hash.k2d`, `opts.k2d`, and `taxo.k2d`.
- `kraken2_db/logs/slurm/`: SLURM stdout and stderr from the database build job.
- `kraken2_db/metadata/`: small text records capturing build parameters, assumptions, and before/after disk-usage snapshots.

## Storage and HPC guardrails

- The script builds only the RefSeq bacteria library plus taxonomy, not the full standard Kraken2 database.
- The script refuses to start unless free space thresholds are met.
- Defaults are `MIN_PROJECT_FREE_GB=250` and `MIN_TMP_FREE_GB=150`.
- The script uses node-local temporary space for transient work and can run `kraken2-build --clean` after success.
- `KRAKEN2_CLEAN_AFTER_BUILD=1` is the default to reduce retained intermediates.
- `KRAKEN2_DOWNLOAD_PROTOCOL=ftp` is the default because the initial attempt failed during rsync taxonomy download.
- `KRAKEN2_DOWNLOAD_MAX_ATTEMPTS=5` and `KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC=300` are the defaults because job `1319091` failed on a transient FTP disconnect during the bacteria-library download.

## Assumptions

- The taxonomic question is bacterial-focused because multi-reference alignment gave species-ambiguous results.
- A bacteria-only Kraken2 database is more appropriate here than a larger multi-kingdom database.
- Actual disk usage will vary with the RefSeq snapshot date and the contents available from NCBI at build time.
- Temporary download/build footprint can be much larger than the final `*.k2d` files, so the free-space checks are intentionally conservative.

## Submission example

Do not run this on the login node. Submit only when ready:

```bash
sbatch scripts/kraken2_build_bacterial_db.slurm
```

If local policy or queue limits require different retry behavior, override the defaults at submission time:

```bash
sbatch --export=ALL,KRAKEN2_DOWNLOAD_MAX_ATTEMPTS=8,KRAKEN2_DOWNLOAD_RETRY_SLEEP_SEC=600 scripts/kraken2_build_bacterial_db.slurm
```
