#!/usr/bin/env python3
"""Summarize primary assembly-to-reference PAF with interval-union coverage.

Unique coverage is reference bp covered by exactly one retained primary query
alignment, not uniquely mappable sequence in the reference genome. Retain PAF
records with MAPQ >=20, aligned block >=1000 bp, and identity >=90%.
"""
import argparse
import csv
import gzip
from collections import defaultdict
from pathlib import Path


def fasta_lengths(path):
    opener = gzip.open if path.suffix == '.gz' else open
    lengths = {}
    name = None
    with opener(path, 'rt', encoding='ascii') as handle:
        for line in handle:
            if line.startswith('>'):
                name = line[1:].split()[0]
                if not name or name in lengths:
                    raise ValueError(f'Duplicate or empty FASTA ID: {name!r}')
                lengths[name] = 0
            elif line.strip():
                if name is None:
                    raise ValueError('Sequence before FASTA header')
                lengths[name] += len(line.strip())
    if not lengths or any(v <= 0 for v in lengths.values()):
        raise ValueError(f'Empty reference FASTA: {path}')
    return lengths


def summarize(reference, paf):
    lengths = fasta_lengths(reference)
    events = defaultdict(list)
    retained = 0
    aligned_query_bases = 0
    with paf.open(encoding='utf-8') as handle:
        for line_number, line in enumerate(handle, 1):
            fields = line.rstrip('\n').split('\t')
            if len(fields) < 12:
                raise ValueError(f'Malformed PAF line {line_number}')
            query_len, qs, qe = map(int, fields[1:4])
            target, target_len = fields[5], int(fields[6])
            ts, te = map(int, fields[7:9])
            matches, block, mapq = map(int, fields[9:12])
            if target not in lengths or lengths[target] != target_len:
                raise ValueError(f'Reference name/length mismatch: {target}')
            if not (0 <= qs < qe <= query_len and 0 <= ts < te <= target_len):
                raise ValueError(f'Out-of-range PAF interval on line {line_number}')
            if block <= 0 or matches > block:
                raise ValueError(f'Invalid PAF match count on line {line_number}')
            if mapq < 20 or block < 1000 or matches / block < 0.90:
                continue
            retained += 1
            aligned_query_bases += qe - qs
            events[target].extend(((ts, 1), (te, -1)))
    union = unique = 0
    for target_events in events.values():
        depth = previous = 0
        for position, change in sorted(target_events):
            span = position - previous
            if depth > 0:
                union += span
            if depth == 1:
                unique += span
            depth += change
            if depth < 0:
                raise ValueError('Invalid interval sweep')
            previous = position
        if depth != 0:
            raise ValueError('Unbalanced interval sweep')
    total = sum(lengths.values())
    return dict(reference_bp=total, reference_contigs=len(lengths),
                retained_primary_alignments=retained,
                aligned_query_bp_sum=aligned_query_bases,
                reference_covered_bp=union, reference_covered_fraction=f'{union / total:.6f}',
                reference_exactly_one_alignment_bp=unique,
                reference_exactly_one_alignment_fraction=f'{unique / total:.6f}',
                method='minimap2_asm10_cigar_secondary_no_MAPQ20_block1000_identity90')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--paf', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error(f'Refusing to replace {args.output}')
    row = summarize(args.reference, args.paf)
    with args.output.open('x', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, row.keys(), delimiter='\t')
        writer.writeheader()
        writer.writerow(row)


if __name__ == '__main__':
    main()
