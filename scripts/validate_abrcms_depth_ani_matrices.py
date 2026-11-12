#!/usr/bin/env python3
"""Read-only preflight or completed-output check for the four 82-genome ANI panels."""
import argparse
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASE = Path('ani/abrcms_poster/ani/depth_ani_matrix_20261112')
ORIGINAL = Path('ani/reference_panel_plus_unknown_matrix')
DEPTHS = ('25x', '50x', '100x')


def table(path):
    with (ROOT / path).open(newline='', encoding='utf-8') as handle:
        return list(csv.DictReader(handle, delimiter='\t'))


def matrix(path):
    with (ROOT / path).open(newline='', encoding='utf-8') as handle:
        rows = list(csv.reader(handle, delimiter='\t'))
    if len(rows) != 83 or any(len(row) != 83 for row in rows):
        raise ValueError(f'Expected an 82 x 82 matrix: {path}')
    return rows


def check_stage(stage, reference_ids, depth, complete):
    queries = table(stage / 'metrics/query_manifest.normalized.tsv')
    references = table(stage / 'metrics/reference_manifest.normalized.tsv')
    if queries != references or len(queries) != 82:
        raise ValueError(f'Query/reference manifests differ or contain !=82 genomes: {stage}')
    ids = [row['genome_id'] for row in queries]
    fastas = [row['genome_fasta'] for row in queries]
    if len(set(ids)) != 82 or len(set(fastas)) != 82 or ids[:76] != reference_ids:
        raise ValueError(f'Duplicate or reordered panel: {stage}')
    if depth != 'original':
        if any(not x.startswith('Buck_') or not x.endswith('_' + depth) for x in ids[76:]):
            raise ValueError(f'Unexpected Buck depth IDs: {stage}')
        buck = table(stage / 'buck_manifest.tsv')
        if [r['sample_id'] for r in buck] != ids[76:] or [r['query_fasta'] for r in buck] != fastas[76:]:
            raise ValueError(f'Buck manifest differs from prepared matrix: {stage}')
        with (ROOT / stage / 'metrics/fastani_reference_list.txt').open(encoding='utf-8') as handle:
            listed = [line.rstrip('\n') for line in handle]
        if listed != fastas:
            raise ValueError(f'fastANI reference list differs from matrix manifest: {stage}')
        for directory in ('outputs', 'metrics', 'logs/slurm'):
            if not (ROOT / stage / directory).is_dir():
                raise ValueError(f'Missing prepared directory: {stage / directory}')
    for fasta in fastas:
        path = ROOT / fasta
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f'Missing or empty FASTA: {fasta}')
    if not complete:
        if any((ROOT / stage / 'outputs').iterdir()) or (ROOT / stage / 'matrix.lock').exists():
            raise ValueError(f'Stage already attempted; inspect before submission: {stage}')
        if any((ROOT / stage / 'metrics' / name).exists() for name in
               ('fastani_genome_matrix.tsv', 'fastani_alignment_fraction_matrix.tsv', 'fastani_matrix_long.tsv')):
            raise ValueError(f'Matrix output already exists: {stage}')
        print(f'PREFLIGHT {depth}: 82 unique genomes, 76 common references, six depth assemblies, empty outputs')
        return

    outdir = ROOT / stage / 'outputs'
    actual = {p.name for p in outdir.glob('*.fastani.tsv')}
    wanted = {f'{genome_id}.fastani.tsv' for genome_id in ids}
    if actual != wanted:
        missing, extra = sorted(wanted-actual), sorted(actual-wanted)
        raise ValueError(f'Raw fastANI output set differs: {stage}; '
                         f'{len(missing)} missing (first five: {missing[:5]}), '
                         f'{len(extra)} extra (first five: {extra[:5]})')
    for qid, qfasta in zip(ids, fastas):
        with (outdir / f'{qid}.fastani.tsv').open(newline='', encoding='utf-8') as handle:
            raw = list(csv.reader(handle, delimiter='\t'))
        seen = set()
        for record in raw:
            if len(record) != 5 or record[0] != qfasta or record[1] not in fastas or record[1] in seen:
                raise ValueError(f'Malformed, unknown, or duplicate raw fastANI hit: {qid}')
            seen.add(record[1])
            value, mapped, fragments = map(float, record[2:])
            if not (0 <= value <= 100 and 0 <= mapped <= fragments and fragments > 0):
                raise ValueError(f'Out-of-range raw fastANI hit: {qid} -> {record[1]}')
    ani = matrix(stage / 'metrics/fastani_genome_matrix.tsv')
    af = matrix(stage / 'metrics/fastani_alignment_fraction_matrix.tsv')
    if ani[0] != ['query_id', *ids] or af[0] != ani[0] or [r[0] for r in ani[1:]] != ids or [r[0] for r in af[1:]] != ids:
        raise ValueError(f'Matrix row/column order differs from manifest: {stage}')
    long = table(stage / 'metrics/fastani_matrix_long.tsv')
    if len(long) != 82 * 82:
        raise ValueError(f'Expected 6,724 long-table comparisons: {stage}')
    n_hit = 0
    for i, qid in enumerate(ids):
        for j, rid in enumerate(ids):
            row = long[i * 82 + j]
            if row['query_id'] != qid or row['reference_id'] != rid or row['query_fasta'] != fastas[i] or row['reference_fasta'] != fastas[j]:
                raise ValueError(f'Long-table ID/path mismatch at {qid} -> {rid}')
            if row['ani_pct'] != ani[i + 1][j + 1] or row['alignment_fraction'] != af[i + 1][j + 1]:
                raise ValueError(f'Matrix/long-table mismatch at {qid} -> {rid}')
            if row['ani_pct'] != 'NA':
                n_hit += 1
                value = float(row['ani_pct'])
                fraction = float(row['alignment_fraction'])
                if not (0 <= value <= 100 and 0 <= fraction <= 1):
                    raise ValueError(f'Out-of-range ANI or AF at {qid} -> {rid}')
            elif row['alignment_fraction'] != 'NA':
                raise ValueError(f'AF exists without ANI at {qid} -> {rid}')
    print(f'COMPLETE {depth}: 82 raw outputs; 82 x 82 ANI/AF; 6,724 long rows; {n_hit} reported ANI hits')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('preflight', 'complete'), required=True)
    parser.add_argument('--depth', choices=DEPTHS + ('original', 'all'), default='all')
    args = parser.parse_args()
    reference_ids = [r['reference_id'] for r in table('configs/reference_sequence_manifest.tsv')]
    if len(reference_ids) != 76:
        raise ValueError('Reference manifest must contain exactly 76 genomes')
    if args.mode == 'preflight' and args.depth == 'original':
        parser.error('Original depth is already complete; use --mode complete')
    if args.mode == 'complete' and args.depth in ('original', 'all'):
        check_stage(ORIGINAL, reference_ids, 'original', True)
    selected = DEPTHS if args.depth == 'all' else (() if args.depth == 'original' else (args.depth,))
    for depth in selected:
        check_stage(BASE / depth, reference_ids, depth, args.mode == 'complete')


if __name__ == '__main__':
    main()
