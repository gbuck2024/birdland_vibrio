# Exact-depth assembly validation (CIGAR-corrected coverage)

## Methods

Twenty-four assemblies from six isolate labels were compared: original full-read plus nominal 25×, 50×, and 100×. Each isolate uses the same external reference across all four conditions, selected from its 25× reciprocal ANI/AF panel. ANI and directional AF use the completed fastANI panels, plus the separate Bacillus comparator run for BI0607_2. Reference coverage uses minimap2 -c base-level CIGAR primary assembly alignments with MAPQ ≥20, aligned block ≥1 kb, and identity ≥90%. Unique coverage means reference bases covered by exactly one retained primary alignment. BUSCO bacteria_odb12.2 complete markers estimate broad conserved-gene completeness; duplicated markers are an independent contamination signal, not a measured contaminant fraction. This v2 report supersedes the initial coverage table, whose PAF match counts were estimated without CIGAR and were unsuitable for the identity cutoff.

## Observations

### BI0607_1

| Condition | Assembly Mb | Contigs | N50 kb | Selected reference | ANI % (forward/reverse) | AF (forward/reverse) | Ref covered % | Exactly-one coverage % | BUSCO complete % | BUSCO duplicated % |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| original | 49.56 | 84400 | 0.7 | vcidicii_2538_88 | 97.6034/98.0795 | 0.2984/0.7683 | 84.08 | 80.18 | 100.00 | 88.79 |
| 25x | 5.54 | 3903 | 98.7 | vcidicii_2538_88 | 98.2910/98.3151 | 0.9228/0.8913 | 84.05 | 84.02 | 98.28 | 0.86 |
| 50x | 7.00 | 8167 | 72.5 | vcidicii_2538_88 | 98.2950/98.3054 | 0.9192/0.8940 | 84.05 | 84.02 | 98.28 | 2.59 |
| 100x | 9.75 | 15268 | 0.8 | vcidicii_2538_88 | 98.2349/98.2866 | 0.9202/0.8940 | 84.07 | 84.04 | 98.28 | 4.31 |

### BI0607_2

| Condition | Assembly Mb | Contigs | N50 kb | Selected reference | ANI % (forward/reverse) | AF (forward/reverse) | Ref covered % | Exactly-one coverage % | BUSCO complete % | BUSCO duplicated % |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| original | 34.17 | 49312 | 1.2 | b_paralicheniformis_atcc_9945a | 98.4602/98.4216 | 0.3423/0.8306 | 87.62 | 87.40 | 100.00 | 89.66 |
| 25x | 5.98 | 5563 | 164.0 | b_paralicheniformis_atcc_9945a | 98.5657/98.5051 | 0.9596/0.9129 | 87.01 | 87.00 | 99.14 | 0.86 |
| 50x | 8.27 | 11168 | 56.0 | b_paralicheniformis_atcc_9945a | 98.5422/98.5180 | 0.9589/0.9129 | 87.04 | 87.03 | 99.14 | 6.03 |
| 100x | 11.89 | 17581 | 0.9 | b_paralicheniformis_atcc_9945a | 98.5212/98.5098 | 0.9584/0.9136 | 87.10 | 87.10 | 96.55 | 18.97 |

### BS0607_9

| Condition | Assembly Mb | Contigs | N50 kb | Selected reference | ANI % (forward/reverse) | AF (forward/reverse) | Ref covered % | Exactly-one coverage % | BUSCO complete % | BUSCO duplicated % |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| original | 65.09 | 97079 | 1.3 | mullis2019_18032 | 99.3291/99.0502 | 0.1196/0.5206 | 92.86 | 90.85 | 100.00 | 97.41 |
| 25x | 6.71 | 6146 | 92.4 | mullis2019_18032 | 99.9901/99.9645 | 0.9831/0.9742 | 98.80 | 98.79 | 98.28 | 0.86 |
| 50x | 9.47 | 12322 | 2.6 | mullis2019_18032 | 99.9859/99.9796 | 0.9852/0.9768 | 99.00 | 98.97 | 99.14 | 1.72 |
| 100x | 14.06 | 18637 | 1.2 | mullis2019_18032 | 99.9806/99.9792 | 0.9533/0.9832 | 99.04 | 99.02 | 100.00 | 25.86 |

### CB0707_82

