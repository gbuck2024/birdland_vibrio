# Frozen Phase II cluster biology: downsampled old NB0507-14

## Method

All 13,807 contigs were joined by exact ID to the original master table. The four ablation-run partitions at k=2 and k=5 were read without fitting. The baseline full-model partitions agree at both k values. Cluster labels are arbitrary between models and k values. Coverage is old-read self-mapping coverage on the old assembly. Kraken2 broad classes are provisional assignments, not organism identities.

Candidate enrichment uses the 41 initial Reyranella candidate IDs. Expected counts use all noncandidate contigs in the same log2 length bands as candidates (40 in 1–2 kb, one in 2–4 kb), weighted by candidate band counts. Fold = observed / expected; this is descriptive and does not assign a probability or establish contamination. Candidates were selected with Kraken2, so candidate enrichment and Reyranella classification are not independent evidence.

## Per-cluster summary

GC in %, length in bp, self-mapping coverage in x; values are medians. Taxon columns in `kraken_composition.tsv` report both contig counts and assembled bp for every cluster. Figures show count and bp fractions.

| Model | k | Cluster | Contigs | Assembled bp | Largest provisional class by bp | GC median | Length median | Coverage median | Candidates | Expected length matched | Fold |
|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| full | 2 | 0 | 508 | 6,244,690 | Vibrio | 44.85 | 5555 | 26.15 | 1 | 13.01 | 0.0768649 |
| full | 2 | 1 | 13,299 | 4,621,507 | Other classified | 63.30 | 283 | 1.81 | 40 | 27.99 | 1.42907 |
| full | 5 | 0 | 2,659 | 1,414,995 | Other classified | 66.31 | 486 | 2.53 | 41 | 8.85 | 4.63326 |
| full | 5 | 1 | 5,821 | 1,645,614 | Other classified | 66.54 | 271 | 1.53 | 0 | 0.00 | 0 |
| full | 5 | 2 | 3,943 | 1,162,828 | Vibrio | 48.57 | 271 | 1.62 | 0 | 0.49 | 0 |
| full | 5 | 3 | 362 | 6,112,210 | Vibrio | 44.90 | 10256 | 27.29 | 0 | 6.86 | 0 |
| full | 5 | 4 | 1,022 | 530,550 | Vibrio | 45.27 | 374 | 5.33 | 0 | 24.80 | 0 |
| gc_coverage | 2 | 0 | 8,900 | 3,154,117 | Other classified | 66.23 | 289 | 1.76 | 41 | 7.87 | 5.21133 |
| gc_coverage | 2 | 1 | 4,907 | 7,712,080 | Vibrio | 46.97 | 283 | 2.13 | 0 | 33.13 | 0 |
| gc_coverage | 5 | 0 | 3,636 | 1,559,828 | Other classified | 66.37 | 365 | 2.47 | 40 | 7.13 | 5.6091 |
| gc_coverage | 5 | 1 | 1,447 | 696,018 | Vibrio | 45.21 | 337 | 3.67 | 0 | 24.37 | 0 |
| gc_coverage | 5 | 2 | 560 | 6,153,560 | Vibrio | 45.20 | 3934 | 25.36 | 0 | 8.51 | 0 |
| gc_coverage | 5 | 3 | 4,788 | 1,464,687 | Other classified | 66.55 | 272 | 1.35 | 1 | 0.74 | 1.35833 |
| gc_coverage | 5 | 4 | 3,376 | 992,104 | Vibrio | 49.16 | 270 | 1.45 | 0 | 0.25 | 0 |
| gc_length | 2 | 0 | 5,215 | 7,802,963 | Vibrio | 47.35 | 279 | 1.98 | 0 | 33.13 | 0 |
| gc_length | 2 | 1 | 8,592 | 3,063,234 | Other classified | 66.39 | 291 | 1.79 | 41 | 7.87 | 5.21133 |
| gc_length | 5 | 0 | 2,256 | 1,278,976 | Other classified | 66.41 | 508 | 2.30 | 41 | 7.87 | 5.21133 |
| gc_length | 5 | 1 | 784 | 631,759 | Vibrio | 45.28 | 604 | 3.50 | 0 | 32.66 | 0 |
| gc_length | 5 | 2 | 314 | 6,028,252 | Vibrio | 44.91 | 12104 | 26.87 | 0 | 0.47 | 0 |
| gc_length | 5 | 3 | 4,242 | 1,162,738 | Vibrio | 48.33 | 268 | 1.73 | 0 | 0.00 | 0 |
| gc_length | 5 | 4 | 6,211 | 1,764,472 | Other classified | 66.48 | 273 | 1.63 | 0 | 0.00 | 0 |
| length_coverage | 2 | 0 | 13,381 | 4,693,308 | Other classified | 63.23 | 284 | 1.82 | 40 | 31.85 | 1.25598 |
| length_coverage | 2 | 1 | 426 | 6,172,889 | Vibrio | 44.92 | 8059 | 27.17 | 1 | 9.15 | 0.109261 |
| length_coverage | 5 | 0 | 3,573 | 1,080,857 | Vibrio | 62.35 | 291 | 2.56 | 0 | 0.00 | 0 |
| length_coverage | 5 | 1 | 2,405 | 1,582,599 | Other classified | 64.96 | 559 | 2.52 | 41 | 32.49 | 1.2621 |
| length_coverage | 5 | 2 | 7,240 | 2,025,141 | Unclassified | 63.04 | 267 | 1.30 | 0 | 0.00 | 0 |
| length_coverage | 5 | 3 | 326 | 6,049,506 | Vibrio | 44.90 | 11546 | 27.09 | 0 | 0.66 | 0 |
| length_coverage | 5 | 4 | 263 | 128,094 | Vibrio | 46.52 | 337 | 21.33 | 0 | 7.85 | 0 |

## Interpretation and limits

The table describes feature-defined groups and their provisional Kraken2 composition. Contig count and assembled-bp fractions can differ strongly because contig lengths differ. Correlated assembly fragments are not independent samples. Old-read self-mapping favors the assembly from which these contigs came; low coverage and provisional taxonomy alone cannot establish biological absence or contamination. The 41 candidate set was selected by Kraken2 and length, so compare these patterns with independent read mapping and exact k-mer support before making taxonomic or causal claims.

## Reproducible outputs

`cluster_contigs.tsv` is the full joined table. `kraken_composition.tsv`, `cluster_summary.tsv`, `feature_distributions.tsv`, and `candidate_enrichment.tsv` contain the source values and units. `figures/composition_k2.svg` and `figures/composition_k5.svg` compare count and assembled-bp fractions. `provenance.json` records input hashes and matching rules.
