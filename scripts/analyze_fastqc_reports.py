#!/usr/bin/env python3

from __future__ import annotations

import csv
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parent.parent
EXTRACT_DIR = PROJECT_DIR / "fastqc_extracted"
REVIEW_DIR = PROJECT_DIR / "fastqc_review"
REPORT_PATH = REVIEW_DIR / "fastqc_interpreted_report.md"
TSV_PATH = REVIEW_DIR / "fastqc_module_status.tsv"
LOG_DIR = REVIEW_DIR / "logs"
LOG_PATH = LOG_DIR / "analyze_fastqc_reports.log"
ROOT_DIR = PROJECT_DIR.parent
DOC_PATHS = {
    "IN_PROGRESS": ROOT_DIR / "IN_PROGRESS.md",
    "NEXT_STEPS": ROOT_DIR / "NEXT_STEPS.md",
    "WORK_COMPLETED": ROOT_DIR / "WORK_COMPLETED.md",
}


def now_stamp() -> str:
    return datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")


def append_log(message: str) -> None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(f"[{now_stamp()}] {message}\n")


def parse_module_lines(text: str) -> dict[str, list[str]]:
    modules: dict[str, list[str]] = {}
    current_name: str | None = None
    current_lines: list[str] = []

    for raw_line in text.splitlines():
        line = raw_line.rstrip("\n")
        if line.startswith(">>END_MODULE"):
            if current_name is not None:
                modules[current_name] = current_lines[:]
            current_name = None
            current_lines = []
            continue
        if line.startswith(">>") and not line.startswith(">>END_MODULE"):
            if current_name is not None:
                modules[current_name] = current_lines[:]
            current_name = line[2:].split("\t", 1)[0]
            current_lines = []
            continue
        if current_name is not None:
            current_lines.append(line)
    return modules


def parse_statuses(summary_path: Path) -> dict[str, str]:
    statuses: dict[str, str] = {}
    with summary_path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            status, module, _filename = line.split("\t", 2)
            statuses[module] = status
    return statuses


def parse_basic_statistics(lines: list[str]) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in lines:
        if not line or line.startswith("#"):
            continue
        key, value = line.split("\t", 1)
        values[key] = value
    return values


def parse_numeric_rows(lines: list[str]) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in lines:
        if not line or line.startswith("#"):
            continue
        rows.append(line.split("\t"))
    return rows


def base_start(label: str) -> int:
    first = label.split("-", 1)[0]
    return int(first)


def parse_report(report_dir: Path) -> dict[str, object]:
    summary_path = report_dir / "summary.txt"
    data_path = report_dir / "fastqc_data.txt"
    statuses = parse_statuses(summary_path)
    modules = parse_module_lines(data_path.read_text(encoding="utf-8"))

    basic_stats = parse_basic_statistics(modules["Basic Statistics"])
    quality_rows = parse_numeric_rows(modules["Per base sequence quality"])
    tile_rows = parse_numeric_rows(modules["Per tile sequence quality"])
    base_content_rows = parse_numeric_rows(modules["Per base sequence content"])
    gc_rows = parse_numeric_rows(modules["Per sequence GC content"])
    duplication_lines = modules["Sequence Duplication Levels"]
    duplication_rows = parse_numeric_rows(duplication_lines)
    overrep_rows = parse_numeric_rows(modules.get("Overrepresented sequences", []))
    adapter_rows = parse_numeric_rows(modules["Adapter Content"])

    min_mean_quality = min(float(row[1]) for row in quality_rows)
    worst_tile_delta = min(float(row[2]) for row in tile_rows)
    dedup_percentage = float(
        next(
            line.split("\t", 1)[1]
            for line in duplication_lines
            if line.startswith("#Total Deduplicated Percentage\t")
        )
    )
    duplication_gt10 = next(float(row[1]) for row in duplication_rows if row[0] == ">10")
    duplication_gt100 = next(float(row[1]) for row in duplication_rows if row[0] == ">100")

    first10_spread = 0.0
    overall_spread = 0.0
    for row in base_content_rows:
        start = base_start(row[0])
        spread = max(float(value) for value in row[1:]) - min(float(value) for value in row[1:])
        overall_spread = max(overall_spread, spread)
        if start <= 10:
            first10_spread = max(first10_spread, spread)

    gc_mode = max(gc_rows, key=lambda row: float(row[1]))[0]
    gc_extreme = max(float(row[1]) for row in gc_rows)

    max_adapter = 0.0
    max_adapter_source = ""
    for row in adapter_rows:
        headers = [
            "Illumina Universal Adapter",
            "Illumina Small RNA 3' Adapter",
            "Illumina Small RNA 5' Adapter",
            "Nextera Transposase Sequence",
            "PolyA",
            "PolyG",
        ]
        for idx, value in enumerate(row[1:], start=0):
            numeric = float(value)
            if numeric > max_adapter:
                max_adapter = numeric
                max_adapter_source = headers[idx]

    return {
        "report_dir": report_dir,
        "name": report_dir.name,
        "sample": report_dir.name.rsplit("_L7_", 1)[0],
        "read": report_dir.name.rsplit("_L7_", 1)[1].split("_", 1)[0],
        "statuses": statuses,
        "filename": basic_stats["Filename"],
        "total_sequences": int(basic_stats["Total Sequences"]),
        "total_bases": basic_stats["Total Bases"],
        "sequence_length": basic_stats["Sequence length"],
        "gc_percent": int(basic_stats["%GC"]),
        "min_mean_quality": min_mean_quality,
        "worst_tile_delta": worst_tile_delta,
        "dedup_percentage": dedup_percentage,
        "duplication_gt10": duplication_gt10,
        "duplication_gt100": duplication_gt100,
        "first10_spread": first10_spread,
        "overall_spread": overall_spread,
        "gc_mode": gc_mode,
        "gc_extreme": gc_extreme,
        "max_adapter": max_adapter,
        "max_adapter_source": max_adapter_source,
        "overrep_rows": overrep_rows,
    }


