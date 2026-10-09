#!/usr/bin/env python3
"""Summarize the NB0507-14 old-vs-new resequencing comparison stage.

This script only parses existing summaries and small text tables. Heavy work
such as read downsampling, assembly, self-mapping, Kraken2, FastANI, and SNP
alignment is handled by SLURM scripts and summarized here after completion.
"""

from __future__ import annotations

import csv
import sys
import math
import re
import statistics
from collections import Counter
from pathlib import Path
from typing import Any


csv.field_size_limit(sys.maxsize)

PROJECT = Path(__file__).resolve().parent.parent
STAGE = PROJECT / "comparison_nb0507_14_resequencing"
METRICS = STAGE / "metrics"
FIGURES = STAGE / "figures"

OLD = "Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7"
NEW = "SRR37852095_L7"
DOWN = "Buck_NB0507_14_downsampled_to_SRR37852095_L7"

CONDITIONS = [
    {
        "condition": "A_old_full",
        "sample_id": OLD,
        "raw_fastqc_prefix": OLD,
        "trim_fastqc_prefix": OLD,
        "assembly_summary": PROJECT / "assembly/metrics/assembly_summary.tsv",
        "selfmap_short": "NB0507_14",
        "selfmap_root": PROJECT / "ambiguous_isolate_resolution/blobtoolkit",
        "read_kreport": PROJECT / f"kraken2_classification/reports/{OLD}.kreport.tsv",
        "contig_kreport": PROJECT
        / f"ambiguous_isolate_resolution/blobtoolkit/NB0507_14/taxonomy/{OLD}.spades_contigs.kreport.tsv",
        "trimmomatic_logs": list((PROJECT / "trimmomatic/logs/slurm").glob("trimmomatic_*.err")),
    },
    {
        "condition": "B_old_downsampled",
        "sample_id": DOWN,
        "raw_fastqc_prefix": DOWN,
        "trim_fastqc_prefix": DOWN,
        "assembly_summary": STAGE / "downsampled_old_assembly/metrics/assembly_summary.tsv",
        "selfmap_short": "NB0507_14_downsampled",
        "selfmap_root": STAGE / "downsampled_old_self_mapping",
        "read_kreport": STAGE
        / f"kraken2_downsampled_old/reports/{DOWN}.kreport.tsv",
        "contig_kreport": STAGE
        / f"downsampled_old_self_mapping/NB0507_14_downsampled/taxonomy/{DOWN}.spades_contigs.kreport.tsv",
        "trimmomatic_logs": [],
    },
    {
        "condition": "C_new",
        "sample_id": NEW,
        "raw_fastqc_prefix": NEW,
        "trim_fastqc_prefix": NEW,
        "assembly_summary": PROJECT / "assembly_sra/metrics/assembly_summary.tsv",
        "selfmap_short": "SRR37852095",
        "selfmap_root": PROJECT / "ambiguous_isolate_resolution/blobtoolkit_sra",
        "read_kreport": PROJECT / f"kraken2_classification_sra/reports/{NEW}.kreport.tsv",
        "contig_kreport": PROJECT
        / f"ambiguous_isolate_resolution/blobtoolkit_sra/SRR37852095/taxonomy/{NEW}.spades_contigs.kreport.tsv",
        "trimmomatic_logs": list((PROJECT / "trimmomatic/logs/slurm").glob("trimmomatic_*.err")),
    },
]


def clean(value: Any) -> str:
    if value is None:
        return "NA"
    if isinstance(value, float):
        if math.isnan(value):
            return "NA"
        return f"{value:.4f}".rstrip("0").rstrip(".")
    return str(value)


def read_tsv(path: Path) -> list[dict[str, str]]:
    if not path.is_file() or path.stat().st_size == 0:
        return []
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def write_tsv(path: Path, rows: list[dict[str, Any]], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, delimiter="\t", fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: clean(row.get(field)) for field in fields})


