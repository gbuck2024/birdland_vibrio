# FastQC Interpreted Report

Generated: 2026-10-03 17:56:03 CDT

## Scope

Analyzed 24 extracted FastQC reports from `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/fastqc` using `summary.txt` and `fastqc_data.txt`.
Reads are interpreted as paired-end data where read `1` is forward and read `2` is reverse.

## Module Status Overview

| Module | PASS | WARN | FAIL |
| --- | ---: | ---: | ---: |
| Adapter Content | 24 | 0 | 0 |
| Basic Statistics | 24 | 0 | 0 |
| Overrepresented sequences | 17 | 6 | 1 |
| Per base N content | 18 | 6 | 0 |
| Per base sequence content | 5 | 7 | 12 |
| Per base sequence quality | 18 | 6 | 0 |
| Per sequence GC content | 2 | 21 | 1 |
| Per sequence quality scores | 24 | 0 | 0 |
| Per tile sequence quality | 0 | 12 | 12 |
| Sequence Duplication Levels | 12 | 0 | 12 |
| Sequence Length Distribution | 12 | 12 | 0 |

## Pair Summary

| Sample | Read | Total sequences | Total bases | %GC | Min mean Q | Worst tile delta | Deduplicated % | Overrepresented status | Top overrepresented sequence/source |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Buck_BI0607_1_WKDL250009588-1A_233TFCLT4 | 1 | 163,455,271 | 24.5 Gbp | 49 | 37.24 | -37.06 | 8.14 | WARN | 0.239% TruSeq Adapter, Index 10 (97% over 37bp) |
| Buck_BI0607_1_WKDL250009588-1A_233TFCLT4 | 2 | 163,455,271 | 24.5 Gbp | 49 | 35.52 | -7.38 | 10.09 | FAIL | 1.137% No Hit |
| Buck_BI0607_2_WKDL250009588-1A_233TFCLT4 | 1 | 128,188,933 | 19.2 Gbp | 47 | 37.15 | -36.96 | 8.07 | PASS | none |
| Buck_BI0607_2_WKDL250009588-1A_233TFCLT4 | 2 | 128,188,933 | 19.2 Gbp | 47 | 35.17 | -7.35 | 9.64 | WARN | 0.456% No Hit |
| Buck_BS0607_9_WKDL250009588-1A_233TFCLT4 | 1 | 249,092,276 | 37.3 Gbp | 48 | 38.12 | -37.18 | 8.70 | PASS | none |
| Buck_BS0607_9_WKDL250009588-1A_233TFCLT4 | 2 | 249,092,276 | 37.3 Gbp | 48 | 35.97 | -7.39 | 10.18 | WARN | 0.427% No Hit |
| Buck_CB0707_82_WKDL250009588-1A_233TFCLT4 | 1 | 189,171,422 | 28.3 Gbp | 47 | 37.96 | -37.14 | 10.10 | PASS | none |
| Buck_CB0707_82_WKDL250009588-1A_233TFCLT4 | 2 | 189,171,422 | 28.3 Gbp | 47 | 35.02 | -7.35 | 12.98 | WARN | 0.541% No Hit |
| Buck_NB0507_14_WKDL250009588-1A_233TFCLT4 | 1 | 153,570,325 | 23 Gbp | 44 | 37.94 | -37.07 | 7.10 | PASS | none |
| Buck_NB0507_14_WKDL250009588-1A_233TFCLT4 | 2 | 153,570,325 | 23 Gbp | 44 | 35.54 | -7.40 | 9.08 | WARN | 0.426% No Hit |
| Buck_NB0507_8_WKDL250009588-1A_233TFCLT4 | 1 | 172,380,967 | 25.8 Gbp | 46 | 38.06 | -37.00 | 10.62 | PASS | none |
| Buck_NB0507_8_WKDL250009588-1A_233TFCLT4 | 2 | 172,380,967 | 25.8 Gbp | 47 | 35.47 | -7.34 | 12.57 | WARN | 0.410% No Hit |
| SRR37851509 | 1 | 882,260 | 214.5 Mbp | 45 | 31.36 | -8.99 | 76.90 | PASS | none |
| SRR37851509 | 2 | 882,260 | 214.5 Mbp | 45 | 24.59 | -27.00 | 81.10 | PASS | none |
| SRR37851510 | 1 | 631,681 | 153.5 Mbp | 45 | 28.76 | -9.45 | 82.53 | PASS | none |
| SRR37851510 | 2 | 631,681 | 153.5 Mbp | 45 | 25.68 | -27.86 | 84.70 | PASS | none |
| SRR37852094 | 1 | 999,748 | 242 Mbp | 44 | 30.61 | -9.32 | 74.86 | PASS | none |
| SRR37852094 | 2 | 999,748 | 242.1 Mbp | 44 | 24.68 | -27.18 | 78.85 | PASS | none |
| SRR37852095 | 1 | 998,281 | 242.2 Mbp | 44 | 31.16 | -9.15 | 75.16 | PASS | none |
| SRR37852095 | 2 | 998,281 | 242.3 Mbp | 44 | 24.99 | -27.43 | 79.08 | PASS | none |
| SRR37852096 | 1 | 802,779 | 194.6 Mbp | 44 | 31.42 | -8.97 | 78.96 | PASS | none |
| SRR37852096 | 2 | 802,779 | 194.6 Mbp | 44 | 24.91 | -26.83 | 83.01 | PASS | none |
| SRR37852097 | 1 | 765,405 | 185.7 Mbp | 46 | 31.11 | -8.84 | 78.63 | PASS | none |
| SRR37852097 | 2 | 765,405 | 185.8 Mbp | 46 | 23.40 | -26.67 | 83.24 | PASS | none |

