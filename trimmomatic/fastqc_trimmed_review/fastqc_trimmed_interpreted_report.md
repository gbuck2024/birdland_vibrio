# Trimmed FastQC Interpreted Report

Generated: 2026-10-03 18:07:15 CDT

## Scope

Analyzed 24 extracted FastQC reports from `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/fastqc_trimmed/reports` using `summary.txt` and `fastqc_data.txt`.
Compared each trimmed report to the matching raw-read report from `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/fastqc_extracted`.

## Module Status Overview

| Module | PASS | WARN | FAIL | Improved vs raw | Unchanged | Worsened |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Adapter Content | 24 | 0 | 0 | 0 | 24 | 0 |
| Basic Statistics | 24 | 0 | 0 | 0 | 24 | 0 |
| Overrepresented sequences | 22 | 2 | 0 | 6 | 18 | 0 |
| Per base N content | 24 | 0 | 0 | 6 | 18 | 0 |
| Per base sequence content | 4 | 8 | 12 | 0 | 23 | 1 |
| Per base sequence quality | 24 | 0 | 0 | 6 | 18 | 0 |
| Per sequence GC content | 5 | 19 | 0 | 5 | 18 | 1 |
| Per sequence quality scores | 24 | 0 | 0 | 0 | 24 | 0 |
| Per tile sequence quality | 0 | 16 | 8 | 4 | 20 | 0 |
| Sequence Duplication Levels | 12 | 0 | 12 | 0 | 24 | 0 |
| Sequence Length Distribution | 0 | 24 | 0 | 0 | 12 | 12 |

## Pair Summary

| Sample | Read | Total sequences | Total bases | %GC | Min mean Q | Worst tile delta | Deduplicated % | Overrepresented status | Top overrepresented sequence/source |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Buck_BI0607_1_WKDL250009588-1A_233TFCLT4 | 1 | 155,294,271 | 23.2 Gbp | 49 | 37.60 | -37.19 | 7.20 | PASS | none |
| Buck_BI0607_1_WKDL250009588-1A_233TFCLT4 | 2 | 155,294,271 | 23.1 Gbp | 49 | 35.97 | -7.40 | 7.28 | WARN | 0.295% No Hit |
| Buck_BI0607_2_WKDL250009588-1A_233TFCLT4 | 1 | 122,931,599 | 18.4 Gbp | 47 | 37.50 | -37.10 | 6.95 | PASS | none |
| Buck_BI0607_2_WKDL250009588-1A_233TFCLT4 | 2 | 122,931,599 | 18.3 Gbp | 47 | 35.67 | -7.39 | 6.84 | PASS | none |
| Buck_BS0607_9_WKDL250009588-1A_233TFCLT4 | 1 | 239,251,931 | 35.8 Gbp | 47 | 38.43 | -37.30 | 7.77 | PASS | none |
| Buck_BS0607_9_WKDL250009588-1A_233TFCLT4 | 2 | 239,251,931 | 35.7 Gbp | 47 | 36.40 | -7.43 | 7.60 | WARN | 0.101% No Hit |
| Buck_CB0707_82_WKDL250009588-1A_233TFCLT4 | 1 | 180,420,959 | 27 Gbp | 47 | 38.32 | -37.27 | 9.21 | PASS | none |
| Buck_CB0707_82_WKDL250009588-1A_233TFCLT4 | 2 | 180,420,959 | 26.9 Gbp | 47 | 35.54 | -7.40 | 10.03 | PASS | none |
| Buck_NB0507_14_WKDL250009588-1A_233TFCLT4 | 1 | 147,813,319 | 22.1 Gbp | 44 | 38.26 | -37.20 | 6.03 | PASS | none |
| Buck_NB0507_14_WKDL250009588-1A_233TFCLT4 | 2 | 147,813,319 | 22 Gbp | 44 | 35.99 | -7.42 | 6.28 | PASS | none |
| Buck_NB0507_8_WKDL250009588-1A_233TFCLT4 | 1 | 165,150,467 | 24.7 Gbp | 46 | 38.39 | -37.13 | 9.79 | PASS | none |
| Buck_NB0507_8_WKDL250009588-1A_233TFCLT4 | 2 | 165,150,467 | 24.6 Gbp | 46 | 35.95 | -7.40 | 10.03 | PASS | none |
| SRR37851509 | 1 | 798,851 | 187.2 Mbp | 45 | 33.19 | -8.86 | 78.05 | PASS | none |
| SRR37851509 | 2 | 798,851 | 171.9 Mbp | 45 | 31.46 | -10.27 | 80.79 | PASS | none |
| SRR37851510 | 1 | 590,950 | 129.2 Mbp | 45 | 32.20 | -9.06 | 83.05 | PASS | none |
| SRR37851510 | 2 | 590,950 | 132.2 Mbp | 45 | 31.91 | -9.42 | 84.90 | PASS | none |
| SRR37852094 | 1 | 909,878 | 208.9 Mbp | 44 | 32.81 | -9.04 | 75.96 | PASS | none |
| SRR37852094 | 2 | 909,878 | 195.5 Mbp | 44 | 31.59 | -9.24 | 78.59 | PASS | none |
| SRR37852095 | 1 | 914,516 | 212.6 Mbp | 44 | 32.91 | -8.93 | 76.24 | PASS | none |
| SRR37852095 | 2 | 914,516 | 198.6 Mbp | 44 | 31.83 | -9.32 | 78.77 | PASS | none |
| SRR37852096 | 1 | 730,326 | 170.6 Mbp | 44 | 33.17 | -8.87 | 80.03 | PASS | none |
| SRR37852096 | 2 | 730,326 | 158.3 Mbp | 44 | 31.29 | -10.18 | 82.76 | PASS | none |
| SRR37852097 | 1 | 669,214 | 156.5 Mbp | 46 | 33.32 | -8.87 | 80.35 | PASS | none |
| SRR37852097 | 2 | 669,214 | 139 Mbp | 46 | 31.26 | -9.71 | 82.92 | PASS | none |