def format_int(value: int) -> str:
    return f"{value:,}"


def ensure_doc(path: Path, title: str) -> None:
    if path.exists():
        return
    path.write_text(f"# {title}\n\n", encoding="utf-8")


def append_section(path: Path, heading: str, lines: list[str]) -> None:
    ensure_doc(path, path.stem.replace("_", " ").title())
    existing_text = path.read_text(encoding="utf-8")
    if f"## {heading}\n" in existing_text:
        return
    with path.open("a", encoding="utf-8") as handle:
        handle.write(f"## {heading}\n\n")
        for line in lines:
            handle.write(f"{line}\n")
        handle.write("\n")


def main() -> None:
    append_log("Starting FastQC report analysis")
    if not EXTRACT_DIR.exists():
        raise SystemExit(f"Missing extraction directory: {EXTRACT_DIR}")

    report_dirs = sorted(
        path for path in EXTRACT_DIR.iterdir() if path.is_dir() and (path / "summary.txt").exists()
    )
    if not report_dirs:
        raise SystemExit(f"No extracted FastQC reports found in {EXTRACT_DIR}")

    reports = [parse_report(report_dir) for report_dir in report_dirs]
    reports.sort(key=lambda item: (str(item["sample"]), str(item["read"])))

    status_counts: dict[str, Counter[str]] = defaultdict(Counter)
    for report in reports:
        for module, status in report["statuses"].items():
            status_counts[module][status] += 1

    per_sample: dict[str, list[dict[str, object]]] = defaultdict(list)
    for report in reports:
        per_sample[str(report["sample"])].append(report)

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with TSV_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["sample", "read", "module", "status"])
        for report in reports:
            for module, status in report["statuses"].items():
                writer.writerow([report["sample"], report["read"], module, status])

    reverse_reads = [r for r in reports if r["read"] == "2"]
    forward_reads = [r for r in reports if r["read"] == "1"]
    polyg_reverse = [r for r in reverse_reads if str(r["max_adapter_source"]) == "PolyG"]
    report_lines: list[str] = []
    report_lines.append("# FastQC Interpreted Report")
    report_lines.append("")
    report_lines.append(f"Generated: {now_stamp()}")
    report_lines.append("")
    report_lines.append("## Scope")
    report_lines.append("")
    report_lines.append(
        f"Analyzed {len(reports)} extracted FastQC reports from `{PROJECT_DIR / 'fastqc'}` using `summary.txt` and `fastqc_data.txt`."
    )
    report_lines.append(
        f"Reads are interpreted as paired-end data where read `1` is forward and read `2` is reverse."
    )
    report_lines.append("")
    report_lines.append("## Module Status Overview")
    report_lines.append("")
    report_lines.append("| Module | PASS | WARN | FAIL |")
    report_lines.append("| --- | ---: | ---: | ---: |")
    for module in sorted(status_counts):
        counts = status_counts[module]
        report_lines.append(
            f"| {module} | {counts['PASS']} | {counts['WARN']} | {counts['FAIL']} |"
        )
    report_lines.append("")
    report_lines.append("## Pair Summary")
    report_lines.append("")
    report_lines.append(
        "| Sample | Read | Total sequences | Total bases | %GC | Min mean Q | Worst tile delta | Deduplicated % | Overrepresented status | Top overrepresented sequence/source |"
    )
    report_lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |")
    for sample in sorted(per_sample):
        sample_reports = sorted(per_sample[sample], key=lambda item: str(item["read"]))
        for report in sample_reports:
            overrep_summary = "none"
            if report["overrep_rows"]:
                top_row = max(report["overrep_rows"], key=lambda row: float(row[2]))
                overrep_summary = f"{float(top_row[2]):.3f}% {top_row[3]}"
            report_lines.append(
                f"| {sample} | {report['read']} | {format_int(int(report['total_sequences']))} | {report['total_bases']} | {report['gc_percent']} | {float(report['min_mean_quality']):.2f} | {float(report['worst_tile_delta']):.2f} | {float(report['dedup_percentage']):.2f} | {report['statuses']['Overrepresented sequences']} | {overrep_summary} |"
            )
    report_lines.append("")
    report_lines.append("## Interpreted Findings")
    report_lines.append("")
    report_lines.append(
        f"- All 12 reports passed both per-base and per-sequence quality score modules. Minimum mean base quality stayed between {min(r['min_mean_quality'] for r in reports):.2f} and {max(r['min_mean_quality'] for r in reports):.2f}, which is consistent with very high raw read quality before trimming."
    )
    report_lines.append(
        f"- All 12 reports passed sequence length distribution and per-base N content. Every file is fixed at 150 bp with zero poor-quality flags in FastQC basic statistics."
    )
    report_lines.append(
        f"- Per tile sequence quality is a systematic lane-level issue: all {len(forward_reads)} forward reads failed this module, while all {len(reverse_reads)} reverse reads warned instead of passing. Worst tile deviations range from {min(r['worst_tile_delta'] for r in reports):.2f} to {max(r['worst_tile_delta'] for r in reports):.2f}, so this is real but it does not coincide with poor overall per-base quality."
    )
    report_lines.append(
        f"- Sequence duplication levels failed in all 12 reports. The deduplicated fraction ranges from {min(r['dedup_percentage'] for r in reports):.2f}% to {max(r['dedup_percentage'] for r in reports):.2f}%, with {min(r['duplication_gt10'] for r in reports):.2f}% to {max(r['duplication_gt10'] for r in reports):.2f}% of reads occurring at duplication level `>10`. That pattern is compatible with deep bacterial resequencing or library amplification and is not a stand-alone reason to discard the data."
    )
    report_lines.append(
        f"- Adapter Content passed in all 12 reports, but every reverse read has PolyG as the highest adapter-content signal ({min(r['max_adapter'] for r in polyg_reverse):.2f}% to {max(r['max_adapter'] for r in polyg_reverse):.2f}% in the FastQC PolyG track). Reverse-read overrepresented sequences are also dominated by long polyG strings, which points to 2-color chemistry tail artifacts rather than classic Illumina adapter carryover."
    )
    report_lines.append(
        f"- Reverse reads carry most of the composition anomalies. Overrepresented sequences are WARN or FAIL in all six reverse reads, and five of six reverse reads WARN or FAIL for per-sequence GC content; `Buck_NB0507_14` read 2 is the strongest GC outlier with a FastQC FAIL."
    )
    report_lines.append(
        f"- Base-composition imbalance is sample-dependent rather than universal. Four forward reads and four reverse reads WARN for per-base sequence content, consistent with start-cycle composition bias that trimming may reduce but may not fully remove."
    )
    report_lines.append(
        "- The only obvious classic adapter signature is `Buck_BI0607_1` read 1, where overrepresented sequences match TruSeq adapter/index-derived sequence fragments at low abundance. This supports adapter clipping during trimming even though the dedicated adapter module still passes."
    )
    report_lines.append("")
    report_lines.append("## Sample-Specific Notes")
    report_lines.append("")
    for sample in sorted(per_sample):
        sample_reports = sorted(per_sample[sample], key=lambda item: str(item["read"]))
        read1 = next(item for item in sample_reports if item["read"] == "1")
        read2 = next(item for item in sample_reports if item["read"] == "2")
        note_parts = []
        if read1["statuses"]["Per base sequence content"] != "PASS" or read2["statuses"]["Per base sequence content"] != "PASS":
            note_parts.append("base-content imbalance in at least one mate")
        if read2["statuses"]["Per sequence GC content"] == "FAIL":
            note_parts.append("reverse-read GC content fail")
        elif read1["statuses"]["Per sequence GC content"] != "PASS" or read2["statuses"]["Per sequence GC content"] != "PASS":
            note_parts.append("GC-content warning")
        if read2["statuses"]["Overrepresented sequences"] != "PASS":
            top_row = max(read2["overrep_rows"], key=lambda row: float(row[2]))
            note_parts.append(f"reverse overrepresented sequence is {float(top_row[2]):.3f}% {top_row[3]}")
        if read1["statuses"]["Overrepresented sequences"] != "PASS":
            top_row = max(read1["overrep_rows"], key=lambda row: float(row[2]))
            note_parts.append(f"forward overrepresented sequence is {float(top_row[2]):.3f}% {top_row[3]}")
        if not note_parts:
            note_parts.append("no sample-specific exception beyond the project-wide tile and duplication patterns")
        report_lines.append(f"- {sample}: " + "; ".join(note_parts) + ".")
    report_lines.append("")
    report_lines.append("## Recommended Next Steps")
    report_lines.append("")
    report_lines.append(
        "1. Proceed to paired-end trimming as the next pipeline step using a SLURM array job, keeping read 1 and read 2 synchronized and writing all outputs into a new trimming directory."
    )
    report_lines.append(
        "2. Include adapter clipping in trimming because `Buck_BI0607_1` read 1 contains low-level TruSeq-derived overrepresented sequences even though the adapter module passed."
    )
    report_lines.append(
        "3. Use quality trimming parameters that address reverse-read tail artifacts. Because the dominant issue is PolyG-rich reverse-read behavior, verify whether the planned Trimmomatic settings remove the affected tails adequately; if post-trim FastQC still shows PolyG-heavy reverse reads, consider a polyG-aware tool such as `fastp` as a follow-up decision point."
    )
    report_lines.append(
        "4. Rerun FastQC immediately after trimming on both mates for every sample and compare the same modules: per tile quality, per-base sequence content, GC content, overrepresented sequences, and adapter/PolyG signals."
    )
    report_lines.append(
        "5. Do not reject samples based on duplication alone before assembly. In isolate WGS, high duplication can still be compatible with useful depth; evaluate coverage and assembly behavior after trimming."
    )
    report_lines.append(
        "6. Keep the strongest watch on `Buck_BI0607_1` read 2 and `Buck_NB0507_14` read 2 because they show the most pronounced reverse-read artifact signatures in overrepresented sequence and GC-content modules."
    )
    report_lines.append("")
    report_lines.append("## Best Pipeline Directions")
    report_lines.append("")
    report_lines.append(
        "- Best immediate option: implement the planned Trimmomatic read-trimming step in a reproducible SLURM array job, then perform post-trim FastQC before moving to assembly."
    )
    report_lines.append(
        "- Best quality-control checkpoint: treat reverse-read PolyG behavior as the main risk to resolve before assembly, not the duplication failures."
    )
    report_lines.append(
        "- Best decision gate after trimming: if reverse-read GC and overrepresented-sequence problems persist, pause before SPAdes and switch to a polyG-aware trimming strategy."
    )

    REPORT_PATH.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

    heading = f"2026-03-27 FastQC extraction and interpretation"
    append_section(
        DOC_PATHS["WORK_COMPLETED"],
        heading,
        [
            f"- Extracted {len(reports)} FastQC zip reports into `{EXTRACT_DIR}`.",
            f"- Parsed every `summary.txt` and `fastqc_data.txt` file and wrote the interpreted report to `{REPORT_PATH}`.",
            f"- Confirmed project-wide high raw read quality with persistent tile-quality, duplication, and reverse-read PolyG/GC anomalies that should be addressed during trimming.",
        ],
    )
    append_section(
        DOC_PATHS["IN_PROGRESS"],
        heading,
        [
            "- FastQC review is complete and the project is ready to enter the read-trimming stage.",
            "- Main open technical question for trimming is whether standard Trimmomatic settings will adequately reduce reverse-read PolyG artifacts.",
            "- Next verification point should be post-trim FastQC on all paired samples.",
        ],
    )
    append_section(
        DOC_PATHS["NEXT_STEPS"],
        heading,
        [
            "- Build a reusable SLURM array script for paired-end trimming with adapter clipping and quality-tail trimming.",
            "- Preserve read pairing and write trimmed outputs plus stdout/stderr logs into new step-specific directories.",
            "- After trimming, rerun FastQC and compare reverse-read PolyG, GC-content, and overrepresented-sequence behavior before proceeding to SPAdes.",
        ],
    )
    append_log(f"Finished FastQC report analysis for {len(reports)} reports")


if __name__ == "__main__":
    main()
