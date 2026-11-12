#!/usr/bin/env python3
"""Create a four-condition manifest for an external competing reference."""
import argparse
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANEL = ROOT / 'ani/abrcms_poster/ani/depth_ani_matrix_20261112'
STAGES = [('original', ROOT / 'ani/reference_panel_plus_unknown_matrix'),
          *[(d, PANEL / d) for d in ('25x', '50x', '100x')]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--isolate', required=True)
    parser.add_argument('--reference-id', required=True)
    parser.add_argument('--reference-fasta', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error(f'Refusing to replace {args.output}')
    if not (ROOT / args.reference_fasta).is_file():
        parser.error(f'Missing reference: {args.reference_fasta}')
    output = []
    prefix = f'Buck_{args.isolate}_WKDL'
    for condition, stage in STAGES:
        with (stage / 'metrics/query_manifest.normalized.tsv').open(newline='', encoding='utf-8') as handle:
            rows = list(csv.DictReader(handle, delimiter='\t'))
        matching = [r for r in rows if r['genome_id'].startswith(prefix)]
        if len(matching) != 1 or not (ROOT / matching[0]['genome_fasta']).is_file():
            raise ValueError(f'Expected exactly one valid {args.isolate} assembly in {stage}')
        output.append(dict(condition=condition, isolate=args.isolate,
                           assembly_id=matching[0]['genome_id'],
                           assembly_fasta=matching[0]['genome_fasta'],
                           reference_id=args.reference_id, reference_fasta=str(args.reference_fasta)))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=output[0].keys(), delimiter='\t', lineterminator='\n')
        writer.writeheader()
        writer.writerows(output)
    print(f'Wrote {len(output)} rows: {args.output}')


if __name__ == '__main__':
    main()
