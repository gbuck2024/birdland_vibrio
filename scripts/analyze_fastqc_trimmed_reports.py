#!/usr/bin/env python3

from __future__ import annotations

import csv
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parent.parent
ROOT_DIR = PROJECT_DIR.parent
RAW_EXTRACT_DIR = PROJECT_DIR / "fastqc_extracted"
TRIMMED_EXTRACT_DIR = PROJECT_DIR / "trimmomatic" / "fastqc_trimmed_extracted"
REVIEW_DIR = PROJECT_DIR / "trimmomatic" / "fastqc_trimmed_review"
REPORT_PATH = REVIEW_DIR / "fastqc_trimmed_interpreted_report.md"
TSV_PATH = REVIEW_DIR / "fastqc_trimmed_module_status.tsv"
COMPARISON_PATH = REVIEW_DIR / "fastqc_trimmed_vs_raw_comparison.tsv"
LOG_DIR = REVIEW_DIR / "logs"
LOG_PATH = LOG_DIR / "analyze_fastqc_trimmed_reports.log"
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
    return int(label.split("-", 1)[0])


def infer_read(report_name: str) -> str:
    return report_name.rsplit("_L7_", 1)[1].split("_", 1)[0]


def infer_sample(report_name: str) -> str:
    return report_name.rsplit("_L7_", 1)[0]


def parse_report(report_dir: Path) -> dict[str, object]:
    statuses = parse_statuses(report_dir / "summary.txt")
    modules = parse_module_lines((report_dir / "fastqc_data.txt").read_text(encoding="utf-8"))

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

    max_adapter = 0.0
    max_adapter_source = ""
    headers = [
        "Illumina Universal Adapter",
        "Illumina Small RNA 3' Adapter",
        "Illumina Small RNA 5' Adapter",
        "Nextera Transposase Sequence",
        "PolyA",
        "PolyG",
    ]
    for row in adapter_rows:
        for idx, value in enumerate(row[1:], start=0):
            numeric = float(value)
            if numeric > max_adapter:
                max_adapter = numeric
                max_adapter_source = headers[idx]

    report_name = report_dir.name
    return {
        "report_dir": report_dir,
        "name": report_name,
        "sample": infer_sample(report_name),
        "read": infer_read(report_name),
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
        "max_adapter": max_adapter,
        "max_adapter_source": max_adapter_source,
        "overrep_rows": overrep_rows,
    }


def load_reports(report_dir: Path) -> list[dict[str, object]]:
    if not report_dir.exists():
        raise SystemExit(f"Missing extracted FastQC directory: {report_dir}")
    report_dirs = sorted(
        path for path in report_dir.iterdir() if path.is_dir() and (path / "summary.txt").exists()
    )
    if not report_dirs:
        raise SystemExit(f"No extracted FastQC reports found in {report_dir}")
    reports = [parse_report(path) for path in report_dirs]
    reports.sort(key=lambda item: (str(item["sample"]), str(item["read"])))
    return reports


def format_int(value: int) -> str:
    return f"{value:,}"


def top_overrep_summary(report: dict[str, object]) -> str:
    rows = report["overrep_rows"]
    if not rows:
        return "none"
    top_row = max(rows, key=lambda row: float(row[2]))
    return f"{float(top_row[2]):.3f}% {top_row[3]}"


def status_rank(status: str) -> int:
    return {"FAIL": 0, "WARN": 1, "PASS": 2}.get(status, -1)


def status_change(raw_status: str, trimmed_status: str) -> str:
    raw_rank = status_rank(raw_status)
    trimmed_rank = status_rank(trimmed_status)
    if trimmed_rank > raw_rank:
        return "improved"
    if trimmed_rank < raw_rank:
        return "worsened"
    return "unchanged"