def parse_fastqc_data(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    modules: dict[str, dict[str, Any]] = {}
    current = ""
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            if line.startswith(">>END_MODULE"):
                current = ""
                continue
            if line.startswith(">>"):
                parts = line[2:].split("\t")
                current = parts[0]
                modules[current] = {"status": parts[1] if len(parts) > 1 else "NA", "rows": []}
                continue
            if current:
                if line.startswith("#") and not line.startswith("#Total Deduplicated Percentage"):
                    continue
                modules[current]["rows"].append(line.split("\t"))

    basic = {row[0]: row[1] for row in modules.get("Basic Statistics", {}).get("rows", []) if len(row) >= 2}
    qual_rows = modules.get("Per base sequence quality", {}).get("rows", [])
    means = [float(row[1]) for row in qual_rows if len(row) > 1 and row[1] not in {"Mean", ""}]
    dedup_rows = modules.get("Sequence Duplication Levels", {}).get("rows", [])
    dedup_pct = "NA"
    for row in dedup_rows:
        if row and row[0].startswith("#Total Deduplicated Percentage"):
            dedup_pct = row[1] if len(row) > 1 else "NA"
    overrep = modules.get("Overrepresented sequences", {}).get("rows", [])
    adapters = modules.get("Adapter Content", {}).get("rows", [])
    max_adapter = 0.0
    for row in adapters:
        for value in row[1:]:
            try:
                max_adapter = max(max_adapter, float(value))
            except ValueError:
                pass
    return {
        "total_sequences": int(basic.get("Total Sequences", "0").replace(",", "")) if basic.get("Total Sequences") else None,
        "total_bases": basic.get("Total Bases"),
        "read_length": basic.get("Sequence length"),
        "gc_pct": basic.get("%GC"),
        "per_base_quality_status": modules.get("Per base sequence quality", {}).get("status", "NA"),
        "minimum_mean_base_quality": min(means) if means else None,
        "deduplicated_pct": dedup_pct,
        "duplication_status": modules.get("Sequence Duplication Levels", {}).get("status", "NA"),
        "overrepresented_status": modules.get("Overrepresented sequences", {}).get("status", "NA"),
        "overrepresented_count": len(overrep),
        "adapter_status": modules.get("Adapter Content", {}).get("status", "NA"),
        "max_adapter_pct": max_adapter,
        "per_tile_quality_status": modules.get("Per tile sequence quality", {}).get("status", "NA"),
        "sequence_content_status": modules.get("Per base sequence content", {}).get("status", "NA"),
        "gc_status": modules.get("Per sequence GC content", {}).get("status", "NA"),
    }


def collect_fastqc(prefix: str, trimmed: bool = False) -> dict[str, Any]:
    root = PROJECT / ("trimmomatic/fastqc_trimmed_extracted" if trimmed else "fastqc_extracted")
    suffix = "_paired_fastqc" if trimmed else "_fastqc"
    mates = []
    for mate in ("1", "2"):
        path = root / f"{prefix}_{mate}{suffix}/fastqc_data.txt"
        parsed = parse_fastqc_data(path)
        if parsed:
            parsed["mate"] = f"R{mate}"
            mates.append(parsed)
    if not mates:
        return {}
    numeric = ["total_sequences", "minimum_mean_base_quality", "max_adapter_pct"]
    out: dict[str, Any] = {}
    for key in numeric:
        values = [m[key] for m in mates if m.get(key) is not None]
        if values:
            out[key] = sum(values) if key == "total_sequences" else min(values)
    out["read_pairs"] = min((m.get("total_sequences") or 0 for m in mates), default=0) or None
    for key in [
        "total_bases",
        "read_length",
        "gc_pct",
        "per_base_quality_status",
        "deduplicated_pct",
        "duplication_status",
        "overrepresented_status",
        "adapter_status",
        "per_tile_quality_status",
        "sequence_content_status",
        "gc_status",
    ]:
        out[key] = ";".join(f"{m['mate']}:{m.get(key, 'NA')}" for m in mates)
    out["overrepresented_count"] = sum(int(m.get("overrepresented_count") or 0) for m in mates)
    return out


def parse_trimmomatic(sample_id: str, log_paths: list[Path]) -> dict[str, Any]:
    pattern = re.compile(
        rf"Input Read Pairs:\s+(\d+)\s+Both Surviving:\s+(\d+) \(([^)]+)\).*?Dropped:\s+(\d+) \(([^)]+)\)"
    )
    for path in sorted(log_paths, key=lambda p: p.stat().st_mtime if p.exists() else 0, reverse=True):
        text = path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""
        if sample_id not in text:
            continue
        match = pattern.search(text)
        if match:
            return {
                "input_pairs": int(match.group(1)),
                "paired_retained": int(match.group(2)),
                "paired_retained_pct": match.group(3).rstrip("%"),
                "dropped_pairs": int(match.group(4)),
                "dropped_pct": match.group(5).rstrip("%"),
            }
    return {}


def assembly_row(condition: dict[str, Any]) -> dict[str, Any]:
    rows = read_tsv(condition["assembly_summary"])
    for row in rows:
        if row.get("sample_id") == condition["sample_id"]:
            return {
                "condition": condition["condition"],
                "sample_id": condition["sample_id"],
                "assembly_size_bp": row.get("contigs_total_bases"),
                "contig_count": row.get("contigs_sequences"),
                "contigs_ge_1000bp": row.get("contigs_ge_1000bp"),
                "n50_bp": row.get("contigs_n50"),
                "longest_contig_bp": row.get("contigs_longest"),
                "gc_pct": row.get("contigs_gc_pct"),
                "scaffold_count": row.get("scaffolds_sequences"),
                "scaffolds_ge_1000bp": row.get("scaffolds_ge_1000bp"),
                "scaffold_total_bases": row.get("scaffolds_total_bases"),
                "scaffold_n50_bp": row.get("scaffolds_n50"),
                "scaffold_longest_bp": row.get("scaffolds_longest"),
                "scaffold_gc_pct": row.get("scaffolds_gc_pct"),
            }
    return {"condition": condition["condition"], "sample_id": condition["sample_id"]}


def parse_flagstat(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    out: dict[str, Any] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if " in total " in line:
            out["total_reads"] = int(line.split()[0])
        elif " mapped (" in line and "primary" not in line:
            out["mapped_reads"] = int(line.split()[0])
            pct = re.search(r"\(([\d.]+)%", line)
            out["mapped_pct"] = float(pct.group(1)) if pct else None
        elif " properly paired " in line:
            out["properly_paired_reads"] = int(line.split()[0])
            pct = re.search(r"\(([\d.]+)%", line)
            out["properly_paired_pct"] = float(pct.group(1)) if pct else None
    return out


def coverage_row(condition: dict[str, Any]) -> dict[str, Any]:
    short_id = condition["selfmap_short"]
    root = condition["selfmap_root"]
    sample_id = condition["sample_id"]
    metrics_dir = root / short_id / "metrics"
    flagstat = metrics_dir / f"{sample_id}.self_contigs.sorted.flagstat.txt"
    master = metrics_dir / f"{short_id}.master_contig_table.tsv"
    rows = read_tsv(master)
    lengths = [int(r["length_bp"]) for r in rows if r.get("length_bp")]
    covs = [float(r["coverage"]) for r in rows if r.get("coverage") not in {"", None}]
    total_bases = sum(lengths)
    weighted_cov = (
        sum(int(r["length_bp"]) * float(r["coverage"]) for r in rows if r.get("length_bp") and r.get("coverage"))
        / total_bases
        if total_bases
        else None
    )
    median_cov = statistics.median(covs) if covs else None
    mean_cov = statistics.mean(covs) if covs else None
    sd_cov = statistics.pstdev(covs) if len(covs) > 1 else 0.0 if covs else None
    cv = (sd_cov / mean_cov) if mean_cov else None
    below10 = (
        100
        * sum(int(r["length_bp"]) for r in rows if r.get("coverage") and float(r["coverage"]) < 10)
        / total_bases
        if total_bases
        else None
    )
    above2x = (
        100
        * sum(int(r["length_bp"]) for r in rows if r.get("coverage") and median_cov and float(r["coverage"]) > 2 * median_cov)
        / total_bases
        if total_bases and median_cov
        else None
    )
    low = sum(1 for c in covs if median_cov and c < 0.25 * median_cov)
    high = sum(1 for c in covs if median_cov and c > 4 * median_cov)
    out = {
        "condition": condition["condition"],
        "sample_id": sample_id,
        "self_mapping_source": str(master.relative_to(PROJECT)) if master.is_file() else "missing",
        "mean_assembly_coverage": weighted_cov,
        "median_contig_coverage": median_cov,
        "coverage_cv_contig_mean": cv,
        "assembly_bases_below_10x_pct_contig_mean": below10,
        "assembly_bases_above_2x_median_pct_contig_mean": above2x,
        "unusually_low_coverage_contigs_lt_0.25x_median": low,
        "unusually_high_coverage_contigs_gt_4x_median": high,
    }
    out.update(parse_flagstat(flagstat))
    return out


def parse_kreport(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    best_by_rank: dict[str, tuple[float, str]] = {}
    rows = []
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            parts = raw.rstrip("\n").split("\t")
            if len(parts) < 6:
                continue
            pct = float(parts[0].strip())
            rank = parts[3].strip()
            name = parts[5].strip()
            rows.append((pct, rank, name))
            if rank in {"G", "S", "U"} and pct > best_by_rank.get(rank, (-1.0, ""))[0]:
                best_by_rank[rank] = (pct, name)
    species = [r for r in rows if r[1] == "S"]
    genus = [r for r in rows if r[1] == "G"]
    dominant_species = max(species, default=(None, None, "NA"), key=lambda r: r[0])
    dominant_genus = max(genus, default=(None, None, "NA"), key=lambda r: r[0])
    secondary = [f"{name}:{pct:.2f}%" for pct, rank, name in species if name != dominant_species[2] and pct >= 1.0]
    unclassified = best_by_rank.get("U", (0.0, "unclassified"))[0]
    return {
        "dominant_species": dominant_species[2],
        "dominant_species_pct": dominant_species[0],
        "dominant_genus": dominant_genus[2],
        "dominant_genus_pct": dominant_genus[0],
        "major_secondary_species_ge_1pct": ";".join(secondary[:8]) if secondary else "none_ge_1pct",
        "unclassified_pct": unclassified,
    }


def taxonomy_row(condition: dict[str, Any]) -> dict[str, Any]:
    short_id = condition["selfmap_short"]
    master = condition["selfmap_root"] / short_id / "metrics" / f"{short_id}.master_contig_table.tsv"
    contigs = read_tsv(master)
    total_contigs = len(contigs)
    total_bases = sum(int(r["length_bp"]) for r in contigs if r.get("length_bp"))
    vibrio_contigs = sum(1 for r in contigs if r.get("broad_taxon") == "Vibrio")
    vibrio_bases = sum(int(r["length_bp"]) for r in contigs if r.get("broad_taxon") == "Vibrio" and r.get("length_bp"))
    broad = Counter(r.get("broad_taxon", "NA") for r in contigs)
    read_tax = parse_kreport(condition["read_kreport"])
    contig_tax = parse_kreport(condition["contig_kreport"])
    return {
        "condition": condition["condition"],
        "sample_id": condition["sample_id"],
        "read_dominant_species": read_tax.get("dominant_species"),
        "read_dominant_species_pct": read_tax.get("dominant_species_pct"),
        "read_dominant_genus": read_tax.get("dominant_genus"),
        "read_dominant_genus_pct": read_tax.get("dominant_genus_pct"),
        "read_major_secondary_species_ge_1pct": read_tax.get("major_secondary_species_ge_1pct"),
        "read_unclassified_pct": read_tax.get("unclassified_pct"),
        "contig_dominant_species": contig_tax.get("dominant_species"),
        "contig_dominant_species_pct": contig_tax.get("dominant_species_pct"),
        "contigs_assigned_vibrio_pct": 100 * vibrio_contigs / total_contigs if total_contigs else None,
        "assembly_bases_assigned_vibrio_pct": 100 * vibrio_bases / total_bases if total_bases else None,
        "contig_broad_taxon_counts": ";".join(f"{k}:{v}" for k, v in broad.most_common(8)) if broad else "NA",
    }


def parse_ani() -> list[dict[str, Any]]:
    out = []
    for path in sorted((STAGE / "ani/outputs").glob("*.tsv")):
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            parts = line.split("\t")
            if len(parts) >= 5:
                query = Path(parts[0]).parent.name
                ref = Path(parts[1]).parent.name
                out.append(
                    {
                        "query": query,
                        "reference": ref,
                        "ani": parts[2],
                        "mapped_fragments": parts[3],
                        "total_query_fragments": parts[4],
                        "alignment_fraction": float(parts[3]) / float(parts[4]) if float(parts[4]) else None,
                    }
                )
    if not out:
        return [
            {
                "query": OLD,
                "reference": NEW,
                "ani": "PENDING_SLURM",
                "mapped_fragments": "NA",
                "total_query_fragments": "NA",
                "alignment_fraction": "NA",
                "reciprocal_alignment_fraction": "PENDING_SLURM",
            },
            {
                "query": NEW,
                "reference": OLD,
                "ani": "PENDING_SLURM",
                "mapped_fragments": "NA",
                "total_query_fragments": "NA",
                "alignment_fraction": "NA",
                "reciprocal_alignment_fraction": "PENDING_SLURM",
            },
        ]
    for row in out:
        recip = next((x for x in out if x["query"] == row["reference"] and x["reference"] == row["query"]), None)
        row["reciprocal_alignment_fraction"] = recip.get("alignment_fraction") if recip else "NA"
    return out


def build_matched_rows(raw: dict[str, dict[str, Any]], trimmed: dict[str, dict[str, Any]], trim: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    rows = []
    for condition in CONDITIONS:
        key = condition["condition"]
        row = {"condition": key, "sample_id": condition["sample_id"]}
        row.update({f"raw_{k}": v for k, v in raw.get(key, {}).items()})
        row.update({f"trimmed_{k}": v for k, v in trimmed.get(key, {}).items()})
        row.update(trim.get(key, {}))
        if row.get("raw_max_adapter_pct") is not None and row.get("trimmed_max_adapter_pct") is not None:
            row["adapter_max_pct_change_raw_minus_trimmed"] = float(row["raw_max_adapter_pct"]) - float(row["trimmed_max_adapter_pct"])
        rows.append(row)
    return rows


def write_markdown(rows: dict[str, list[dict[str, Any]]]) -> None:
    tax = {r["condition"]: r for r in rows["taxonomy"]}
    asm = {r["condition"]: r for r in rows["assembly"]}
    cov = {r["condition"]: r for r in rows["coverage"]}
    ani_ready = any(r.get("ani") not in {"PENDING_SLURM", None, "NA"} for r in rows["ani"])
    down_ready = asm.get("B_old_downsampled", {}).get("assembly_size_bp") not in {None, "NA", ""}
    old_tax = tax.get("A_old_full", {})
    new_tax = tax.get("C_new", {})
    text = [
        "# NB0507-14 matched-isolate resequencing comparison",
        "",
        "This comparison treats `Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7` and `SRR37852095_L7` as the same biological isolate sequenced in different runs. Existing raw/post-trim FastQC, Trimmomatic, SPAdes, self-contig mapping, BlobToolKit-style contig tables, and Kraken2 outputs were summarized without overwriting prior stages.",
        "",
        "## Current interpretation",
        "",
    ]
    if ani_ready:
        text.append("- FastANI has completed; use `old_vs_new_ani.tsv` as the primary same-isolate genome identity check.")
    else:
        text.append("- Same-isolate identity remains provisional because the stage-specific reciprocal FastANI and whole-genome SNP jobs are prepared but not yet run.")
    if down_ready:
        text.append("- The depth-controlled old-read assembly is present and included, so old-full, old-downsampled, and new can be compared directly.")
    else:
        text.append("- The matched-depth control is pending SLURM execution; current A-vs-C differences still confound sequencing depth with run quality.")
    text.extend(
        [
            f"- Read taxonomy reproduces the same broad identity: old dominant genus `{clean(old_tax.get('read_dominant_genus'))}` at `{clean(old_tax.get('read_dominant_genus_pct'))}%`; new dominant genus `{clean(new_tax.get('read_dominant_genus'))}` at `{clean(new_tax.get('read_dominant_genus_pct'))}%`.",
            f"- The new run is much smaller but cleaner by Kraken2 read purity: old unclassified `{clean(old_tax.get('read_unclassified_pct'))}%`; new unclassified `{clean(new_tax.get('read_unclassified_pct'))}%`.",
            f"- Assembly contiguity is much stronger for the new run before depth control: old N50 `{clean(asm.get('A_old_full', {}).get('n50_bp'))}` bp with `{clean(asm.get('A_old_full', {}).get('contig_count'))}` contigs; new N50 `{clean(asm.get('C_new', {}).get('n50_bp'))}` bp with `{clean(asm.get('C_new', {}).get('contig_count'))}` contigs.",
            f"- Coverage uniformity by contig mean favors the lower-CV condition: old CV `{clean(cov.get('A_old_full', {}).get('coverage_cv_contig_mean'))}`; new CV `{clean(cov.get('C_new', {}).get('coverage_cv_contig_mean'))}`.",
            "",
            "Per-base low/high coverage percentages were not inferred from external BWA reference mappings. They are contig-length-weighted summaries from each sample's self-mapping master contig table and should be interpreted as contig-mean coverage diagnostics, not pileup-level breadth.",
            "",
            "## Required follow-up before final biological conclusion",
            "",
            "Run `scripts/nb0507_14_resequencing_downsample.slurm` for the matched-depth old control, `scripts/nb0507_14_resequencing_fastani.slurm` for reciprocal FastANI, and `scripts/nb0507_14_resequencing_snp.slurm` for whole-genome alignment/SNP counting. Then rerun this summarizer.",
        ]
    )
    (METRICS / "matched_isolate_comparison.md").write_text("\n".join(text) + "\n", encoding="utf-8")


def main() -> int:
    METRICS.mkdir(parents=True, exist_ok=True)
    FIGURES.mkdir(parents=True, exist_ok=True)
    raw = {c["condition"]: collect_fastqc(c["raw_fastqc_prefix"], trimmed=False) for c in CONDITIONS}
    trimmed = {c["condition"]: collect_fastqc(c["trim_fastqc_prefix"], trimmed=True) for c in CONDITIONS}
    trim = {c["condition"]: parse_trimmomatic(c["sample_id"], c["trimmomatic_logs"]) for c in CONDITIONS}
    matched = build_matched_rows(raw, trimmed, trim)
    assembly = [assembly_row(c) for c in CONDITIONS]
    coverage = [coverage_row(c) for c in CONDITIONS]
    taxonomy = [taxonomy_row(c) for c in CONDITIONS]
    ani = parse_ani()

    write_tsv(METRICS / "matched_isolate_comparison.tsv", matched, sorted({k for r in matched for k in r}))
    write_tsv(
        METRICS / "assembly_comparison.tsv",
        assembly,
        [
            "condition",
            "sample_id",
            "assembly_size_bp",
            "contig_count",
            "contigs_ge_1000bp",
            "n50_bp",
            "longest_contig_bp",
            "gc_pct",
            "scaffold_count",
            "scaffolds_ge_1000bp",
            "scaffold_total_bases",
            "scaffold_n50_bp",
            "scaffold_longest_bp",
            "scaffold_gc_pct",
        ],
    )
    write_tsv(METRICS / "coverage_comparison.tsv", coverage, sorted({k for r in coverage for k in r}))
    write_tsv(METRICS / "taxonomy_comparison.tsv", taxonomy, sorted({k for r in taxonomy for k in r}))
    write_tsv(
        METRICS / "old_vs_new_ani.tsv",
        ani,
        ["query", "reference", "ani", "mapped_fragments", "total_query_fragments", "alignment_fraction", "reciprocal_alignment_fraction"],
    )
    write_markdown({"assembly": assembly, "coverage": coverage, "taxonomy": taxonomy, "ani": ani})
    print(f"Wrote comparison summaries under {METRICS.relative_to(PROJECT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
