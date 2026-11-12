# ABRCMS poster depth comparison

## Scope and evidence

Eighteen assemblies from six Buck isolates were compared at nominal 25x, 50x, and 100x. The read-base table records actual sequenced bases; bases per assumed genome uses the project's 5.2 Mb assumption and is not mapped coverage. Self-mapping percentages come from samtools flagstat for each read set against its own assembly. Contig GC, length and coverage come from the per-condition BlobToolKit master tables. Kraken2 assignments are provisional. Taxonomic percentages below use assembled bp, not contig counts.

No ANI or aligned-fraction result exists for these exact 18 assemblies. The prior ANI columns in selected_depth.tsv describe different full-depth assemblies and must not be used to rank the depth conditions. No fixed genome-size cutoff was used for ambiguous isolates.

## BI0607_1

| Depth | Assembly Mb | Contigs | N50 kb | ≥10 kb bp % | Primary mapped % | Vibrio bp % | Bacillus bp % | Reyranella bp % | Unclassified bp % | Top Kraken label (bp %) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 25x | 5.54 | 3903 | 98.7 | 77.14 | 95.15 | 82.28 | 0.02 | 3.12 | 8.38 | Vibrio cidicii (taxid 1763883) (75.03%) |
| 50x | 7.00 | 8167 | 72.5 | 61.53 | 95.75 | 65.28 | 0.04 | 6.53 | 15.81 | Vibrio cidicii (taxid 1763883) (59.53%) |
| 100x | 9.75 | 15268 | 0.8 | 44.30 | 96.42 | 47.10 | 0.07 | 10.53 | 23.61 | Vibrio cidicii (taxid 1763883) (42.86%) |

**Recommended: 25x (medium confidence).** 25x retains 82.3% Vibrio-assigned bp and 77.1% of assembled bp in contigs at least 10 kb; at 50x and 100x these fall to 65.3%/61.5% and 47.1%/44.3% while Reyranella and unclassified fractions rise and N50 collapses at 100x.

**Ambiguity:** Mixed assembly and incomplete prior reciprocal ANI alignment; Kraken2 labels are provisional.

Prior full-depth assembly context: Vibrio cidicii, ANI 97.8414%, query-to-reference AF 0.2984, reverse AF 0.7683. This is a different assembly and does not validate this depth choice.

## BI0607_2

| Depth | Assembly Mb | Contigs | N50 kb | ≥10 kb bp % | Primary mapped % | Vibrio bp % | Bacillus bp % | Reyranella bp % | Unclassified bp % | Top Kraken label (bp %) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 25x | 5.98 | 5563 | 164.0 | 70.17 | 94.72 | 0.45 | 70.71 | 6.26 | 11.98 | Bacillus paralicheniformis (taxid 1648923) (61.06%) |
| 50x | 8.27 | 11168 | 56.0 | 50.77 | 95.82 | 0.69 | 51.14 | 11.65 | 18.60 | Bacillus paralicheniformis (taxid 1648923) (42.79%) |
| 100x | 11.89 | 17581 | 0.9 | 35.31 | 96.89 | 1.08 | 35.56 | 16.96 | 23.01 | Bacillus paralicheniformis (taxid 1648923) (29.76%) |

**Recommended: 25x (low confidence).** 25x retains the clearest Bacillus-assigned component (70.7% of assembled bp) and 70.2% of bp in contigs at least 10 kb; higher depths add fragmented and Reyranella-assigned sequence with little Vibrio signal at any depth.

**Ambiguity:** Biological target is unresolved and the dominant Kraken2 signal is Bacillus; this choice is only the least-confounded representation of the current reads.

Prior full-depth assembly context: Vibrio vulnificus, ANI 98.0584%, query-to-reference AF 0.1584, reverse AF 0.3671. This is a different assembly and does not validate this depth choice.

## BS0607_9

| Depth | Assembly Mb | Contigs | N50 kb | ≥10 kb bp % | Primary mapped % | Vibrio bp % | Bacillus bp % | Reyranella bp % | Unclassified bp % | Top Kraken label (bp %) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 25x | 6.71 | 6146 | 92.4 | 68.47 | 95.31 | 72.05 | 0.03 | 6.70 | 10.51 | Vibrio vulnificus Env1 (taxid 1246305) (68.01%) |
| 50x | 9.47 | 12322 | 2.6 | 48.71 | 96.48 | 51.12 | 0.03 | 13.24 | 17.51 | Vibrio vulnificus Env1 (taxid 1246305) (48.70%) |
| 100x | 14.06 | 18637 | 1.2 | 33.00 | 97.62 | 34.46 | 0.05 | 20.05 | 22.20 | Vibrio vulnificus Env1 (taxid 1246305) (32.96%) |

**Recommended: 25x (medium confidence).** 25x has 72.1% Vibrio-assigned bp and 68.5% of bp in contigs at least 10 kb; 50x and 100x inflate span and reduce these fractions to 51.1%/48.7% and 34.5%/33.0%, despite modestly higher self-mapping fractions.

**Ambiguity:** Full-depth prior ANI has low query aligned fraction; the assembly remains mixed and exact-depth ANI is unavailable.

Prior full-depth assembly context: Vibrio vulnificus, ANI 99.1897%, query-to-reference AF 0.1196, reverse AF 0.5206. This is a different assembly and does not validate this depth choice.

