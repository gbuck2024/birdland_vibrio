#!/usr/bin/env python3
"""Plot six paired original/25x assemblies from the validated exact-depth TSV.

Run from the project root with:
  python3 ani/abrcms_poster/ani/figures/assembly_original_vs_25x/assembly_comparison_4panel.py

Requires Python standard library and rsvg-convert. Refuses to replace outputs.
"""

import csv
import math
from pathlib import Path
import subprocess
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[5]
SOURCE = ROOT / "ani/abrcms_poster/ani/exact_depth_validation_20261112/metrics/exact_depth_comparison_v2.tsv"
OUT = Path(__file__).resolve().parent
ISOLATES = ("BI0607_1", "BI0607_2", "BS0607_9", "CB0707_82", "NB0507_14", "NB0507_8")
NAVY = "#344967"
TEAL = "#087F82"
INK = "#263343"
MUTED = "#596777"
GRID = "#DFE5E9"


def load_pairs():
    with SOURCE.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        needed = {"isolate", "condition", "reference_id", "reference_species",
                  "ani_forward_pct", "af_forward", "contigs", "n50_bp"}
        if not needed.issubset(reader.fieldnames or []):
            raise ValueError(f"Source TSV lacks columns: {sorted(needed - set(reader.fieldnames or []))}")
        pairs = {}
        for row in reader:
            if row["isolate"] not in ISOLATES or row["condition"] not in ("original", "25x"):
                continue
            key = row["isolate"], row["condition"]
            if key in pairs:
                raise ValueError(f"Duplicate isolate/condition row: {key}")
            for col in ("ani_forward_pct", "af_forward", "contigs", "n50_bp"):
                value = float(row[col])
                if not math.isfinite(value):
                    raise ValueError(f"Non-finite {col} for {key}")
            if not (90 <= float(row["ani_forward_pct"]) <= 100):
                raise ValueError(f"ANI outside displayed range for {key}")
            if not (0 <= float(row["af_forward"]) <= 1):
                raise ValueError(f"AF outside [0, 1] for {key}")
            if int(row["contigs"]) <= 0 or int(row["n50_bp"]) <= 0:
                raise ValueError(f"Non-positive contigs or N50 for {key}")
            pairs[key] = row
    for isolate in ISOLATES:
        old, new = (pairs.get((isolate, cond)) for cond in ("original", "25x"))
        if old is None or new is None:
            raise ValueError(f"Expected one original and one 25x row for {isolate}")
        if old["reference_id"] != new["reference_id"] or old["reference_species"] != new["reference_species"]:
            raise ValueError(f"Reference differs between conditions for {isolate}")
    return pairs


def txt(x, y, value, size=18, anchor="start", fill=INK, weight="normal", extra=""):
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" text-anchor="{anchor}" '
            f'fill="{fill}" font-weight="{weight}" {extra}>{escape(str(value))}</text>')


def line(x1, y1, x2, y2, stroke=GRID, width=1):
    return f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{stroke}" stroke-width="{width}"/>'