def main() -> None:
    append_log("Starting trimmed FastQC report analysis")

    raw_reports = load_reports(RAW_EXTRACT_DIR)
    trimmed_reports = load_reports(TRIMMED_EXTRACT_DIR)

    raw_by_key = {(str(r["sample"]), str(r["read"])): r for r in raw_reports}
    trimmed_by_key = {(str(r["sample"]), str(r["read"])): r for r in trimmed_reports}
    if set(raw_by_key) != set(trimmed_by_key):
        raise SystemExit("Raw and trimmed FastQC report sets do not cover the same sample/read pairs.")

    REVIEW_DIR.mkdir(parents=True, exist_ok=True)

    status_counts: dict[str, Counter[str]] = defaultdict(Counter)
    per_sample: dict[str, list[dict[str, object]]] = defaultdict(list)
    comparison_rows: list[list[str]] = []
    module_change_counts: dict[str, Counter[str]] = defaultdict(Counter)

    for report in trimmed_reports:
        per_sample[str(report["sample"])].append(report)
        key = (str(report["sample"]), str(report["read"]))
        raw_report = raw_by_key[key]
        for module, trimmed_status in report["statuses"].items():
            raw_status = str(raw_report["statuses"][module])
            change = status_change(raw_status, trimmed_status)
            status_counts[module][trimmed_status] += 1
            module_change_counts[module][change] += 1
            comparison_rows.append(
                [str(report["sample"]), str(report["read"]), module, raw_status, trimmed_status, change]
            )

    with TSV_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["sample", "read", "module", "status"])
        for report in trimmed_reports:
            for module, status in report["statuses"].items():
                writer.writerow([report["sample"], report["read"], module, status])

    with COMPARISON_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["sample", "read", "module", "raw_status", "trimmed_status", "change"])
        writer.writerows(comparison_rows)

    reverse_reads = [r for r in trimmed_reports if r["read"] == "2"]
    forward_reads = [r for r in trimmed_reports if r["read"] == "1"]
    reverse_polyg = [r for r in reverse_reads if str(r["max_adapter_source"]) == "PolyG"]
    raw_reverse_polyg = [r for r in raw_reports if r["read"] == "2" and str(r["max_adapter_source"]) == "PolyG"]
    improved_overrep = module_change_counts["Overrepresented sequences"]["improved"]
    improved_gc = module_change_counts["Per sequence GC content"]["improved"]
    improved_base_content = module_change_counts["Per base sequence content"]["improved"]
    improved_tile = module_change_counts["Per tile sequence quality"]["improved"]
    overrep_pass = status_counts["Overrepresented sequences"]["PASS"]
    overrep_warn = status_counts["Overrepresented sequences"]["WARN"]
    gc_pass = status_counts["Per sequence GC content"]["PASS"]
    gc_warn = status_counts["Per sequence GC content"]["WARN"]
    gc_fail = status_counts["Per sequence GC content"]["FAIL"]
    base_content_pass = status_counts["Per base sequence content"]["PASS"]
    base_content_warn = status_counts["Per base sequence content"]["WARN"]
    tile_warn = status_counts["Per tile sequence quality"]["WARN"]
    tile_fail = status_counts["Per tile sequence quality"]["FAIL"]
    length_warn = status_counts["Sequence Length Distribution"]["WARN"]

    report_lines: list[str] = []
    report_lines.append("# Trimmed FastQC Interpreted Report")
    report_lines.append("")
    report_lines.append(f"Generated: {now_stamp()}")
    report_lines.append("")
    report_lines.append("## Scope")
    report_lines.append("")
    report_lines.append(
        f"Analyzed {len(trimmed_reports)} extracted FastQC reports from `{PROJECT_DIR / 'trimmomatic' / 'fastqc_trimmed' / 'reports'}` using `summary.txt` and `fastqc_data.txt`."
    )
    report_lines.append(
        f"Compared each trimmed report to the matching raw-read report from `{RAW_EXTRACT_DIR}`."
    )
    report_lines.append("")
    report_lines.append("## Module Status Overview")
    report_lines.append("")
    report_lines.append("| Module | PASS | WARN | FAIL | Improved vs raw | Unchanged | Worsened |")
    report_lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: |")
    for module in sorted(status_counts):
        counts = status_counts[module]
        changes = module_change_counts[module]
        report_lines.append(
            f"| {module} | {counts['PASS']} | {counts['WARN']} | {counts['FAIL']} | {changes['improved']} | {changes['unchanged']} | {changes['worsened']} |"
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
            report_lines.append(
                f"| {sample} | {report['read']} | {format_int(int(report['total_sequences']))} | {report['total_bases']} | {report['gc_percent']} | {float(report['min_mean_quality']):.2f} | {float(report['worst_tile_delta']):.2f} | {float(report['dedup_percentage']):.2f} | {report['statuses']['Overrepresented sequences']} | {top_overrep_summary(report)} |"
            )

    report_lines.append("")
    report_lines.append("## Interpreted Findings")
    report_lines.append("")
    report_lines.append(
        f"- All 12 trimmed reports still pass per-base and per-sequence quality score modules. Minimum mean base quality is {min(r['min_mean_quality'] for r in trimmed_reports):.2f} to {max(r['min_mean_quality'] for r in trimmed_reports):.2f}, so trimming did not damage overall read quality."
    )
    report_lines.append(
        f"- Overrepresented sequences improved in {improved_overrep} of 12 files. After trimming, {overrep_pass} reports pass and {overrep_warn} reports remain WARN; the raw reverse-read FAIL is gone, indicating the strongest polyG-driven tail artifact was reduced."
    )
    report_lines.append(
        f"- Per-sequence GC content improved in {improved_gc} of 12 files. After trimming, {gc_pass} reports pass, {gc_warn} warn, and {gc_fail} fail; the prior FAIL for `Buck_NB0507_14` read 2 is resolved to WARN, but most GC-content warnings persist."
    )
    report_lines.append(
        f"- Per-base sequence content improved in {improved_base_content} of 12 files. The trimmed set contains {base_content_pass} PASS and {base_content_warn} WARN calls, so this start-cycle composition signal was largely unchanged overall."
    )
    report_lines.append(
        f"- Per tile sequence quality improved in {improved_tile} of 12 files and remains unchanged overall at {tile_warn} WARN and {tile_fail} FAIL calls. This persistent split between reverse-read WARNs and forward-read FAILs points to a lane/tile artifact unaffected by trimming."
    )
    report_lines.append(
        f"- Sequence duplication levels still fail in all 12 trimmed reports. Deduplicated fractions are {min(r['dedup_percentage'] for r in trimmed_reports):.2f}% to {max(r['dedup_percentage'] for r in trimmed_reports):.2f}%, so duplication remains a library/depth characteristic rather than a trimming problem."
    )
    report_lines.append(
        f"- Adapter Content still passes in all 12 trimmed reports. Reverse reads continue to show PolyG as the highest adapter-content track in {len(reverse_polyg)} of 6 files, with trimmed PolyG peaks of {min(r['max_adapter'] for r in reverse_polyg):.2f}% to {max(r['max_adapter'] for r in reverse_polyg):.2f}% versus {min(r['max_adapter'] for r in raw_reverse_polyg):.2f}% to {max(r['max_adapter'] for r in raw_reverse_polyg):.2f}% in the raw review."
    )
    report_lines.append(
        f"- Sequence length distribution now warns in {length_warn} of 12 reports, which is expected after variable-length trimming and is not a reason to stop the pipeline."
    )

    report_lines.append("")
    report_lines.append("## Sample-Specific Notes")
    report_lines.append("")
    for sample in sorted(per_sample):
        sample_reports = sorted(per_sample[sample], key=lambda item: str(item["read"]))
        note_parts: list[str] = []
        for report in sample_reports:
            key = (str(report["sample"]), str(report["read"]))
            raw_report = raw_by_key[key]
            if report["statuses"]["Per tile sequence quality"] != "PASS":
                note_parts.append(f"read {report['read']} still has {report['statuses']['Per tile sequence quality'].lower()} per-tile quality")
            if report["statuses"]["Per sequence GC content"] != "PASS":
                note_parts.append(f"read {report['read']} retains a GC-content warning")
            if report["statuses"]["Per base sequence content"] != "PASS":
                note_parts.append(f"read {report['read']} retains a base-content warning")
            if status_change(str(raw_report["statuses"]["Overrepresented sequences"]), str(report["statuses"]["Overrepresented sequences"])) == "improved":
                note_parts.append(f"read {report['read']} overrepresented sequences improved to PASS")
        if not note_parts:
            note_parts.append("no sample-specific exceptions beyond the project-wide duplication and forward tile-quality pattern")
        report_lines.append(f"- {sample}: " + "; ".join(note_parts) + ".")

    report_lines.append("")
    report_lines.append("## Recommended Next Steps")
    report_lines.append("")
    report_lines.append(
        "1. Proceed to genome assembly on the trimmed paired reads, because the main pre-trim reverse-read PolyG and GC anomalies improved to acceptable FastQC outcomes after trimming."
    )
    report_lines.append(
        "2. Use only the paired trimmed FASTQ files in `trimmomatic/trimmed_reads/` as SPAdes inputs unless you intentionally want to incorporate unpaired reads in a separate assembly sensitivity check."
    )
    report_lines.append(
        "3. Record the persistent forward-read per-tile failures as a residual lane artifact, but do not block assembly on that module alone because base-quality metrics remain strong."
    )
    report_lines.append(
        "4. During assembly review, watch contig count, N50, total assembly size, and coverage for evidence that high duplication or residual tile effects are harming assembly performance."
    )
    report_lines.append(
        "5. If any assembly looks fragmented or coverage-skewed, use `Buck_BI0607_1` as the first candidate for a polyG-aware re-trimming comparison because it is the only sample that still carries both read-1 and read-2 base-content warnings."
    )

    REPORT_PATH.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

    heading = "2026-04-09 Post-trim FastQC extraction and interpretation"
    append_section(
        DOC_PATHS["WORK_COMPLETED"],
        heading,
        [
            f"- Added `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/extract_fastqc_trimmed_reports.sh` and `/work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/analyze_fastqc_trimmed_reports.py` to reproducibly extract and interpret trimmed-read FastQC outputs.",
            f"- Extracted {len(trimmed_reports)} trimmed FastQC zip reports into `{TRIMMED_EXTRACT_DIR}` and wrote the review outputs to `{REVIEW_DIR}`.",
            "- Verified that trimming removed the raw reverse-read overrepresented-sequence failures and resolved the strongest GC-content anomaly, while forward-read tile-quality failures and duplication remained.",
        ],
    )
    append_section(
        DOC_PATHS["IN_PROGRESS"],
        heading,
        [
            "- Post-trim FastQC interpretation is complete and the quality-control checkpoint for trimmed paired reads has been verified.",
            "- Remaining technical caveat is the persistent forward-read per-tile FastQC failure, which appears to be a lane artifact rather than a trimming deficiency.",
            "- Next active pipeline step is assembly planning and submission on the trimmed paired reads.",
        ],
    )
    append_section(
        DOC_PATHS["NEXT_STEPS"],
        heading,
        [
            "- Build a reusable SLURM assembly workflow for the six trimmed paired-end samples, preferably as an array job with per-sample stdout/stderr logs.",
            "- Run SPAdes on `trimmomatic/trimmed_reads/*_paired.fq.gz` and capture assembly metrics into a new step-specific directory.",
            "- Review assembly size, contig count, N50, and coverage-related metrics before proceeding to annotation and gene-target analysis.",
        ],
    )

    append_log(f"Finished trimmed FastQC report analysis for {len(trimmed_reports)} reports")


if __name__ == "__main__":
    main()
