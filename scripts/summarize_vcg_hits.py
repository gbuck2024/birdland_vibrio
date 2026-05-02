#!/usr/bin/env python3
"""Summarize the best vcg BLAST hit per sample."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

BLAST_COLUMNS = [
    "qseqid",
    "sseqid",
    "pident",
    "length",
    "qstart",
    "qend",
    "sstart",
    "send",
    "evalue",
    "bitscore",
    "qcovs",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        required=True,
        help="Path to the vcg mining manifest TSV.",
    )
    parser.add_argument(
        "--summary-out",
        required=True,
        help="Path for the summary TSV with one best hit per sample.",
    )
    return parser.parse_args()


def load_manifest(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise SystemExit(f"ERROR: Required manifest not found: {path}")

    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))

    if not rows:
        raise SystemExit(f"ERROR: Manifest contains no sample rows: {path}")

    required_fields = {"sample_id", "assembly_fasta", "blast_output"}
    missing = required_fields.difference(rows[0].keys())
    if missing:
        joined = ", ".join(sorted(missing))
        raise SystemExit(f"ERROR: Manifest is missing required columns: {joined}")

    return rows


def best_hit_key(row: dict[str, str]) -> tuple[float, float, float, float, str, str]:
    return (
        float(row["bitscore"]),
        -float(row["evalue"]),
        float(row["pident"]),
        float(row["qcovs"]),
        row["qseqid"],
        row["sseqid"],
    )


def read_best_hit(path: Path) -> dict[str, str] | None:
    best_row: dict[str, str] | None = None

    with path.open("r", encoding="utf-8", newline="") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue

            fields = stripped.split("\t")
            if len(fields) != len(BLAST_COLUMNS):
                raise SystemExit(
                    f"ERROR: Unexpected BLAST column count in {path} line {line_number}: "
                    f"expected {len(BLAST_COLUMNS)}, found {len(fields)}"
                )

            row = dict(zip(BLAST_COLUMNS, fields))
            if best_row is None or best_hit_key(row) > best_hit_key(best_row):
                best_row = row

    return best_row


def main() -> int:
    args = parse_args()
    manifest_path = Path(args.manifest).resolve()
    summary_out = Path(args.summary_out).resolve()
    project_dir = manifest_path.parent.parent if manifest_path.parent.name == "configs" else manifest_path.parent
    manifest_rows = load_manifest(manifest_path)

    missing_outputs: list[str] = []
    summary_rows: list[dict[str, str]] = []

    for row in manifest_rows:
        sample_id = row["sample_id"]
        assembly_fasta = row["assembly_fasta"]
        blast_output = Path(row["blast_output"])
        if not blast_output.is_absolute():
            blast_output = (project_dir / blast_output).resolve()

        if not blast_output.is_file():
            missing_outputs.append(str(blast_output))
            continue

        best_hit = read_best_hit(blast_output)
        if best_hit is None:
            summary_rows.append(
                {
                    "sample_id": sample_id,
                    "assembly_fasta": assembly_fasta,
                    "blast_output": row["blast_output"],
                    "best_hit_found": "no",
                    "qseqid": "NA",
                    "sseqid": "NA",
                    "pident": "NA",
                    "length": "NA",
                    "qstart": "NA",
                    "qend": "NA",
                    "sstart": "NA",
                    "send": "NA",
                    "evalue": "NA",
                    "bitscore": "NA",
                    "qcovs": "NA",
                }
            )
            continue

        summary_rows.append(
            {
                "sample_id": sample_id,
                "assembly_fasta": assembly_fasta,
                "blast_output": row["blast_output"],
                "best_hit_found": "yes",
                **best_hit,
            }
        )

    if missing_outputs:
        joined = "\n".join(f"- {path}" for path in sorted(missing_outputs))
        raise SystemExit(
            "ERROR: Missing expected vcg BLAST outputs. Run the BLAST array jobs first or finish incomplete tasks:\n"
            f"{joined}"
        )

    summary_rows.sort(key=lambda row: row["sample_id"])
    summary_out.parent.mkdir(parents=True, exist_ok=True)

    with summary_out.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "sample_id",
                "assembly_fasta",
                "blast_output",
                "best_hit_found",
                *BLAST_COLUMNS,
            ],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(summary_rows)

    print(f"Wrote vcg best-hit summary: {summary_out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
