#!/usr/bin/env python3
"""Inspect the saved vcg MAFFT alignment and summarize simple variation."""

from __future__ import annotations

import csv
from itertools import combinations
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
INPUT_FASTA = PROJECT_DIR / "vcg_mining" / "alignment" / "all_vcg_sequences.aligned.fasta"
OUTPUT_DIR = PROJECT_DIR / "vcg_mining" / "alignment_review"
PAIRWISE_TSV = OUTPUT_DIR / "vcg_pairwise_differences.tsv"
REPORT_MD = OUTPUT_DIR / "vcg_alignment_review.md"


def read_fasta(path: Path) -> list[tuple[str, str]]:
    if not path.is_file():
        raise SystemExit(f"ERROR: Required FASTA not found: {path}")

    records: list[tuple[str, str]] = []
    header: str | None = None
    sequence_parts: list[str] = []

    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue

            if line.startswith(">"):
                if header is not None:
                    records.append((header, "".join(sequence_parts).upper()))
                header = line[1:]
                sequence_parts = []
            else:
                if header is None:
                    raise SystemExit(f"ERROR: FASTA sequence encountered before header in {path}")
                sequence_parts.append(line)

    if header is not None:
        records.append((header, "".join(sequence_parts).upper()))

    if not records:
        raise SystemExit(f"ERROR: FASTA contains no records: {path}")

    return records


def count_pairwise_differences(sequence_a: str, sequence_b: str) -> int:
    return sum(base_a != base_b for base_a, base_b in zip(sequence_a, sequence_b))


def main() -> int:
    records = read_fasta(INPUT_FASTA)
    lengths = {header: len(sequence) for header, sequence in records}
    unique_lengths = sorted(set(lengths.values()))

    if len(unique_lengths) != 1:
        details = ", ".join(f"{header}={length}" for header, length in lengths.items())
        raise SystemExit(f"ERROR: Aligned FASTA contains unequal sequence lengths: {details}")

    alignment_length = unique_lengths[0]
    gap_counts = {header: sequence.count("-") for header, sequence in records}

    variable_columns: list[int] = []
    for index in range(alignment_length):
        observed_bases = {sequence[index] for _, sequence in records}
        if len(observed_bases) > 1:
            variable_columns.append(index + 1)

    pairwise_rows: list[dict[str, str]] = []
    for (header_a, sequence_a), (header_b, sequence_b) in combinations(records, 2):
        pairwise_rows.append(
            {
                "sequence_1": header_a,
                "sequence_2": header_b,
                "aligned_length": str(alignment_length),
                "pairwise_differences": str(count_pairwise_differences(sequence_a, sequence_b)),
                "gap_positions_sequence_1": str(gap_counts[header_a]),
                "gap_positions_sequence_2": str(gap_counts[header_b]),
            }
        )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    with PAIRWISE_TSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "sequence_1",
                "sequence_2",
                "aligned_length",
                "pairwise_differences",
                "gap_positions_sequence_1",
                "gap_positions_sequence_2",
            ],
            delimiter="\t",
        )
        writer.writeheader()
        writer.writerows(pairwise_rows)

    with REPORT_MD.open("w", encoding="utf-8") as handle:
        handle.write("# vcg Alignment Review\n\n")
        handle.write(f"- Input alignment: `{INPUT_FASTA.relative_to(PROJECT_DIR).as_posix()}`\n")
        handle.write(f"- Number of sequences: `{len(records)}`\n")
        handle.write(f"- Equal aligned length confirmed: `yes`\n")
        handle.write(f"- Aligned length: `{alignment_length}`\n")
        handle.write(f"- Variable alignment columns: `{len(variable_columns)}`\n")
        handle.write(f"- Variable column positions (1-based): `{', '.join(map(str, variable_columns)) if variable_columns else 'none'}`\n\n")
        handle.write("## Gap Counts Per Sequence\n\n")
        handle.write("| Sequence | Gap positions |\n")
        handle.write("| --- | ---: |\n")
        for header, _ in records:
            handle.write(f"| {header} | {gap_counts[header]} |\n")

        handle.write("\n## Pairwise Nucleotide Differences\n\n")
        handle.write("| Sequence 1 | Sequence 2 | Differences |\n")
        handle.write("| --- | --- | ---: |\n")
        for row in pairwise_rows:
            handle.write(
                f"| {row['sequence_1']} | {row['sequence_2']} | {row['pairwise_differences']} |\n"
            )

    print(f"Wrote pairwise TSV: {PAIRWISE_TSV.relative_to(PROJECT_DIR).as_posix()}")
    print(f"Wrote markdown report: {REPORT_MD.relative_to(PROJECT_DIR).as_posix()}")
    print(f"Aligned length confirmed: {alignment_length}")
    print(f"Variable columns: {len(variable_columns)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