## Interpreted Findings

- All 12 reports passed both per-base and per-sequence quality score modules. Minimum mean base quality stayed between 23.40 and 38.12, which is consistent with very high raw read quality before trimming.
- All 12 reports passed sequence length distribution and per-base N content. Every file is fixed at 150 bp with zero poor-quality flags in FastQC basic statistics.
- Per tile sequence quality is a systematic lane-level issue: all 12 forward reads failed this module, while all 12 reverse reads warned instead of passing. Worst tile deviations range from -37.18 to -7.34, so this is real but it does not coincide with poor overall per-base quality.
- Sequence duplication levels failed in all 12 reports. The deduplicated fraction ranges from 7.10% to 84.70%, with 0.21% to 69.62% of reads occurring at duplication level `>10`. That pattern is compatible with deep bacterial resequencing or library amplification and is not a stand-alone reason to discard the data.
- Adapter Content passed in all 12 reports, but every reverse read has PolyG as the highest adapter-content signal (0.69% to 1.68% in the FastQC PolyG track). Reverse-read overrepresented sequences are also dominated by long polyG strings, which points to 2-color chemistry tail artifacts rather than classic Illumina adapter carryover.
- Reverse reads carry most of the composition anomalies. Overrepresented sequences are WARN or FAIL in all six reverse reads, and five of six reverse reads WARN or FAIL for per-sequence GC content; `Buck_NB0507_14` read 2 is the strongest GC outlier with a FastQC FAIL.
- Base-composition imbalance is sample-dependent rather than universal. Four forward reads and four reverse reads WARN for per-base sequence content, consistent with start-cycle composition bias that trimming may reduce but may not fully remove.
- The only obvious classic adapter signature is `Buck_BI0607_1` read 1, where overrepresented sequences match TruSeq adapter/index-derived sequence fragments at low abundance. This supports adapter clipping during trimming even though the dedicated adapter module still passes.

## Sample-Specific Notes

- Buck_BI0607_1_WKDL250009588-1A_233TFCLT4: GC-content warning; reverse overrepresented sequence is 1.137% No Hit; forward overrepresented sequence is 0.239% TruSeq Adapter, Index 10 (97% over 37bp).
- Buck_BI0607_2_WKDL250009588-1A_233TFCLT4: base-content imbalance in at least one mate; GC-content warning; reverse overrepresented sequence is 0.456% No Hit.
- Buck_BS0607_9_WKDL250009588-1A_233TFCLT4: GC-content warning; reverse overrepresented sequence is 0.427% No Hit.
- Buck_CB0707_82_WKDL250009588-1A_233TFCLT4: base-content imbalance in at least one mate; GC-content warning; reverse overrepresented sequence is 0.541% No Hit.
- Buck_NB0507_14_WKDL250009588-1A_233TFCLT4: base-content imbalance in at least one mate; reverse-read GC content fail; reverse overrepresented sequence is 0.426% No Hit.
- Buck_NB0507_8_WKDL250009588-1A_233TFCLT4: base-content imbalance in at least one mate; GC-content warning; reverse overrepresented sequence is 0.410% No Hit.
- SRR37851509: base-content imbalance in at least one mate; GC-content warning.
- SRR37851510: base-content imbalance in at least one mate; GC-content warning.
- SRR37852094: base-content imbalance in at least one mate; GC-content warning.
- SRR37852095: base-content imbalance in at least one mate; GC-content warning.
- SRR37852096: base-content imbalance in at least one mate; GC-content warning.
- SRR37852097: base-content imbalance in at least one mate; GC-content warning.

## Recommended Next Steps

1. Proceed to paired-end trimming as the next pipeline step using a SLURM array job, keeping read 1 and read 2 synchronized and writing all outputs into a new trimming directory.
2. Include adapter clipping in trimming because `Buck_BI0607_1` read 1 contains low-level TruSeq-derived overrepresented sequences even though the adapter module passed.
3. Use quality trimming parameters that address reverse-read tail artifacts. Because the dominant issue is PolyG-rich reverse-read behavior, verify whether the planned Trimmomatic settings remove the affected tails adequately; if post-trim FastQC still shows PolyG-heavy reverse reads, consider a polyG-aware tool such as `fastp` as a follow-up decision point.
4. Rerun FastQC immediately after trimming on both mates for every sample and compare the same modules: per tile quality, per-base sequence content, GC content, overrepresented sequences, and adapter/PolyG signals.
5. Do not reject samples based on duplication alone before assembly. In isolate WGS, high duplication can still be compatible with useful depth; evaluate coverage and assembly behavior after trimming.
6. Keep the strongest watch on `Buck_BI0607_1` read 2 and `Buck_NB0507_14` read 2 because they show the most pronounced reverse-read artifact signatures in overrepresented sequence and GC-content modules.

## Best Pipeline Directions

- Best immediate option: implement the planned Trimmomatic read-trimming step in a reproducible SLURM array job, then perform post-trim FastQC before moving to assembly.
- Best quality-control checkpoint: treat reverse-read PolyG behavior as the main risk to resolve before assembly, not the duplication failures.
- Best decision gate after trimming: if reverse-read GC and overrepresented-sequence problems persist, pause before SPAdes and switch to a polyG-aware trimming strategy.
