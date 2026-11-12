#!/usr/bin/env python3
"""Join validated ANI, reference coverage and BUSCO results for 24 assemblies."""
import csv
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STAGE = ROOT / 'ani/abrcms_poster/ani/exact_depth_validation_20261112'
DEPTH_STAGE = ROOT / 'ani/abrcms_poster/ani/gc_coverage_kraken_depth_20261111'
FIELDS = ('isolate', 'condition', 'assembly_id', 'assembly_bp', 'contigs', 'n50_bp',
          'reference_id', 'reference_species', 'ani_forward_pct', 'ani_reverse_pct',
          'af_forward', 'af_reverse', 'reference_covered_bp',
          'reference_covered_pct', 'reference_exactly_one_alignment_bp',
          'reference_exactly_one_alignment_pct', 'busco_total', 'busco_complete',
          'busco_single_copy', 'busco_duplicated', 'busco_fragmented',
          'busco_missing', 'busco_complete_pct', 'busco_duplicated_pct',
          'reference_selection_status')


def read_table(path):
    with path.open(newline='', encoding='utf-8') as handle:
        return list(csv.DictReader(handle, delimiter='\t'))


def busco_counts(path):
    content = path.read_text(encoding='utf-8')
    patterns = {
        'busco_complete': r'Complete BUSCOs \(C\)',
        'busco_single_copy': r'Complete and single-copy BUSCOs \(S\)',
        'busco_duplicated': r'Complete and duplicated BUSCOs \(D\)',
        'busco_fragmented': r'Fragmented BUSCOs \(F\)',
        'busco_missing': r'Missing BUSCOs \(M\)',
        'busco_total': r'Total BUSCO groups searched',
    }
    counts = {}
    for name, label in patterns.items():
        match = re.search(r'^\s*(\d+)\s+' + label, content, flags=re.MULTILINE)
        if not match:
            raise ValueError(f'Missing {label} in {path}')
        counts[name] = int(match.group(1))
    if (counts['busco_complete'] != counts['busco_single_copy'] + counts['busco_duplicated']
            or counts['busco_total'] != counts['busco_complete'] + counts['busco_fragmented'] + counts['busco_missing']):
        raise ValueError(f'Inconsistent BUSCO counts: {path}')
    return counts


