#!/usr/bin/env python3
"""Select one external reference per Buck assembly from reciprocal fastANI panels.

Input: the completed original, 25x, 50x and 100x long matrices. Output: one
24-row manifest for independent reference-coverage alignment. A reciprocal hit
with both alignment fractions >=0.5 is preferred; among those, highest mean
ANI wins. If none qualifies, the largest minimum AF wins and is flagged.
This selection is descriptive, not a species call.
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'ani/abrcms_poster/ani/exact_depth_validation_20261112/reference_coverage_manifest.tsv'
PANEL = ROOT / 'ani/abrcms_poster/ani/depth_ani_matrix_20261112'
STAGES = [('original', ROOT / 'ani/reference_panel_plus_unknown_matrix'),
          *[(d, PANEL / d) for d in ('25x', '50x', '100x')]]
FIELDS = ('condition', 'isolate', 'assembly_id', 'assembly_fasta', 'reference_id',
          'reference_fasta', 'reference_species', 'ani_forward_pct', 'ani_reverse_pct',
          'af_forward', 'af_reverse', 'selection_status')


def rows(path):
    with path.open(newline='', encoding='utf-8') as handle:
        return list(csv.DictReader(handle, delimiter='\t'))


def number(value):
    return None if value in ('', 'NA', None) else float(value)


def bacillus_comparison(assembly_id, assembly_fasta):
    stage = ROOT / 'ani/abrcms_poster/ani/exact_depth_validation_20261112'
    manifest = {r['assembly_id']: r for r in rows(stage / 'bacillus_comparison_manifest_v2.tsv')}
    entry = manifest.get(assembly_id)
    if entry is None or entry['assembly_fasta'] != assembly_fasta:
        raise ValueError(f'Missing or mismatched Bacillus comparator manifest: {assembly_id}')
    out = stage / 'bacillus_fastani' / assembly_id
    if not (out / 'COMPLETE').is_file():
        raise ValueError(f'Bacillus comparator job not verified: {assembly_id}')
    values = []
    for filename, expected_query, expected_reference in (
        ('forward.tsv', assembly_fasta, entry['reference_fasta']),
        ('reverse.tsv', entry['reference_fasta'], assembly_fasta),
    ):
        with (out / filename).open(newline='', encoding='utf-8') as handle:
            records = list(csv.reader(handle, delimiter='\t'))
        if len(records) != 1 or len(records[0]) != 5:
            raise ValueError(f'Expected one reciprocal Bacillus hit: {out / filename}')
        record = records[0]
        if Path(record[0]).resolve() != (ROOT / expected_query).resolve() or Path(record[1]).resolve() != (ROOT / expected_reference).resolve():
            raise ValueError(f'Bacillus FASTA path mismatch: {out / filename}')
        ani, mapped, fragments = map(float, record[2:])
        if not (0 <= ani <= 100 and 0 <= mapped <= fragments and fragments > 0):
            raise ValueError(f'Invalid Bacillus fastANI values: {out / filename}')
        values.append((ani, mapped / fragments))
    return entry, values[0][0], values[1][0], values[0][1], values[1][1]


def main():
    if OUT.exists():
        raise SystemExit(f'Refusing to replace {OUT}')
    references = rows(ROOT / 'configs/reference_sequence_manifest.tsv')
    ref_ids = {r['reference_id'] for r in references}
    if len(ref_ids) != 76:
        raise ValueError('Expected 76 distinct external references')
    output = []
    for condition, stage in STAGES:
        table = rows(stage / 'metrics/fastani_matrix_long.tsv')
        if len(table) != 82 * 82:
            raise ValueError(f'Incomplete ANI panel: {stage}')
        indexed = {(r['query_id'], r['reference_id']): r for r in table}
        buck = rows(stage / 'metrics/query_manifest.normalized.tsv')[-6:]
        if len(buck) != 6 or any(not r['genome_id'].startswith('Buck_') for r in buck):
            raise ValueError(f'Expected six Buck rows: {stage}')
        for b in buck:
            bid = b['genome_id']
            isolate = bid.split('_WKDL', 1)[0].removeprefix('Buck_')
            if isolate == 'BI0607_2':
                ref, ani_f, ani_r, af_f, af_r = bacillus_comparison(bid, b['genome_fasta'])
                output.append(dict(condition=condition, isolate=isolate, assembly_id=bid,
                                   assembly_fasta=b['genome_fasta'], reference_id=ref['reference_id'],
                                   reference_fasta=ref['reference_fasta'],
                                   reference_species='Bacillus paralicheniformis',
                                   ani_forward_pct=f'{ani_f:.4f}', ani_reverse_pct=f'{ani_r:.4f}',
                                   af_forward=f'{af_f:.4f}', af_reverse=f'{af_r:.4f}',
                                   selection_status='separate_competing_bacillus_reference'))
                continue
            options = []
            for ref in references:
                rid = ref['reference_id']
                forward = indexed[(bid, rid)]
                reverse = indexed[(rid, bid)]
                ani_f, ani_r = number(forward['ani_pct']), number(reverse['ani_pct'])
                af_f, af_r = number(forward['alignment_fraction']), number(reverse['alignment_fraction'])
                if None in (ani_f, ani_r, af_f, af_r):
                    continue
                minimum = min(af_f, af_r)
                good = minimum >= 0.5 and min(ani_f, ani_r) >= 95
                score = (good, (ani_f + ani_r) / 2 if good else minimum,
                         minimum if good else (ani_f + ani_r) / 2, rid)
                options.append((score, ref, ani_f, ani_r, af_f, af_r))
            if not options:
                raise ValueError(f'No reciprocal external-reference hit for {bid} in {condition}')
            score, ref, ani_f, ani_r, af_f, af_r = max(options, key=lambda x: x[0])
            output.append(dict(condition=condition, isolate=isolate, assembly_id=bid,
                               assembly_fasta=b['genome_fasta'], reference_id=ref['reference_id'],
                               reference_fasta=ref['reference_fasta'],
                               reference_species=indexed[(bid, ref['reference_id'])]['reference_species'],
                               ani_forward_pct=f'{ani_f:.4f}', ani_reverse_pct=f'{ani_r:.4f}',
                               af_forward=f'{af_f:.4f}', af_reverse=f'{af_r:.4f}',
                               selection_status='reciprocal_af_ge_0.5_ani_ge_95' if score[0]
                               else 'provisional_low_reciprocal_support'))
    if len(output) != 24 or len({r['assembly_id'] for r in output}) != 24:
        raise ValueError('Expected 24 unique assembly rows')
    for row in output:
        for col in ('assembly_fasta', 'reference_fasta'):
            if not (ROOT / row[col]).is_file():
                raise ValueError(f'Missing {col}: {row[col]}')
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open('x', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, FIELDS, delimiter='\t', lineterminator='\n')
        writer.writeheader()
        writer.writerows(output)
    print(f'Wrote {len(output)} rows: {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
