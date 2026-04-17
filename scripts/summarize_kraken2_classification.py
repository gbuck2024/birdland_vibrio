#!/usr/bin/env python3
"""Summarize Kraken2 paired-end classification reports across all saved samples."""

from __future__ import annotations

import csv
import sys
from dataclasses import dataclass
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
MANIFEST_FILE = PROJECT_DIR / "configs" / "kraken2_classification_manifest.tsv"
REPORT_DIR = PROJECT_DIR / "kraken2_classification" / "reports"
OUTPUT_DIR = PROJECT_DIR / "kraken2_classification" / "outputs"
METRICS_DIR = PROJECT_DIR / "kraken2_classification" / "metrics"
SUMMARY_TSV = METRICS_DIR / "kraken2_classification_summary.tsv"


@dataclass(frozen=True)
class ReportRow:
    percent: float
    clade_reads: int
    taxon_reads: int
    rank_code: str
    taxid: str
    name: str


def load_manifest(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise SystemExit(f"ERROR: Required manifest not found: {path}")

    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)

    if not rows:
        raise SystemExit(f"ERROR: Manifest contains no sample rows: {path}")

    return rows


def parse_report(path: Path) -> list[ReportRow]:
    if not path.is_file():
        raise SystemExit(f"ERROR: Expected Kraken2 report missing: {path}")

    rows: list[ReportRow] = []
    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\n")
            if not line:
                continue

            fields = line.split("\t")
            if len(fields) < 6:
                raise SystemExit(f"ERROR: Malformed Kraken2 report line in {path}: {line}")

            percent_text, clade_reads, taxon_reads, rank_code, taxid = fields[:5]
            name = fields[5].strip()
            rows.append(
                ReportRow(
                    percent=float(percent_text),
                    clade_reads=int(clade_reads),
                    taxon_reads=int(taxon_reads),
                    rank_code=rank_code.strip(),
                    taxid=taxid.strip(),
                    name=name,
                )
            )

    if not rows:
        raise SystemExit(f"ERROR: Kraken2 report is empty: {path}")

    return rows


def require_nonempty_output(path: Path) -> None:
    if not path.is_file():
        raise SystemExit(f"ERROR: Expected Kraken2 output missing: {path}")

    if path.stat().st_size == 0:
        raise SystemExit(f"ERROR: Kraken2 output is empty: {path}")


def find_unclassified_row(rows: list[ReportRow]) -> ReportRow | None:
    for row in rows:
        if row.rank_code == "U" or row.name.lower() == "unclassified":
            return row
    return None


def find_root_row(rows: list[ReportRow]) -> ReportRow | None:
    for row in rows:
        if row.name.lower() == "root":
            return row
    return None


def top_hits(rows: list[ReportRow], prefix: str) -> list[ReportRow]:
    ranked = [row for row in rows if row.rank_code.startswith(prefix) and row.name]
    return sorted(ranked, key=lambda row: (row.clade_reads, row.percent, row.taxon_reads, row.name), reverse=True)


def looks_like_vibrio(name: str) -> bool:
    lowered = name.lower()
    return lowered == "vibrio" or lowered.startswith("vibrio ")


def percent(value: int, total: int) -> float:
    if total == 0:
        return 0.0
    return (value / total) * 100.0


def classify_sample(
    percent_classified: float,
    top_species: ReportRow | None,
    second_species: ReportRow | None,
    top_genus: ReportRow | None,
) -> tuple[str, str]:
    label_name = "NA"
    if top_species is not None:
        label_name = top_species.name
    elif top_genus is not None:
        label_name = top_genus.name

    if percent_classified < 20.0:
        return "mostly unclassified", f"mostly unclassified: only {percent_classified:.2f}% classified"

    if top_species is None:
        genus_name = top_genus.name if top_genus is not None else "NA"
        if top_genus is not None and top_genus.percent >= 20.0:
            return "genus-level only fit", f"genus-level only fit: {genus_name} present without species-level winner"
        return "mixed/ambiguous", "mixed/ambiguous: classified reads lack a clear species-level hit"

    second_species_percent = second_species.percent if second_species is not None else 0.0
    dominance_ratio = top_species.percent / second_species_percent if second_species_percent > 0 else float("inf")

    if (
        top_species.percent >= 40.0
        and dominance_ratio >= 2.0
        and (top_genus is None or top_genus.percent >= top_species.percent)
    ):
        return "strong species fit", f"strong species fit: {label_name} dominates the classified signal"

    if top_genus is not None and top_genus.percent >= 20.0 and top_species.percent < 20.0:
        return "genus-level only fit", f"genus-level only fit: {top_genus.name} present but species split is weak"

    return "mixed/ambiguous", f"mixed/ambiguous: {label_name} is top but competing hits remain substantial"


