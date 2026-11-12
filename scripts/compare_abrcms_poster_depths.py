#!/usr/bin/env python3
"""Compare 18 poster assemblies with read, self-mapping, Kraken2 and contig data."""
from __future__ import annotations

import argparse
import collections
import csv
import math
import re
import statistics
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
csv.field_size_limit(sys.maxsize)
BROAD = ("Vibrio", "Bacillus", "Reyranella", "Other classified", "Unclassified")


def load_table(path: Path) -> list[dict[str, str]]:
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"Missing or empty table: {path}")
    with path.open(newline="") as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    low = math.floor(position)
    high = math.ceil(position)
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def weighted_median(pairs: list[tuple[float, int]]) -> float:
    half = sum(weight for _, weight in pairs) / 2
    cumulative = 0
    for value, weight in sorted(pairs):
        cumulative += weight
        if cumulative >= half:
            return value
    raise ValueError("No weighted observations")


def flagstat_percent(path: Path, label: str) -> float:
    if not path.is_file():
        raise ValueError(f"Missing flagstat: {path}")
    pattern = re.compile(rf"^\d+ \+ \d+ {re.escape(label)} \(([0-9.]+)%", re.M)
    hit = pattern.search(path.read_text())
    if not hit:
        raise ValueError(f"Missing {label} percentage in {path}")
    return float(hit.group(1))


