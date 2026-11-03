#!/usr/bin/env python3
"""Describe frozen Phase II clusters using the original contig annotations.

Input contracts: 13,807-row master TSV, 41 candidate IDs, completed baseline
and ablation runs. No model is fitted. Output is a new, exclusive run directory.
"""
from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import html
import json
import math
import statistics
from pathlib import Path

N = 13807
TAXA = ("Vibrio", "Reyranella", "Bacillus", "Other classified", "Unclassified")
MODELS = ("full", "gc_coverage", "gc_length", "length_coverage")
KS = (2, 5)
COLORS = ("#2875a9", "#b85b9b", "#c18a28", "#87939d", "#d6d9dc")


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def table(path, required):
    with path.open(newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        if not set(required) <= set(reader.fieldnames or ()):
            raise ValueError(f"{path}: missing columns {set(required) - set(reader.fieldnames or ())}")
        return list(reader)


def write(path, fields, rows):
    with path.open("x", newline="") as f:
        writer = csv.writer(f, delimiter="\t", lineterminator="\n")
        writer.writerow(fields)
        writer.writerows(rows)


def quantiles(values):
    a = sorted(values)
    if not a:
        raise ValueError("Empty distribution")
    def q(p):
        pos = (len(a) - 1) * p
        lo, hi = math.floor(pos), math.ceil(pos)
        return a[lo] + (a[hi] - a[lo]) * (pos - lo)
    return (q(0), q(.25), q(.5), q(.75), q(1))


def band(length):
    return math.floor(math.log2(length / 1000))


def assignments(path, models):
    rows = table(path, ("k", "contig_id", "cluster"))
    result = collections.defaultdict(dict)
    for r in rows:
        model = r.get("model", "full")
        k = int(r["k"])
        if model not in models or k not in KS:
            continue
        cluster = int(r["cluster"])
        if cluster < 0 or cluster >= k:
            raise ValueError(f"Bad cluster {cluster} for {model}, k={k}")
        key = (model, k)
        if r["contig_id"] in result[key]:
            raise ValueError(f"Duplicate assignment: {key} {r['contig_id']}")
        result[key][r["contig_id"]] = cluster
    return result


def svg_figure(path, k, composition, summary):
    # Each model is a row; each cluster has a count and assembled-bp bar.
    width, left, barw = 1200, 205, 420
    row_h, top = 32, 116
    height = top + 4 * k * row_h + 42
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
             '<rect width="100%" height="100%" fill="white"/>',
             f'<text x="20" y="29" font-size="20" font-family="sans-serif">Frozen Phase II clusters, k={k}</text>',
             '<text x="205" y="55" font-size="13" font-family="sans-serif">Contig fraction</text>',
             '<text x="660" y="55" font-size="13" font-family="sans-serif">Assembled bp fraction</text>']
    x = 20
    for taxon, color in zip(TAXA, COLORS):
        parts += [f'<rect x="{x}" y="71" width="12" height="12" fill="{color}"/>',
                  f'<text x="{x+17}" y="82" font-size="11" font-family="sans-serif">{html.escape(taxon)}</text>']
        x += 120 if taxon != "Other classified" else 155
    bykey = {(r[0], int(r[1]), int(r[2]), r[3]): (int(r[4]), int(r[5])) for r in composition}
    summ = {(r[0], int(r[1]), int(r[2])): (int(r[3]), int(r[4])) for r in summary}
    for mi, model in enumerate(MODELS):
        for cluster in range(k):
            y = top + (mi * k + cluster) * row_h
            n, bp = summ[(model, k, cluster)]
            parts.append(f'<text x="20" y="{y+13}" font-size="12" font-family="sans-serif">{model} / {cluster} (n={n})</text>')
            for x0, total, ix in ((left, n, 0), (660, bp, 1)):
                offset = 0.0
                for taxon, color in zip(TAXA, COLORS):
                    value = bykey[(model, k, cluster, taxon)][ix]
                    w = barw * value / total
                    parts.append(f'<rect x="{x0+offset:.3f}" y="{y}" width="{w:.3f}" height="17" fill="{color}"/>')
                    offset += w
            if cluster == k - 1:
                parts.append(f'<line x1="20" x2="1080" y1="{y+25}" y2="{y+25}" stroke="#bbb"/>')
    parts.append('</svg>')
    path.write_text("\n".join(parts) + "\n")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("master", "candidate-ids", "baseline", "ablation", "output"):
        p.add_argument("--" + name, type=Path, required=True)
    p.add_argument("--validate-only", action="store_true")
    a = p.parse_args()
    if a.output.exists():
        p.error(f"Output exists: {a.output}")
    for run in (a.baseline, a.ablation):
        if not (run / "COMPLETE").is_file():
            p.error(f"Run lacks COMPLETE: {run}")
        prov = json.loads((run / "provenance.json").read_text())
        if prov["master_sha256"] != sha(a.master) or prov["candidate_ids_sha256"] != sha(a.candidate_ids):
            p.error(f"Input hash mismatch against {run}")
    raw = table(a.master, ("contig_id", "length_bp", "gc_percent", "coverage", "broad_taxon"))
    if len(raw) != N:
        p.error(f"Expected {N} master contigs, got {len(raw)}")
    master = {}
    for r in raw:
        cid = r["contig_id"]
        if not cid or cid in master or r["broad_taxon"] not in TAXA:
            p.error(f"Invalid ID or taxon for {cid}")
        length, gc, cov = int(r["length_bp"]), float(r["gc_percent"]), float(r["coverage"])
        if length <= 0 or not 0 <= gc <= 100 or cov < 0 or not all(map(math.isfinite, (gc, cov))):
            p.error(f"Invalid features for {cid}")
        master[cid] = (length, gc, cov, r["broad_taxon"])
    candidates = [s.strip() for s in a.candidate_ids.read_text().splitlines() if s.strip()]
    if len(candidates) != 41 or len(set(candidates)) != 41 or not set(candidates) <= master.keys():
        p.error("Candidate list must contain 41 unique master IDs")
    candidates = set(candidates)
    base = assignments(a.baseline / "assignments.tsv", {"full"})
    ablation = assignments(a.ablation / "assignments.tsv", set(MODELS))
    for key in [(m, k) for m in MODELS for k in KS]:
        if set(ablation[key]) != master.keys():
            p.error(f"Incomplete/foreign ablation assignment IDs: {key}")
    for k in KS:
        if set(base[("full", k)]) != master.keys():
            p.error(f"Incomplete/foreign baseline assignment IDs: k={k}")
    # Baseline and ablation full models should coincide; labels may permute.
    # Preserve the ablation labels as the common four-model frame.
    agreement = {}
    for k in KS:
        groups = collections.defaultdict(set)
        for cid, cluster in base[("full", k)].items():
            groups[cluster].add(cid)
        target = {frozenset(cid for cid, c in ablation[("full", k)].items() if c == cl) for cl in range(k)}
        if {frozenset(s) for s in groups.values()} != target:
            p.error(f"Baseline and ablation full partitions disagree at k={k}")
        agreement[str(k)] = "identical partition (cluster labels may differ)"
    if a.validate_only:
        print(f"PASS: {N} master IDs, 41 candidate IDs, 8 complete frozen partitions; baseline full agrees at k=2,5")
        return

    # Length strata: [1000,2000), [2000,4000), etc. Noncandidate pool.
    cband = collections.Counter(band(master[c][0]) for c in candidates)
    background = collections.defaultdict(list)
    for cid, (length, _, _, _) in master.items():
        if cid not in candidates:
            background[band(length)].append(cid)
    if any(not background[b] for b in cband):
        p.error("Candidate length band has no noncandidate background")
    composition, summary, distribution, enrichment, joined = [], [], [], [], []
    for model in MODELS:
        for k in KS:
            labels = ablation[(model, k)]
            for cid, cl in labels.items():
                length, gc, cov, taxon = master[cid]
                joined.append((model, k, cid, cl, length, gc, cov, taxon, int(cid in candidates)))
            for cl in range(k):
                ids = [cid for cid, v in labels.items() if v == cl]
                n = len(ids)
                if not n:
                    p.error(f"Empty cluster: {model} k={k} cluster={cl}")
                bp = sum(master[c][0] for c in ids)
                cand = sum(c in candidates for c in ids)
                summary.append((model, k, cl, n, bp, cand, round(cand / n, 6)))
                for taxon in TAXA:
                    subset = [c for c in ids if master[c][3] == taxon]
                    subbp = sum(master[c][0] for c in subset)
                    composition.append((model, k, cl, taxon, len(subset), subbp, round(len(subset) / n, 6), round(subbp / bp, 6)))
                for field, ix, unit in (("gc_percent", 1, "%"), ("length_bp", 0, "bp"), ("self_mapping_coverage", 2, "x")):
                    q = quantiles([master[c][ix] for c in ids])
                    distribution.append((model, k, cl, field, unit, n, *(round(x, 6) for x in q)))
                # Expected candidate count under the empirical noncandidate cluster
                # proportions in the exact candidate length strata.
                expected = sum(count * sum(labels[c] == cl for c in background[b]) / len(background[b]) for b, count in cband.items())
                fold = cand / expected if expected else (float("inf") if cand else 0.0)
                enrichment.append((model, k, cl, cand, 41, round(expected, 6), round(cand / 41, 6), round(expected / 41, 6), f"{fold:.6g}"))
    out = a.output
    out.mkdir(parents=True, exist_ok=False)
    (out / "figures").mkdir()
    write(out / "cluster_contigs.tsv", ("model", "k", "contig_id", "cluster", "length_bp", "gc_percent", "self_mapping_coverage", "broad_taxon", "candidate"), joined)
    write(out / "cluster_summary.tsv", ("model", "k", "cluster", "contigs", "assembled_bp", "candidate_contigs", "candidate_fraction"), summary)
    write(out / "kraken_composition.tsv", ("model", "k", "cluster", "provisional_class", "contigs", "assembled_bp", "contig_fraction", "bp_fraction"), composition)
    write(out / "feature_distributions.tsv", ("model", "k", "cluster", "feature", "unit", "n", "min", "q25", "median", "q75", "max"), distribution)
    write(out / "candidate_enrichment.tsv", ("model", "k", "cluster", "observed_candidates", "total_candidates", "expected_length_matched", "observed_fraction", "background_fraction", "fold_enrichment"), enrichment)
    for k in KS:
        svg_figure(out / "figures" / f"composition_k{k}.svg", k, composition, summary)
    provenance = {"question": "Biological composition of frozen Phase II contig clusters", "observation_unit": "assembly contig", "master": str(a.master), "master_sha256": sha(a.master), "candidate_ids": str(a.candidate_ids), "candidate_ids_sha256": sha(a.candidate_ids), "baseline": str(a.baseline), "baseline_assignments_sha256": sha(a.baseline / "assignments.tsv"), "ablation": str(a.ablation), "ablation_assignments_sha256": sha(a.ablation / "assignments.tsv"), "baseline_full_agreement": agreement, "k": KS, "models": MODELS, "background": "All noncandidate contigs within each candidate-occupied log2 length band anchored at 1000 bp; expected count sums candidate count in each band times background cluster fraction in that band", "candidate_band_counts": dict(cband), "background_band_counts": {str(b): len(background[b]) for b in cband}, "classification": "Original master broad_taxon; Kraken2 assignments are provisional"}
    (out / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    comp = {(m, int(k), int(cl)): (tax, n, bp) for m, k, cl, tax, n, bp, *_ in composition}
    dist = {(m, int(k), int(cl), feature): med for m, k, cl, feature, _, _, _, _, med, _, _ in distribution}
    enr = {(m, int(k), int(cl)): (obs, exp, fold) for m, k, cl, obs, _, exp, _, _, fold in enrichment}
    lines = ["# Frozen Phase II cluster biology: downsampled old NB0507-14", "", "## Method", "", "All 13,807 contigs were joined by exact ID to the original master table. The four ablation-run partitions at k=2 and k=5 were read without fitting. The baseline full-model partitions agree at both k values. Cluster labels are arbitrary between models and k values. Coverage is old-read self-mapping coverage on the old assembly. Kraken2 broad classes are provisional assignments, not organism identities.", "", "Candidate enrichment uses the 41 initial Reyranella candidate IDs. Expected counts use all noncandidate contigs in the same log2 length bands as candidates (40 in 1–2 kb, one in 2–4 kb), weighted by candidate band counts. Fold = observed / expected; this is descriptive and does not assign a probability or establish contamination. Candidates were selected with Kraken2, so candidate enrichment and Reyranella classification are not independent evidence.", "", "## Per-cluster summary", "", "GC in %, length in bp, self-mapping coverage in x; values are medians. Taxon columns in `kraken_composition.tsv` report both contig counts and assembled bp for every cluster. Figures show count and bp fractions.", "", "| Model | k | Cluster | Contigs | Assembled bp | Largest provisional class by bp | GC median | Length median | Coverage median | Candidates | Expected length matched | Fold |", "|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|"]
    for m, k, cl, n, bp, cand, _ in summary:
        taxon = max(TAXA, key=lambda t: next(r[5] for r in composition if r[0] == m and r[1] == k and r[2] == cl and r[3] == t))
        obs, exp, fold = enr[(m, k, cl)]
        lines.append(f"| {m} | {k} | {cl} | {n:,} | {bp:,} | {taxon} | {dist[(m,k,cl,'gc_percent')]:.2f} | {dist[(m,k,cl,'length_bp')]:.0f} | {dist[(m,k,cl,'self_mapping_coverage')]:.2f} | {obs} | {exp:.2f} | {fold} |")
    lines += ["", "## Interpretation and limits", "", "The table describes feature-defined groups and their provisional Kraken2 composition. Contig count and assembled-bp fractions can differ strongly because contig lengths differ. Correlated assembly fragments are not independent samples. Old-read self-mapping favors the assembly from which these contigs came; low coverage and provisional taxonomy alone cannot establish biological absence or contamination. The 41 candidate set was selected by Kraken2 and length, so compare these patterns with independent read mapping and exact k-mer support before making taxonomic or causal claims.", "", "## Reproducible outputs", "", "`cluster_contigs.tsv` is the full joined table. `kraken_composition.tsv`, `cluster_summary.tsv`, `feature_distributions.tsv`, and `candidate_enrichment.tsv` contain the source values and units. `figures/composition_k2.svg` and `figures/composition_k5.svg` compare count and assembled-bp fractions. `provenance.json` records input hashes and matching rules.", ""]
    (out / "report.md").write_text("\n".join(lines))
    if len(summary) != 28 or len(composition) != 140 or len(joined) != 8 * N:
        raise ValueError("Unexpected output row counts")
    (out / "COMPLETE").write_text("Validated 28 clusters, 140 taxon rows, and 110456 joined assignments.\n")
    print(f"Completed {out}")


if __name__ == "__main__":
    main()