def panel(parts, pairs, letter, title, ylabel, x0, y0, column, limits, ticks, tick_labels, log=False, multiplier=1):
    plot_left, plot_right = x0 + 88, x0 + 622
    plot_top, plot_bottom = y0 + 42, y0 + 292
    parts.append(txt(x0, y0 + 5, letter, 28, weight="bold"))
    parts.append(txt(x0 + 48, y0 + 5, title, 23, weight="bold"))
    if log:
        parts.append(txt(plot_right, y0 + 5, "log scale", 15, anchor="end", fill=MUTED))
    parts.append(txt(x0 + 10, (plot_top + plot_bottom) / 2, ylabel, 19, anchor="middle",
                     extra=f'transform="rotate(-90 {x0 + 10:.1f} {(plot_top + plot_bottom) / 2:.1f})"'))

    def ymap(value):
        v = math.log10(value) if log else value
        low = math.log10(limits[0]) if log else limits[0]
        high = math.log10(limits[1]) if log else limits[1]
        return plot_bottom - (v - low) / (high - low) * (plot_bottom - plot_top)

    for tick, label in zip(ticks, tick_labels):
        y = ymap(tick)
        parts.append(line(plot_left, y, plot_right, y, GRID, 1))
        parts.append(txt(plot_left - 12, y + 6, label, 16, anchor="end", fill=MUTED))
    parts.append(line(plot_left, plot_top, plot_left, plot_bottom, MUTED, 1.2))
    parts.append(line(plot_left, plot_bottom, plot_right, plot_bottom, MUTED, 1.2))
    for i, isolate in enumerate(ISOLATES):
        xc = plot_left + (i + .5) * (plot_right - plot_left) / 6
        old = float(pairs[(isolate, "original")][column]) * multiplier
        new = float(pairs[(isolate, "25x")][column]) * multiplier
        y_old, y_new = ymap(old), ymap(new)
        parts.append(line(xc - 13, y_old, xc + 13, y_new, "#AAB5BF", 1.5))
        for x, y, color in ((xc - 13, y_old, NAVY), (xc + 13, y_new, TEAL)):
            parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="7.2" fill="{color}" stroke="white" stroke-width="1.5"/>')
        label = isolate.replace("_", "-")
        lx, ly = xc + 18, plot_bottom + 19
        parts.append(txt(lx, ly, label, 15, anchor="end", fill=INK,
                         extra=f'transform="rotate(-42 {lx:.1f} {ly:.1f})"'))


def make_svg(pairs):
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="15in" height="11in" viewBox="0 0 1500 1100">',
             '<rect width="1500" height="1100" fill="white"/>',
             '<g font-family="DejaVu Sans, sans-serif">']
    parts.append(txt(750, 53, "Effects of Sequencing-Read Downsampling on Genomic Similarity", 29,
                     anchor="middle", weight="bold"))
    parts.append(txt(750, 91, "and Assembly Contiguity", 29, anchor="middle", weight="bold"))
    parts.append(txt(750, 127, "Six paired isolates (n = 6)  ·  selected reference held fixed within each isolate", 17,
                     anchor="middle", fill=MUTED))
    legend_y = 164
    for x, color, label in ((475, NAVY, "Original full-read assembly"), (860, TEAL, "25× downsampled and reassembled")):
        parts.append(f'<circle cx="{x}" cy="{legend_y-6}" r="8" fill="{color}"/>')
        parts.append(txt(x + 20, legend_y, label, 18))
    panel(parts, pairs, "A", "Average nucleotide identity", "ANI (%)", 67, 210,
          "ani_forward_pct", (90, 100), [90, 92, 94, 96, 98, 100], ["90", "92", "94", "96", "98", "100"])
    panel(parts, pairs, "B", "Alignment fraction · assembly → reference", "AF (%)", 801, 210,
          "af_forward", (0, 100), [0, 25, 50, 75, 100], ["0", "25", "50", "75", "100"], multiplier=100)
    panel(parts, pairs, "C", "Number of contigs", "Contigs", 67, 663,
          "contigs", (100, 100000), [100, 1000, 10000, 100000], ["100", "1k", "10k", "100k"], log=True)
    panel(parts, pairs, "D", "Assembly N50", "N50 (kb)", 801, 663,
          "n50_bp", (.5, 500), [.5, 1, 10, 100, 500], ["0.5", "1", "10", "100", "500"], log=True, multiplier=.001)
    parts.append('</g></svg>')
    return "\n".join(parts) + "\n"


def main():
    pairs = load_pairs()
    stem = OUT / "assembly_comparison_4panel"
    paths = [stem.with_suffix(suffix) for suffix in (".svg", ".pdf", ".png")]
    for path in paths:
        if path.exists():
            raise FileExistsError(f"Refusing to replace existing output: {path}")
    svg, pdf, png = paths
    with svg.open("x", encoding="utf-8") as handle:
        handle.write(make_svg(pairs))
    subprocess.run(["rsvg-convert", "-f", "pdf", "-o", str(pdf), str(svg)], check=True)
    subprocess.run(["rsvg-convert", "-f", "png", "-d", "600", "-p", "600", "-o", str(png), str(svg)], check=True)
    print(f"Validated 6 pairs from {SOURCE.relative_to(ROOT)}")
    for path in paths:
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