## CB0707_82

| Depth | Assembly Mb | Contigs | N50 kb | ≥10 kb bp % | Primary mapped % | Vibrio bp % | Bacillus bp % | Reyranella bp % | Unclassified bp % | Top Kraken label (bp %) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 25x | 5.16 | 473 | 138.1 | 95.52 | 99.60 | 99.39 | 0.03 | 0.07 | 0.26 | Vibrio vulnificus Env1 (taxid 1246305) (34.51%) |
| 50x | 5.21 | 639 | 152.9 | 95.08 | 99.61 | 98.68 | 0.07 | 0.17 | 0.58 | Vibrio vulnificus Env1 (taxid 1246305) (32.96%) |
| 100x | 5.33 | 1006 | 179.6 | 93.16 | 99.63 | 96.65 | 0.17 | 0.47 | 1.36 | Vibrio vulnificus Env1 (taxid 1246305) (33.39%) |

**Recommended: 25x (medium confidence).** 25x has 99.4% Vibrio-assigned bp, 473 contigs, and 95.5% of bp in contigs at least 10 kb. Higher depths slightly raise N50 but add 166 or 533 contigs and reduce Vibrio and long-contig fractions while primary mapping stays near 99.6%.

**Ambiguity:** 25x and 50x are both plausible; exact-depth ANI and independent completeness metrics are unavailable.

Prior full-depth assembly context: Vibrio vulnificus, ANI 99.9531%, query-to-reference AF 0.4875, reverse AF 0.9337. This is a different assembly and does not validate this depth choice.

## NB0507_14

| Depth | Assembly Mb | Contigs | N50 kb | ≥10 kb bp % | Primary mapped % | Vibrio bp % | Bacillus bp % | Reyranella bp % | Unclassified bp % | Top Kraken label (bp %) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 25x | 8.01 | 6113 | 103.7 | 73.88 | 94.16 | 80.87 | 0.03 | 3.56 | 6.81 | Vibrio diabolicus (taxid 50719) (60.58%) |
| 50x | 10.62 | 13362 | 8.8 | 48.32 | 95.22 | 67.26 | 0.05 | 6.87 | 11.62 | Vibrio diabolicus (taxid 50719) (44.71%) |
| 100x | 14.50 | 20941 | 1.0 | 40.11 | 96.28 | 52.98 | 0.07 | 10.95 | 15.80 | Vibrio diabolicus (taxid 50719) (32.95%) |

**Recommended: 25x (low confidence).** 25x has 80.9% Vibrio-assigned bp and 73.9% of bp in contigs at least 10 kb; at 50x and 100x these fall to 67.3%/48.3% and 53.0%/40.1%, with rising Reyranella and unclassified fractions and severe fragmentation.

**Ambiguity:** Kraken2 favors V. diabolicus in this stage while earlier full-depth ANI favored a V. vulnificus reference with low aligned fraction; old and new sequencing differ in candidate-contig support.

Prior full-depth assembly context: Vibrio vulnificus, ANI 95.8304%, query-to-reference AF 0.2612, reverse AF 0.5310. This is a different assembly and does not validate this depth choice.

## NB0507_8

| Depth | Assembly Mb | Contigs | N50 kb | ≥10 kb bp % | Primary mapped % | Vibrio bp % | Bacillus bp % | Reyranella bp % | Unclassified bp % | Top Kraken label (bp %) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 25x | 5.11 | 368 | 246.1 | 97.39 | 99.85 | 99.74 | 0.02 | 0.02 | 0.14 | Vibrio vulnificus Env1 (taxid 1246305) (91.15%) |
| 50x | 5.12 | 377 | 351.4 | 97.57 | 99.85 | 99.52 | 0.08 | 0.03 | 0.24 | Vibrio vulnificus Env1 (taxid 1246305) (90.87%) |
| 100x | 5.16 | 459 | 448.3 | 97.13 | 99.85 | 98.98 | 0.14 | 0.08 | 0.51 | Vibrio vulnificus Env1 (taxid 1246305) (85.45%) |

**Recommended: 50x (medium confidence).** 50x improves N50 from 246 kb to 351 kb with only 9 more contigs, nearly unchanged span (5.11 versus 5.12 Mb), stable 99.85% primary mapping, and 99.5% Vibrio-assigned bp. 100x raises N50 further but adds 82 contigs and lowers Vibrio/long-contig fractions.

**Ambiguity:** 25x is also defensible; exact-depth ANI and independent completeness metrics are unavailable.

Prior full-depth assembly context: Vibrio vulnificus, ANI 99.9608%, query-to-reference AF 0.9324, reverse AF 0.9643. This is a different assembly and does not validate this depth choice.

## Missing evidence and next validation

Run reciprocal ANI and aligned-fraction comparisons on the selected exact-depth assemblies before making species-level claims. Read-mapping breadth and independent completeness/contamination estimates are also missing. For mixed or taxonomically discordant isolates, compare alternative reference species and inspect read support and assembly completeness. Per-isolate distribution figures show contig-count distributions of length, GC, and coverage, plus assembled-bp Kraken2 composition. Contigs from the same assembly are correlated and should not be treated as independent biological samples.
