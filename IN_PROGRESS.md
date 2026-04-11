# In Progress

## 2026-03-27 FastQC extraction and interpretation

- FastQC review is complete and the project is ready to enter the read-trimming stage.
- Main open technical question for trimming is whether standard Trimmomatic settings will adequately reduce reverse-read PolyG artifacts.
- Next verification point should be post-trim FastQC on all paired samples.

## 2026-03-28 Trimmomatic preparation

- Created a non-destructive trimming workspace at `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic` with `copied_reads`, `logs`, and `metrics`.
- Copied and byte-validated all 6 paired FASTQ datasets from `fq_raw/` into `trimmomatic/copied_reads/`; raw reads remain unchanged.
- Prepared the SLURM array script and manifest for a `0-5` array submission; next active step is job submission plus a 1-2 minute early-failure check in the SLURM logs.
- Remaining technical caveat: Trimmomatic quality trimming can reduce low-quality PolyG-heavy tails, but post-trim FastQC is still required to confirm whether the reverse-read artifact is sufficiently improved.
## 2026-04-09 Post-trim FastQC extraction and interpretation

- Post-trim FastQC interpretation is complete and the quality-control checkpoint for trimmed paired reads has been verified.
- Remaining technical caveat is the persistent forward-read per-tile FastQC failure, which appears to be a lane artifact rather than a trimming deficiency.
- Next active pipeline step is assembly planning and submission on the trimmed paired reads.

