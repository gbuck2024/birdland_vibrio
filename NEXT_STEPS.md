# Next Steps

## 2026-03-27 FastQC extraction and interpretation

- Build a reusable SLURM array script for paired-end trimming with adapter clipping and quality-tail trimming.
- Preserve read pairing and write trimmed outputs plus stdout/stderr logs into new step-specific directories.
- After trimming, rerun FastQC and compare reverse-read PolyG, GC-content, and overrepresented-sequence behavior before proceeding to SPAdes.

## 2026-03-28 Trimmomatic ready for submission

- Submit `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/trimmomatic_array.slurm` with `sbatch --array=0-5` so each copied sample pair is trimmed once.
- Check job status and the first SLURM stdout/stderr files in `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/logs/slurm` within 1-2 minutes of submission.
- Verify that paired and unpaired outputs are written for each sample under the `trimmomatic` step directory before starting post-trim FastQC.
- Run FastQC on the trimmed paired reads and compare reverse-read PolyG, per-base quality, and adapter content against the pre-trim FastQC review.
## 2026-04-09 Post-trim FastQC extraction and interpretation

- Build a reusable SLURM assembly workflow for the six trimmed paired-end samples, preferably as an array job with per-sample stdout/stderr logs.
- Run SPAdes on `trimmomatic/trimmed_reads/*_paired.fq.gz` and capture assembly metrics into a new step-specific directory.
- Review assembly size, contig count, N50, and coverage-related metrics before proceeding to annotation and gene-target analysis.

## 2026-04-12 Alignment review completed

- Prioritize de novo assembly on all 6 trimmed paired samples because reference-based alignment rates vary sharply across isolates, from `1.05%` to `88.12%`.
- Treat `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` and `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` as reference-mismatch outliers because they show both low mapped-read percentages and very poor proper-pairing rates against the current `Vibrio vulnificus` reference.
- Build additional reference-alignment tests against other candidate Vibrio species, especially `Vibrio alginolyticus` and `Vibrio parahaemolyticus`, to determine whether the poorly paired samples map more cleanly to a different species-level reference.
- Compare mapped percentage, properly paired percentage, and contig-level `idxstats` distributions across the alternative references before deciding whether those samples belong in the same downstream reference-based analysis set.
- If reference-based analysis continues for the strongest current matches, start with `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, and `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, which all show high mapping and strong proper-pairing against the present reference.
- Submit or prepare the SPAdes stage next, keeping outputs in a new assembly-specific directory and documenting all parameters used.

## 2026-04-13 Multi-reference alignment review completed

- Use `multi_reference_alignment/metrics/multi_reference_alignment_summary.tsv` and `multi_reference_alignment/metrics/multi_reference_alignment_mapped_pct_matrix.tsv` as the decision point for the next biological split in the workflow.
- Prioritize de novo assembly for all 6 trimmed paired samples so downstream annotation, gene mining, and phylogenetics do not depend on a single reference species assumption.
- Treat `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7`, `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7`, `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7`, and likely `Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7` as the strongest current `Vibrio vulnificus` candidates for any optional follow-up reference-based analysis.
- Treat `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` as a likely non-`Vibrio vulnificus` isolate or mixed-signal sample because it maps best to `Vibrio alginolyticus` rather than the current `Vibrio vulnificus` reference.
- Flag `Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7` for extra scrutiny during assembly and annotation because its mapped-read percentage stays near `1%` across all tested references, consistent with severe reference mismatch, contamination, or low-complexity data.
- Prepare the SPAdes stage next in a new assembly-specific directory with a reusable SLURM script, saved parameters, and an explicit manifest so the step is ready for cluster submission without running heavy work on the login node.
