# SRA Assembly Review

All six SRA SPAdes assemblies are in a biologically reasonable range for the inferred `Vibrio` species-level assignments.

| Sample | Contigs | Total bp | N50 | Longest contig | GC % | Initial interpretation |
|---|---:|---:|---:|---:|---:|---|
| SRR37851509_L7 | 85 | 5,069,492 | 874,954 | 954,261 | 45.31 | Reasonable `Vibrio parahaemolyticus`-scale assembly; low fragmentation. |
| SRR37851510_L7 | 71 | 5,066,687 | 952,840 | 1,788,923 | 45.31 | Reasonable `Vibrio parahaemolyticus`-scale assembly; low fragmentation. |
| SRR37852094_L7 | 109 | 5,142,880 | 452,400 | 1,107,396 | 44.55 | Reasonable `Vibrio alginolyticus`-scale assembly; moderate fragmentation. |
| SRR37852095_L7 | 102 | 5,190,047 | 556,107 | 1,858,277 | 44.80 | Reasonable `Vibrio diabolicus`-scale assembly; moderate fragmentation. |
| SRR37852096_L7 | 84 | 5,150,427 | 903,161 | 1,741,333 | 44.80 | Reasonable `Vibrio diabolicus`-scale assembly; low fragmentation. |
| SRR37852097_L7 | 173 | 4,970,811 | 188,603 | 380,860 | 46.51 | Reasonable `Vibrio vulnificus`-scale assembly, but the most fragmented of the SRA set. |

Notes:

- Total assembly sizes are approximately `4.97-5.19 Mb`, not inflated like the earlier mixed Buck assemblies.
- GC percentages are coherent with the inferred species groups: `V. parahaemolyticus` near `45.31%`, `V. alginolyticus`/`V. diabolicus` near `44.55-44.80%`, and `V. vulnificus` near `46.51%`.
- `SRR37852097_L7` has the highest contig count and lowest N50, so it is the main assembly to scrutinize in downstream contig-level GC x coverage plots.
