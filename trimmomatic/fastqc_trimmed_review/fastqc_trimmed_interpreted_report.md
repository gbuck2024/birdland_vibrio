# Trimmed FastQC Interpreted Report

Generated: 2026-04-09 16:29:19 CDT

## Scope

Analyzed 12 extracted FastQC reports from `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/trimmomatic/fastqc_trimmed/reports` using `summary.txt` and `fastqc_data.txt`.
Compared each trimmed report to the matching raw-read report from `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/fastqc_extracted`.

## Module Status Overview

| Module | PASS | WARN | FAIL | Improved vs raw | Unchanged | Worsened |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Adapter Content | 12 | 0 | 0 | 0 | 12 | 0 |
| Basic Statistics | 12 | 0 | 0 | 0 | 12 | 0 |
| Overrepresented sequences | 10 | 2 | 0 | 6 | 6 | 0 |
| Per base N content | 12 | 0 | 0 | 0 | 12 | 0 |
| Per base sequence content | 4 | 8 | 0 | 0 | 11 | 1 |
| Per base sequence quality | 12 | 0 | 0 | 0 | 12 | 0 |
| Per sequence GC content | 2 | 10 | 0 | 2 | 9 | 1 |
| Per sequence quality scores | 12 | 0 | 0 | 0 | 12 | 0 |
| Per tile sequence quality | 0 | 6 | 6 | 0 | 12 | 0 |
| Sequence Duplication Levels | 0 | 0 | 12 | 0 | 12 | 0 |
| Sequence Length Distribution | 0 | 12 | 0 | 0 | 0 | 12 |

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

## Interpreted Findings

- All 12 trimmed reports still pass per-base and per-sequence quality score modules. Minimum mean base quality is 35.54 to 38.43, so trimming did not damage overall read quality.
- Overrepresented sequences improved in 6 of 12 files. After trimming, 10 reports pass and 2 reports remain WARN; the raw reverse-read FAIL is gone, indicating the strongest polyG-driven tail artifact was reduced.
- Per-sequence GC content improved in 2 of 12 files. After trimming, 2 reports pass, 10 warn, and 0 fail; the prior FAIL for `Buck_NB0507_14` read 2 is resolved to WARN, but most GC-content warnings persist.
- Per-base sequence content improved in 0 of 12 files. The trimmed set contains 4 PASS and 8 WARN calls, so this start-cycle composition signal was largely unchanged overall.
- Per tile sequence quality improved in 0 of 12 files and remains unchanged overall at 6 WARN and 6 FAIL calls. This persistent split between reverse-read WARNs and forward-read FAILs points to a lane/tile artifact unaffected by trimming.
- Sequence duplication levels still fail in all 12 trimmed reports. Deduplicated fractions are 6.03% to 10.03%, so duplication remains a library/depth characteristic rather than a trimming problem.
- Adapter Content still passes in all 12 trimmed reports. Reverse reads continue to show PolyG as the highest adapter-content track in 6 of 6 files, with trimmed PolyG peaks of 0.08% to 0.31% versus 0.69% to 1.68% in the raw review.
- Sequence length distribution now warns in 12 of 12 reports, which is expected after variable-length trimming and is not a reason to stop the pipeline.

## Sample-Specific Notes

- Buck_BI0607_1_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a GC-content warning; read 1 overrepresented sequences improved to PASS; read 2 still has warn per-tile quality; read 2 retains a GC-content warning; read 2 overrepresented sequences improved to PASS.
- Buck_BI0607_2_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a base-content warning; read 2 overrepresented sequences improved to PASS.
- Buck_BS0607_9_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a GC-content warning; read 2 still has warn per-tile quality; read 2 retains a GC-content warning.
- Buck_CB0707_82_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a GC-content warning; read 2 retains a base-content warning; read 2 overrepresented sequences improved to PASS.
- Buck_NB0507_14_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a GC-content warning; read 2 retains a base-content warning; read 2 overrepresented sequences improved to PASS.
- Buck_NB0507_8_WKDL250009588-1A_233TFCLT4: read 1 still has fail per-tile quality; read 1 retains a GC-content warning; read 1 retains a base-content warning; read 2 still has warn per-tile quality; read 2 retains a GC-content warning; read 2 retains a base-content warning; read 2 overrepresented sequences improved to PASS.

## Recommended Next Steps

1. Proceed to genome assembly on the trimmed paired reads, because the main pre-trim reverse-read PolyG and GC anomalies improved to acceptable FastQC outcomes after trimming.
2. Use only the paired trimmed FASTQ files in `trimmomatic/trimmed_reads/` as SPAdes inputs unless you intentionally want to incorporate unpaired reads in a separate assembly sensitivity check.
3. Record the persistent forward-read per-tile failures as a residual lane artifact, but do not block assembly on that module alone because base-quality metrics remain strong.
4. During assembly review, watch contig count, N50, total assembly size, and coverage for evidence that high duplication or residual tile effects are harming assembly performance.
5. If any assembly looks fragmented or coverage-skewed, use `Buck_BI0607_1` as the first candidate for a polyG-aware re-trimming comparison because it is the only sample that still carries both read-1 and read-2 base-content warnings.
