#!/usr/bin/env python3
"""Choose one 25x-derived comparator per isolate for cross-depth coverage."""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STAGE = ROOT / 'ani/abrcms_poster/ani/exact_depth_validation_20261112'
SOURCE = STAGE / 'reference_coverage_manifest.tsv'
OUT = STAGE / 'fixed_reference_coverage_manifest.tsv'
PANEL = ROOT / 'ani/abrcms_poster/ani/depth_ani_matrix_20261112'
PANELS = {'original': ROOT / 'ani/reference_panel_plus_unknown_matrix',
          **{d: PANEL / d for d in ('25x', '50x', '100x')}}


def read(path):
    with path.open(newline='', encoding='utf-8') as handle:
        return list(csv.DictReader(handle, delimiter='\t'))


def main():
    if OUT.exists():
        raise SystemExit(f'Refusing to replace {OUT}')
    rows = read(SOURCE)
    if len(rows) != 24:
        raise ValueError('Expected 24 source rows')
    chosen = {r['isolate']: r for r in rows if r['condition'] == '25x'}
    if len(chosen) != 6:
        raise ValueError('Expected one 25x comparator per isolate')
    panel_cache = {}
    output = []
    for row in rows:
        fixed = chosen[row['isolate']]
        out = dict(row)
        out['reference_id'] = fixed['reference_id']
        out['reference_fasta'] = fixed['reference_fasta']
        out['reference_species'] = fixed['reference_species']
        out['selection_status'] = 'fixed_reference_from_25x'
        if row['reference_id'] != fixed['reference_id']:
            condition = row['condition']
            if condition not in panel_cache:
                table = read(PANELS[condition] / 'metrics/fastani_matrix_long.tsv')
                panel_cache[condition] = {(r['query_id'], r['reference_id']): r for r in table}
            panel = panel_cache[condition]
            forward = panel.get((row['assembly_id'], fixed['reference_id']))
            reverse = panel.get((fixed['reference_id'], row['assembly_id']))
            if not forward or not reverse:
                raise ValueError(f'Missing fixed reference cells for {row["assembly_id"]}')
            out['ani_forward_pct'] = forward['ani_pct']
            out['ani_reverse_pct'] = reverse['ani_pct']
            out['af_forward'] = forward['alignment_fraction']
            out['af_reverse'] = reverse['alignment_fraction']
            if 'NA' in (out['ani_forward_pct'], out['ani_reverse_pct']):
                out['selection_status'] = 'fixed_reference_no_reciprocal_fastani_hit'
        output.append(out)
    if len(output) != 24 or len({r['assembly_id'] for r in output}) != 24:
        raise ValueError('Invalid fixed-reference manifest')
    with OUT.open('x', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), delimiter='\t', lineterminator='\n')
        writer.writeheader()
        writer.writerows(output)
    print(f'Wrote {len(output)} fixed-reference rows: {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