def main():
    out_tsv = STAGE / 'metrics/exact_depth_comparison_v2.tsv'
    out_md = STAGE / 'metrics/exact_depth_report_v2.md'
    if out_tsv.exists() or out_md.exists():
        raise SystemExit('Refusing to replace an existing comparison output')
    manifest = read_table(STAGE / 'fixed_reference_coverage_manifest.tsv')
    if len(manifest) != 24 or len({r['assembly_id'] for r in manifest}) != 24:
        raise ValueError('Expected 24 unique assembly conditions')
    assemblies = {}
    for path in (ROOT / 'assembly/metrics/assembly_summary.tsv',
                 DEPTH_STAGE / 'metrics/assembly_summary.tsv'):
        for row in read_table(path):
            if row['sample_id'] in assemblies:
                raise ValueError(f'Duplicate assembly metrics: {row["sample_id"]}')
            assemblies[row['sample_id']] = row
    result = []
    for row in manifest:
        aid = row['assembly_id']
        coverage_dir = STAGE / 'fixed_reference_coverage_cigar' / aid
        busco_dir = STAGE / 'busco' / aid
        if not (coverage_dir / 'COMPLETE').is_file() or not (STAGE / 'busco' / (aid + '.lock') / 'COMPLETE').is_file():
            raise ValueError(f'Missing completion marker: {aid}')
        coverage = read_table(coverage_dir / 'reference_coverage.tsv')
        if len(coverage) != 1:
            raise ValueError(f'Invalid coverage table: {aid}')
        summaries = list(busco_dir.glob('short_summary.specific.bacteria_odb12.2.*.txt'))
        if len(summaries) != 1:
            raise ValueError(f'Expected one BUSCO text summary: {aid}')
        counts = busco_counts(summaries[0])
        a = assemblies[aid]
        c = coverage[0]
        result.append(dict(isolate=row['isolate'], condition=row['condition'], assembly_id=aid,
                           assembly_bp=a['contigs_total_bases'], contigs=a['contigs_sequences'],
                           n50_bp=a['contigs_n50'], reference_id=row['reference_id'],
                           reference_species=row['reference_species'],
                           ani_forward_pct=row['ani_forward_pct'], ani_reverse_pct=row['ani_reverse_pct'],
                           af_forward=row['af_forward'], af_reverse=row['af_reverse'],
                           reference_covered_bp=c['reference_covered_bp'],
                           reference_covered_pct=f"{100 * float(c['reference_covered_fraction']):.2f}",
                           reference_exactly_one_alignment_bp=c['reference_exactly_one_alignment_bp'],
                           reference_exactly_one_alignment_pct=f"{100 * float(c['reference_exactly_one_alignment_fraction']):.2f}",
                           **counts,
                           busco_complete_pct=f"{100 * counts['busco_complete'] / counts['busco_total']:.2f}",
                           busco_duplicated_pct=f"{100 * counts['busco_duplicated'] / counts['busco_total']:.2f}",
                           reference_selection_status=row['selection_status']))
    if len(result) != 24:
        raise ValueError('Incomplete 24-row result')
    with out_tsv.open('x', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS, delimiter='\t')
        writer.writeheader()
        writer.writerows(result)
    grouped = defaultdict(dict)
    for row in result:
        grouped[row['isolate']][row['condition']] = row
    lines = ['# Exact-depth assembly validation (CIGAR-corrected coverage)', '',
             '## Methods', '',
             'Twenty-four assemblies from six isolate labels were compared: original full-read plus nominal 25×, 50×, and 100×. Each isolate uses the same external reference across all four conditions, selected from its 25× reciprocal ANI/AF panel. ANI and directional AF use the completed fastANI panels, plus the separate Bacillus comparator run for BI0607_2. Reference coverage uses minimap2 -c base-level CIGAR primary assembly alignments with MAPQ ≥20, aligned block ≥1 kb, and identity ≥90%. Unique coverage means reference bases covered by exactly one retained primary alignment. BUSCO bacteria_odb12.2 complete markers estimate broad conserved-gene completeness; duplicated markers are an independent contamination signal, not a measured contaminant fraction. This v2 report supersedes the initial coverage table, whose PAF match counts were estimated without CIGAR and were unsuitable for the identity cutoff.', '',
             '## Observations', '']
    for isolate, conditions in grouped.items():
        if set(conditions) != {'original', '25x', '50x', '100x'}:
            raise ValueError(f'Missing condition for {isolate}')
        lines.extend([f'### {isolate}', '',
                      '| Condition | Assembly Mb | Contigs | N50 kb | Selected reference | ANI % (forward/reverse) | AF (forward/reverse) | Ref covered % | Exactly-one coverage % | BUSCO complete % | BUSCO duplicated % |',
                      '|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|'])
        for condition in ('original', '25x', '50x', '100x'):
            r = conditions[condition]
            lines.append(f"| {condition} | {int(r['assembly_bp']) / 1e6:.2f} | {r['contigs']} | {int(r['n50_bp']) / 1000:.1f} | {r['reference_id']} | {r['ani_forward_pct']}/{r['ani_reverse_pct']} | {r['af_forward']}/{r['af_reverse']} | {r['reference_covered_pct']} | {r['reference_exactly_one_alignment_pct']} | {r['busco_complete_pct']} | {r['busco_duplicated_pct']} |")
        lines.append('')
    lines.extend(['## Possible explanation', '',
                  'Differences across depths may reflect added low-abundance sequence, assembly fragmentation, repeats, or mixed material. These observations alone do not locate contamination or prove an isolate species.', '',
                  '## Limitations', '',
                  'The 76-reference panel contains Vibrio genomes; a separate Bacillus paralicheniformis comparator was added for BI0607_2. The fixed reference may not be the best-hit reference at every depth, and low reciprocal AF remains provisional. Reference coverage is conditional on the chosen reference and mapping filters; it is not whole-assembly completeness. BUSCO duplication can arise from genuine paralogs or assembly errors and can miss contaminants. The original assembly and subsamples come from the same sequencing run, so their rows are correlated, not independent samples.', '',
                  '## Next validation', '',
                  'For ambiguous isolates, add biologically plausible competing references and inspect read-supported breadth and marker placement. Confirm candidate species with reciprocal alignment fraction and independent isolate provenance.', '',
                  '## Source data', '',
                  '`fixed_reference_coverage_manifest.tsv`, per-assembly PAF and coverage TSVs under `fixed_reference_coverage_cigar/`, BUSCO summaries under `busco/`, and the four ANI long tables provide the underlying measurements. The earlier exploratory coverage outputs remain under `coverage/` and `fixed_reference_coverage/`. `metrics/exact_depth_comparison_v2.tsv` is the machine-readable summary.', ''])
    out_md.write_text('\n'.join(lines), encoding='utf-8')
    print(f'Wrote {len(result)} conditions: {out_tsv.relative_to(ROOT)} and {out_md.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