| Condition | Assembly Mb | Contigs | N50 kb | Selected reference | ANI % (forward/reverse) | AF (forward/reverse) | Ref covered % | Exactly-one coverage % | BUSCO complete % | BUSCO duplicated % |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| original | 32.11 | 47277 | 1.0 | mullis2019_18052 | 99.9678/99.9385 | 0.4875/0.9337 | 98.79 | 98.58 | 100.00 | 73.28 |
| 25x | 5.16 | 473 | 138.1 | mullis2019_18052 | 99.9842/99.9729 | 0.9957/0.9695 | 98.72 | 98.69 | 98.28 | 0.86 |
| 50x | 5.21 | 639 | 152.9 | mullis2019_18052 | 99.9782/99.9585 | 0.9964/0.9707 | 98.89 | 98.83 | 98.28 | 0.86 |
| 100x | 5.33 | 1006 | 179.6 | mullis2019_18052 | 99.9844/99.9596 | 0.9952/0.9773 | 99.01 | 98.99 | 98.28 | 0.86 |

### NB0507_14

| Condition | Assembly Mb | Contigs | N50 kb | Selected reference | ANI % (forward/reverse) | AF (forward/reverse) | Ref covered % | Exactly-one coverage % | BUSCO complete % | BUSCO duplicated % |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| original | 46.41 | 72565 | 0.9 | vdiabolicus_mzt14 | 94.5355/94.9248 | 0.2242/0.4224 | 80.35 | 76.68 | 96.55 | 81.03 |
| 25x | 8.01 | 6113 | 103.7 | vdiabolicus_mzt14 | 98.1137/98.1193 | 0.7859/0.9069 | 84.22 | 84.19 | 98.28 | 3.45 |
| 50x | 10.62 | 13362 | 8.8 | vdiabolicus_mzt14 | 98.1631/97.9693 | 0.7611/0.8155 | 88.13 | 87.66 | 93.97 | 5.17 |
| 100x | 14.50 | 20941 | 1.0 | vdiabolicus_mzt14 | 98.1278/98.0221 | 0.7644/0.8858 | 88.69 | 87.81 | 97.41 | 6.90 |

### NB0507_8

| Condition | Assembly Mb | Contigs | N50 kb | Selected reference | ANI % (forward/reverse) | AF (forward/reverse) | Ref covered % | Exactly-one coverage % | BUSCO complete % | BUSCO duplicated % |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| original | 18.67 | 30245 | 0.7 | mullis2019_18061 | 99.9675/99.9542 | 0.9324/0.9643 | 99.33 | 99.26 | 99.14 | 22.41 |
| 25x | 5.11 | 368 | 246.1 | mullis2019_18061 | 99.9951/99.9788 | 0.9964/0.9792 | 99.23 | 99.22 | 98.28 | 0.86 |
| 50x | 5.12 | 377 | 351.4 | mullis2019_18061 | 99.9816/99.9890 | 0.9970/0.9792 | 99.32 | 98.81 | 98.28 | 0.86 |
| 100x | 5.16 | 459 | 448.3 | mullis2019_18061 | 99.9870/99.9803 | 0.9970/0.9839 | 99.40 | 98.89 | 98.28 | 0.86 |

## Possible explanation

Differences across depths may reflect added low-abundance sequence, assembly fragmentation, repeats, or mixed material. These observations alone do not locate contamination or prove an isolate species.

## Limitations

The 76-reference panel contains Vibrio genomes; a separate Bacillus paralicheniformis comparator was added for BI0607_2. The fixed reference may not be the best-hit reference at every depth, and low reciprocal AF remains provisional. Reference coverage is conditional on the chosen reference and mapping filters; it is not whole-assembly completeness. BUSCO duplication can arise from genuine paralogs or assembly errors and can miss contaminants. The original assembly and subsamples come from the same sequencing run, so their rows are correlated, not independent samples.

## Next validation

For ambiguous isolates, add biologically plausible competing references and inspect read-supported breadth and marker placement. Confirm candidate species with reciprocal alignment fraction and independent isolate provenance.

## Source data

`fixed_reference_coverage_manifest.tsv`, per-assembly PAF and coverage TSVs under `fixed_reference_coverage_cigar/`, BUSCO summaries under `busco/`, and the four ANI long tables provide the underlying measurements. The earlier exploratory coverage outputs remain under `coverage/` and `fixed_reference_coverage/`. `metrics/exact_depth_comparison_v2.tsv` is the machine-readable summary.
