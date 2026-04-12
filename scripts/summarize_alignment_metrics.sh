#!/bin/bash
set -euo pipefail

METRICS_DIR="alignment/metrics"
OUTFILE="${METRICS_DIR}/alignment_summary.tsv"

echo -e "sample\ttotal_reads\tmapped_reads\tmapped_pct\tproperly_paired\tproperly_paired_pct\tsecondary\tsupplementary\tsingletons\tmate_diff_chr\tidx_mapped_sum\tidx_unmapped_sum" > "$OUTFILE"

for flag in "$METRICS_DIR"/*.flagstat.txt; do
    [ -e "$flag" ] || continue

    sample="$(basename "$flag" .flagstat.txt)"
    idx="${METRICS_DIR}/${sample}.idxstats.txt"

    total_reads=$(awk '/in total/ {print $1; exit}' "$flag")
    mapped_reads=$(awk '/ mapped \(/ && $0 !~ /primary mapped/ {print $1; exit}' "$flag")
    mapped_pct=$(awk -F'[()%]' '/ mapped \(/ && $0 !~ /primary mapped/ {gsub(/ /,"",$2); print $2; exit}' "$flag")
    properly_paired=$(awk '/properly paired/ {print $1; exit}' "$flag")
    properly_paired_pct=$(awk -F'[()%]' '/properly paired/ {gsub(/ /,"",$2); print $2; exit}' "$flag")
    secondary=$(awk '/secondary/ {print $1; exit}' "$flag")
    supplementary=$(awk '/supplementary/ {print $1; exit}' "$flag")
    singletons=$(awk '/singletons/ {print $1; exit}' "$flag")
    mate_diff_chr=$(awk '/with mate mapped to a different chr$/ {print $1; exit}' "$flag")

    idx_mapped_sum="NA"
    idx_unmapped_sum="NA"

    if [ -f "$idx" ]; then
        idx_mapped_sum=$(awk '{sum+=$3} END {print sum+0}' "$idx")
        idx_unmapped_sum=$(awk '{sum+=$4} END {print sum+0}' "$idx")
    fi

    echo -e "${sample}\t${total_reads}\t${mapped_reads}\t${mapped_pct}\t${properly_paired}\t${properly_paired_pct}\t${secondary}\t${supplementary}\t${singletons}\t${mate_diff_chr}\t${idx_mapped_sum}\t${idx_unmapped_sum}" >> "$OUTFILE"
done

echo "Wrote summary to: $OUTFILE"