def main() -> int:
    samples = load_manifest(MANIFEST_FILE)
    METRICS_DIR.mkdir(parents=True, exist_ok=True)

    summary_rows: list[dict[str, str]] = []

    for sample in samples:
        sample_id = sample["sample_id"]
        read1 = sample["read1"]
        read2 = sample["read2"]
        report_path = REPORT_DIR / f"{sample_id}.kreport.tsv"
        output_path = OUTPUT_DIR / f"{sample_id}.kraken2.tsv"

        report_rows = parse_report(report_path)
        require_nonempty_output(output_path)
        unclassified_row = find_unclassified_row(report_rows)
        root_row = find_root_row(report_rows)

        if root_row is None:
            raise SystemExit(f"ERROR: Kraken2 report is missing the root row: {report_path}")

        unclassified_reads = unclassified_row.clade_reads if unclassified_row is not None else 0
        classified_reads = root_row.clade_reads
        total_reads = classified_reads + unclassified_reads
        percent_classified = percent(classified_reads, total_reads)

        if root_row.clade_reads != classified_reads:
            raise SystemExit(
                "ERROR: Kraken2 root row does not match derived classified count "
                f"for {sample_id}: root={root_row.clade_reads} derived={classified_reads}"
            )

        species_hits = top_hits(report_rows, "S")
        genus_hits = top_hits(report_rows, "G")

        top_species = species_hits[0] if species_hits else None
        second_species = species_hits[1] if len(species_hits) > 1 else None
        top_genus = genus_hits[0] if genus_hits else None

        classification_flag, short_interpretation = classify_sample(
            percent_classified=percent_classified,
            top_species=top_species,
            second_species=second_species,
            top_genus=top_genus,
        )

        top_hit_name = top_species.name if top_species is not None else (top_genus.name if top_genus is not None else "NA")
        top_hit_is_vibrio = "yes" if looks_like_vibrio(top_hit_name) else "no"

        summary_rows.append(
            {
                "sample_id": sample_id,
                "read1": read1,
                "read2": read2,
                "total_reads": str(total_reads),
                "classified_reads": str(classified_reads),
                "percent_classified": f"{percent_classified:.2f}",
                "top_species_hit": top_species.name if top_species is not None else "NA",
                "top_species_percent": f"{top_species.percent:.2f}" if top_species is not None else "NA",
                "top_genus_hit": top_genus.name if top_genus is not None else "NA",
                "top_genus_percent": f"{top_genus.percent:.2f}" if top_genus is not None else "NA",
                "second_best_species_hit": second_species.name if second_species is not None else "NA",
                "second_best_species_percent": f"{second_species.percent:.2f}" if second_species is not None else "NA",
                "top_hit_is_vibrio": top_hit_is_vibrio,
                "classification_flag": classification_flag,
                "short_interpretation": short_interpretation,
            }
        )

    fieldnames = [
        "sample_id",
        "read1",
        "read2",
        "total_reads",
        "classified_reads",
        "percent_classified",
        "top_species_hit",
        "top_species_percent",
        "top_genus_hit",
        "top_genus_percent",
        "second_best_species_hit",
        "second_best_species_percent",
        "top_hit_is_vibrio",
        "classification_flag",
        "short_interpretation",
    ]

    with SUMMARY_TSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(summary_rows)

    print(f"Wrote summary table: {SUMMARY_TSV.relative_to(PROJECT_DIR)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
