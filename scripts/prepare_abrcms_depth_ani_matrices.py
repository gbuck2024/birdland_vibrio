#!/usr/bin/env python3
"""Prepare three 82-genome fastANI stages matching the saved full-depth matrix.

Input: original 76-reference-plus-six-Buck matrix metadata and the 18-row
ABRCMS assembly summary. Output: six-row depth manifests, normalized 82-row
manifests, reference lists, and provenance, each in a new depth directory.
This performs no ANI computation and refuses to reuse an output stage.
"""
import csv
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OLD = Path('ani/reference_panel_plus_unknown_matrix')
DEPTH = Path('ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111')
STAGE = Path('ani/abrcms_poster/ani/depth_ani_matrix_20261112')
DEPTHS = ('25x', '50x', '100x')


def rows(path):
    with (ROOT / path).open(newline='', encoding='utf-8') as handle:
        result = list(csv.DictReader(handle, delimiter='\t'))
    if not result:
        raise ValueError(f'Empty table: {path}')
    return result


def write_tsv(path, fieldnames, data):
    with (ROOT / path).open('x', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter='\t')
        writer.writeheader()
        writer.writerows(data)


def main():
    old_query = rows(OLD / 'metrics/query_manifest.normalized.tsv')
    old_ref = rows(OLD / 'metrics/reference_manifest.normalized.tsv')
    original_buck = rows('configs/ani_unknown_query_manifest.tsv')
    assembly = rows(DEPTH / 'metrics/assembly_summary.tsv')
    raw_assembly = rows('configs/abrcms_poster_depth_20261111_assembly.tsv')
    refs = rows('configs/reference_sequence_manifest.tsv')
    if len(refs) != 76 or len(original_buck) != 6 or len(assembly) != 18 or len(raw_assembly) != 18:
        raise ValueError('Expected 76 references, 6 original Buck assemblies, and 18 depth assemblies')
    ref_ids = [r['reference_id'] for r in refs]
    original_ids = [r['sample_id'] for r in original_buck]
    if [r['genome_id'] for r in old_query] != ref_ids + original_ids or old_query != old_ref:
        raise ValueError('Saved original 82-genome panel differs from current manifests')
    for row, ref in zip(old_query[:76], refs):
        if row['genome_fasta'] != ref['reference_fasta']:
            raise ValueError(f'Reference path changed: {row["genome_id"]}')
    for row, buck in zip(old_query[76:], original_buck):
        if row['genome_fasta'] != buck['query_fasta']:
            raise ValueError(f'Original Buck path changed: {row["genome_id"]}')
    for name in ('fastani_genome_matrix.tsv', 'fastani_alignment_fraction_matrix.tsv'):
        with (ROOT / OLD / 'metrics' / name).open(newline='', encoding='utf-8') as handle:
            matrix = list(csv.reader(handle, delimiter='\t'))
        if len(matrix) != 83 or matrix[0] != ['query_id', *ref_ids, *original_ids] or [r[0] for r in matrix[1:]] != ref_ids + original_ids or any(len(r) != 83 for r in matrix):
            raise ValueError(f'Original matrix layout invalid: {name}')
    by_id = {r['sample_id']: r for r in assembly}
    if len(by_id) != 18 or {r['sample_id'] for r in raw_assembly} != set(by_id):
        raise ValueError('Assembly summary IDs do not match the 18-condition manifest')

    plans = {}
    for depth in DEPTHS:
        buck_rows, normalized = [], old_query[:76].copy()
        for original_id in original_ids:
            sample_id = f'{original_id}_{depth}'
            info = by_id.get(sample_id)
            if info is None:
                raise ValueError(f'Missing depth assembly: {sample_id}')
            fasta = Path(info['assembly_dir']) / 'contigs.fasta'
            if not (ROOT / fasta).is_file() or (ROOT / fasta).stat().st_size == 0:
                raise ValueError(f'Missing/empty ANI assembly: {fasta}')
            if not (ROOT / info['assembly_dir'] / 'scaffolds.fasta').is_file():
                raise ValueError(f'Missing SPAdes scaffold companion: {sample_id}')
            buck_rows.append({'sample_id': sample_id, 'query_fasta': str(fasta), 'is_unknown': 'yes',
                              'notes': f'ABRCMS 2026-11-11 paired-read subsample; nominal {depth}; source {original_id}; SPAdes contigs'})
            normalized.append({'genome_id': sample_id, 'genome_fasta': str(fasta), 'species': 'unknown',
                               'genome_type': 'query_genome', 'is_unknown': 'yes', 'notes': buck_rows[-1]['notes']})
        if len({r['genome_id'] for r in normalized}) != 82 or len({r['genome_fasta'] for r in normalized}) != 82:
            raise ValueError(f'Duplicate ID or FASTA in {depth} panel')
        plans[depth] = (buck_rows, normalized)

    if (ROOT / STAGE).exists():
        raise FileExistsError(f'Refusing to replace stage: {STAGE}')
    (ROOT / STAGE).mkdir(parents=True)
    for depth, (buck_rows, normalized) in plans.items():
        sub = STAGE / depth
        for directory in ('outputs', 'metrics', 'logs/slurm'):
            (ROOT / sub / directory).mkdir(parents=True)
        write_tsv(sub / 'buck_manifest.tsv', ['sample_id', 'query_fasta', 'is_unknown', 'notes'], buck_rows)
        fields = ['genome_id','genome_fasta','species','genome_type','is_unknown','notes']
        write_tsv(sub / 'metrics/query_manifest.normalized.tsv', fields, normalized)
        write_tsv(sub / 'metrics/reference_manifest.normalized.tsv', fields, normalized)
        with (ROOT / sub / 'metrics/fastani_reference_list.txt').open('x', encoding='utf-8') as handle:
            handle.writelines(r['genome_fasta'] + '\n' for r in normalized)
        provenance = [
            ('condition', depth), ('reference_count', '76'), ('buck_assembly_count', '6'),
            ('matrix_dimension', '82x82'), ('assembly_type', 'SPAdes contigs.fasta'),
            ('source_assembly_summary', str(DEPTH / 'metrics/assembly_summary.tsv')),
            ('original_matrix', str(OLD / 'metrics/fastani_genome_matrix.tsv')),
            ('fastani_fraglen', '3000'), ('fastani_kmer', '16'), ('fastani_min_fraction', '0.2'),
            ('af_definition', 'fragment_mappings/query_fragments (query direction)'),
        ]
        for key, source in [('original_query_manifest_sha256', OLD / 'metrics/query_manifest.normalized.tsv'),
                            ('assembly_summary_sha256', DEPTH / 'metrics/assembly_summary.tsv')]:
            provenance.append((key, hashlib.sha256((ROOT / source).read_bytes()).hexdigest()))
        write_tsv(sub / 'metrics/parameters.tsv', ['parameter','value'],
                  [{'parameter': key, 'value': value} for key, value in provenance])
        print(f'Prepared {sub}: 82 queries x 82 references')


if __name__ == '__main__':
    main()