def write_tsv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("x", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", default="ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111")
    parser.add_argument("--manifest", default="configs/abrcms_poster_depth_20261111_blob.tsv")
    parser.add_argument("--decisions", default="configs/abrcms_poster_depth_decisions_20261112.tsv")
    args = parser.parse_args()
    stage = ROOT / args.stage
    metrics = stage / "metrics"
    outputs = {name: metrics / name for name in (
        "depth_comparison.tsv", "kraken_broad_composition.tsv", "kraken_taxon_composition.tsv",
        "contig_distribution_plot_data.tsv", "selected_depth.tsv", "depth_comparison_report.md")}
    existing = [str(path) for path in outputs.values() if path.exists()]
    if existing:
        parser.error("Refusing to replace existing output(s): " + ", ".join(existing))
    manifest = load_table(ROOT / args.manifest)
    if len(manifest) != 18 or len({r["short_id"] for r in manifest}) != 18:
        parser.error("Expected exactly 18 distinct depth conditions")
    assemblies = {r["sample_id"]: r for r in load_table(metrics / "assembly_summary.tsv")}
    reads = {r["subsample_id"]: r for r in load_table(metrics / "read_bases_and_depth.tsv")}
    if len(assemblies) != 18 or len(reads) != 18:
        parser.error("Expected 18 assembly and 18 read-base rows")
    context_rows = load_table(ROOT / "ani/reference_panel_plus_unknown_matrix/metrics/buck_reciprocal_ani_af_summary.tsv")
    context = {r["buck isolate"].split("_WKDL", 1)[0].removeprefix("Buck_"): r for r in context_rows}
    full_assemblies = {r["sample_id"].split("_WKDL", 1)[0].removeprefix("Buck_"): r["query_fasta"]
                       for r in load_table(ROOT / "configs/ani_query_manifest.tsv")}
    decisions = {r["isolate"]: r for r in load_table(ROOT / args.decisions)}
    if len(decisions) != 6 or set(decisions) != {r["short_id"].rsplit("_", 1)[0] for r in manifest}:
        parser.error("Decision manifest must contain exactly the six isolates")

    comparison: list[dict[str, object]] = []
    broad_rows: list[dict[str, object]] = []
    named_rows: list[dict[str, object]] = []
    plot_rows: list[dict[str, object]] = []
    for item in manifest:
        short, sample = item["short_id"], item["sample_id"]
        isolate, depth = short.rsplit("_", 1)
        if depth not in ("25x", "50x", "100x") or not sample.endswith("_" + depth):
            raise ValueError(f"Depth/sample ID mismatch: {short}, {sample}")
        assembly = assemblies[sample]
        read = reads[sample]
        if read["target_coverage"] != depth or assembly["read1"] != item["trimmed_r1"] or assembly["read2"] != item["trimmed_r2"]:
            raise ValueError(f"Assembly/read provenance mismatch: {short}")
        master = stage / "postassembly" / short / "metrics" / f"{short}.master_contig_table.tsv"
        flagstat = stage / "postassembly" / short / "metrics" / f"{sample}.self_contigs.sorted.flagstat.txt"
        lengths: list[float] = []
        gcs: list[float] = []
        coverages: list[float] = []
        weighted_coverage: list[tuple[float, int]] = []
        broad_bp: collections.Counter[str] = collections.Counter()
        broad_count: collections.Counter[str] = collections.Counter()
        named_bp: collections.Counter[tuple[str, str]] = collections.Counter()
        named_count: collections.Counter[tuple[str, str]] = collections.Counter()
        long_bp = long10_bp = zero_count = zero_bp = 0
        ids: set[str] = set()
        with master.open(newline="") as stream:
            for row in csv.DictReader(stream, delimiter="\t"):
                if row["short_id"] != short or row["sample_id"] != sample:
                    raise ValueError(f"Master-table identity mismatch: {master}")
                contig = row["contig_id"]
                if contig in ids:
                    raise ValueError(f"Duplicate contig ID in {master}: {contig}")
                ids.add(contig)
                length, gc, coverage = int(row["length_bp"]), float(row["gc_percent"]), float(row["coverage"])
                taxon = row["broad_taxon"]
                if length <= 0 or not (0 <= gc <= 100) or not math.isfinite(coverage) or coverage < 0 or taxon not in BROAD:
                    raise ValueError(f"Invalid contig metric: {short}, {contig}")
                lengths.append(length)
                gcs.append(gc)
                coverages.append(coverage)
                weighted_coverage.append((coverage, length))
                broad_bp[taxon] += length
                broad_count[taxon] += 1
                key = (row["taxon_label"], row["taxid"])
                named_bp[key] += length
                named_count[key] += 1
                long_bp += length if length >= 1000 else 0
                long10_bp += length if length >= 10000 else 0
                if coverage == 0:
                    zero_count += 1
                    zero_bp += length
                plot_rows.append(dict(isolate=isolate, depth=depth, short_id=short, length_bp=length,
                                      gc_percent=f"{gc:.4f}", coverage=f"{coverage:.4f}", broad_taxon=taxon))
        total_bp = sum(lengths)
        if not lengths or len(lengths) != int(assembly["contigs_sequences"]) or total_bp != int(assembly["contigs_total_bases"]):
            raise ValueError(f"Master table and assembly summary differ: {short}")
        primary_mapped = flagstat_percent(flagstat, "primary mapped")
        proper_pairs = flagstat_percent(flagstat, "properly paired")
        top_label, top_taxid = max(named_bp, key=named_bp.get)
        result: dict[str, object] = dict(
            isolate=isolate, depth=depth, short_id=short, sample_id=sample,
            read_pairs=read["read_pairs"], sequenced_bases=read["total_sequenced_bases"],
            bases_per_assumed_genome=read["sequenced_bases_per_assumed_genome"],
            contigs=len(lengths), assembly_bp=total_bp, n50_bp=assembly["contigs_n50"],
            length_p10_bp=f"{percentile(lengths, .1):.1f}", length_median_bp=f"{statistics.median(lengths):.1f}",
            length_p90_bp=f"{percentile(lengths, .9):.1f}", bp_ge_1kb_pct=f"{100*long_bp/total_bp:.2f}",
            bp_ge_10kb_pct=f"{100*long10_bp/total_bp:.2f}",
            gc_p10_pct=f"{percentile(gcs, .1):.2f}", gc_median_pct=f"{statistics.median(gcs):.2f}",
            gc_p90_pct=f"{percentile(gcs, .9):.2f}",
            coverage_p10=f"{percentile(coverages, .1):.3f}",
            coverage_median=f"{statistics.median(coverages):.3f}",
            coverage_p90=f"{percentile(coverages, .9):.3f}",
            coverage_bp_weighted_median=f"{weighted_median(weighted_coverage):.3f}",
            zero_coverage_contigs=zero_count, zero_coverage_bp_pct=f"{100*zero_bp/total_bp:.2f}",
            primary_mapped_pct=f"{primary_mapped:.2f}", properly_paired_pct=f"{proper_pairs:.2f}",
            top_kraken_label=top_label, top_kraken_taxid=top_taxid,
            top_kraken_bp_pct=f"{100*named_bp[(top_label,top_taxid)]/total_bp:.2f}",
            exact_depth_ani_pct="", exact_depth_alignment_fraction="", exact_depth_ani_status="not_measured",
            master_table=str(master.relative_to(ROOT)))
        for taxon in BROAD:
            key = taxon.lower().replace(" ", "_")
            result[f"{key}_contigs_pct"] = f"{100*broad_count[taxon]/len(lengths):.2f}"
            result[f"{key}_bp_pct"] = f"{100*broad_bp[taxon]/total_bp:.2f}"
            broad_rows.append(dict(isolate=isolate, depth=depth, short_id=short, broad_taxon=taxon,
                                   contigs=broad_count[taxon], assembled_bp=broad_bp[taxon],
                                   contigs_pct=f"{100*broad_count[taxon]/len(lengths):.2f}",
                                   assembled_bp_pct=f"{100*broad_bp[taxon]/total_bp:.2f}"))
        for label, taxid in named_bp:
            named_rows.append(dict(isolate=isolate, depth=depth, short_id=short, taxon_label=label, taxid=taxid,
                                   contigs=named_count[(label,taxid)], assembled_bp=named_bp[(label,taxid)],
                                   assembled_bp_pct=f"{100*named_bp[(label,taxid)]/total_bp:.2f}"))
        comparison.append(result)

    if len(comparison) != 18 or len({(r["isolate"], r["depth"]) for r in comparison}) != 18:
        raise ValueError("Missing or repeated depth condition")
    by_key = {(str(r["isolate"]), str(r["depth"])): r for r in comparison}
    selected: list[dict[str, object]] = []
    for isolate in sorted(decisions):
        decision = decisions[isolate]
        depth = decision["selected_depth"]
        if (isolate, depth) not in by_key or decision["selection_confidence"] not in ("low", "medium", "high"):
            raise ValueError(f"Invalid selection for {isolate}: {depth}")
        row = by_key[(isolate, depth)]
        prior = context.get(isolate)
        selected.append(dict(isolate=isolate, selected_depth=depth, sample_id=row["sample_id"],
                             selected_assembly=str(Path("ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111/assembly/assemblies") / str(row["sample_id"]) / "contigs.fasta"),
                             selected_master_table=row["master_table"], selection_confidence=decision["selection_confidence"],
                             rationale=decision["rationale"], ambiguities=decision["ambiguities"],
                             exact_depth_ani_pct="", exact_depth_alignment_fraction="",
                             exact_depth_ani_status="not_measured_for_any_of_18_depth_assemblies",
                             context_source_assembly=full_assemblies.get(isolate, ""),
                             context_candidate_species=prior["candidate species"] if prior else "",
                             context_ani_pct=prior["ANI"] if prior else "",
                             context_query_to_reference_af=prior["Buck->ref AF"] if prior else "",
                             context_reference_to_query_af=prior["ref AF -> Buck"] if prior else "",
                             missing_metrics="exact-depth ANI and reciprocal aligned fraction; read-mapping breadth; independent completeness/contamination estimate"))
    write_tsv(outputs["depth_comparison.tsv"], list(comparison[0]), comparison)
    write_tsv(outputs["kraken_broad_composition.tsv"], list(broad_rows[0]), broad_rows)
    write_tsv(outputs["kraken_taxon_composition.tsv"], list(named_rows[0]), named_rows)
    write_tsv(outputs["contig_distribution_plot_data.tsv"], list(plot_rows[0]), plot_rows)
    write_tsv(outputs["selected_depth.tsv"], list(selected[0]), selected)

    lines = ["# ABRCMS poster depth comparison", "", "## Scope and evidence", "",
             "Eighteen assemblies from six Buck isolates were compared at nominal 25x, 50x, and 100x. The read-base table records actual sequenced bases; bases per assumed genome uses the project's 5.2 Mb assumption and is not mapped coverage. Self-mapping percentages come from samtools flagstat for each read set against its own assembly. Contig GC, length and coverage come from the per-condition BlobToolKit master tables. Kraken2 assignments are provisional. Taxonomic percentages below use assembled bp, not contig counts.", "",
             "No ANI or aligned-fraction result exists for these exact 18 assemblies. The prior ANI columns in selected_depth.tsv describe different full-depth assemblies and must not be used to rank the depth conditions. No fixed genome-size cutoff was used for ambiguous isolates.", ""]
    for isolate in sorted(decisions):
        decision = decisions[isolate]
        lines.extend([f"## {isolate}", "", "| Depth | Assembly Mb | Contigs | N50 kb | ≥10 kb bp % | Primary mapped % | Vibrio bp % | Bacillus bp % | Reyranella bp % | Unclassified bp % | Top Kraken label (bp %) |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|"])
        for depth in ("25x", "50x", "100x"):
            row = by_key[(isolate, depth)]
            lines.append(f"| {depth} | {int(row['assembly_bp'])/1e6:.2f} | {row['contigs']} | {int(row['n50_bp'])/1000:.1f} | {row['bp_ge_10kb_pct']} | {row['primary_mapped_pct']} | {row['vibrio_bp_pct']} | {row['bacillus_bp_pct']} | {row['reyranella_bp_pct']} | {row['unclassified_bp_pct']} | {row['top_kraken_label']} ({row['top_kraken_bp_pct']}%) |")
        context_note = context.get(isolate)
        lines.extend(["", f"**Recommended: {decision['selected_depth']} ({decision['selection_confidence']} confidence).** {decision['rationale']}", "",
                      f"**Ambiguity:** {decision['ambiguities']}", ""])
        if context_note:
            lines.extend([f"Prior full-depth assembly context: {context_note['candidate species']}, ANI {context_note['ANI']}%, query-to-reference AF {context_note['Buck->ref AF']}, reverse AF {context_note['ref AF -> Buck']}. This is a different assembly and does not validate this depth choice.", ""])
    lines.extend(["## Missing evidence and next validation", "",
                  "Run reciprocal ANI and aligned-fraction comparisons on the selected exact-depth assemblies before making species-level claims. Read-mapping breadth and independent completeness/contamination estimates are also missing. For mixed or taxonomically discordant isolates, compare alternative reference species and inspect read support and assembly completeness. Per-isolate distribution figures show contig-count distributions of length, GC, and coverage, plus assembled-bp Kraken2 composition. Contigs from the same assembly are correlated and should not be treated as independent biological samples.", ""])
    outputs["depth_comparison_report.md"].write_text("\n".join(lines))
    print(f"Wrote 18 depth rows, {len(named_rows)} Kraken2 label rows, six selections, and report to {metrics}")


if __name__ == "__main__":
    main()