## Interpreted Findings

- Per-base sequence quality passes in 24 of 24 trimmed reports and per-sequence quality scores pass in 24 of 24. Minimum mean base quality is 31.26 to 38.43, so trimming did not damage overall read quality.
- Overrepresented sequences improved in 6 of 24 files. After trimming, 22 reports pass and 2 reports remain WARN; no trimmed report fails this module.
- Per-sequence GC content improved in 5 of 24 files. After trimming, 5 reports pass, 19 warn, and 0 fail; most residual GC-content calls are warnings rather than failures.
- Per-base sequence content improved in 0 of 24 files. The trimmed set contains 4 PASS, 8 WARN, and 12 FAIL calls, so start-cycle composition bias remains the main residual content artifact.
- Per tile sequence quality improved in 4 of 24 files and remains at 16 WARN and 8 FAIL calls after trimming. This is consistent with a tile/lane artifact rather than adapter carryover.
- Sequence duplication levels pass in 12 of 24 reports and fail in 12. Deduplicated fractions are 6.03% to 84.90%, so duplication varies strongly by sample set and library depth.
- Adapter Content passes in 24 of 24 trimmed reports. Reverse reads show PolyG as the highest adapter-content track in 6 of 12 files, with trimmed PolyG peaks of 0.08% to 0.31% versus 0.69% to 1.68% in the raw review.
- Sequence length distribution now warns in 24 of 24 reports, which is expected after variable-length trimming and is not a reason to stop the pipeline.

## Sample-Specific Notes

- Buck_BI0607_1_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a GC-content warning; read 1 overrepresented sequences improved to PASS; read 2 still has warn per-tile quality; read 2 retains a GC-content warning; read 2 overrepresented sequences improved to PASS.
- Buck_BI0607_2_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a base-content warning; read 2 overrepresented sequences improved to PASS.
- Buck_BS0607_9_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a GC-content warning; read 2 still has warn per-tile quality; read 2 retains a GC-content warning.
- Buck_CB0707_82_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a GC-content warning; read 2 retains a base-content warning; read 2 overrepresented sequences improved to PASS.
- Buck_NB0507_14_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a GC-content warning; read 2 retains a base-content warning; read 2 overrepresented sequences improved to PASS.
- Buck_NB0507_8_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a GC-content warning; read 2 retains a base-content warning; read 2 overrepresented sequences improved to PASS.
- SRR37851509: read 1 still has warn per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has fail per-tile quality; read 2 retains a GC-content warning; read 2 retains a base-content warning.
- SRR37851510: read 1 still has warn per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a GC-content warning; read 2 retains a base-content warning.
- SRR37852094: read 1 still has warn per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a base-content warning.
- SRR37852095: read 1 still has warn per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a GC-content warning; read 2 retains a base-content warning.
- SRR37852096: read 1 still has warn per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has fail per-tile quality; read 2 retains a base-content warning.
- SRR37852097: read 1 still has warn per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a base-content warning.

## Recommended Next Steps

1. Proceed to genome assembly on the trimmed paired reads, because the main pre-trim reverse-read PolyG and GC anomalies improved to acceptable FastQC outcomes after trimming.
2. Use only the paired trimmed FASTQ files in `trimmomatic/trimmed_reads/` as SPAdes inputs unless you intentionally want to incorporate unpaired reads in a separate assembly sensitivity check.
3. Record the persistent forward-read per-tile failures as a residual lane artifact, but do not block assembly on that module alone because base-quality metrics remain strong.
4. During assembly review, watch contig count, N50, total assembly size, and coverage for evidence that high duplication or residual tile effects are harming assembly performance.
5. If any assembly looks fragmented or coverage-skewed, use `Buck_BI0607_1` as the first candidate for a polyG-aware re-trimming comparison because it is the only sample that still carries both read-1 and read-2 base-content warnings.
