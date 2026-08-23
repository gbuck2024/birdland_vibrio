#!/usr/bin/env Rscript

args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args_all[grepl(file_arg, args_all)])
if (length(script_path) == 0) {
  script_path <- "scripts/plot_bi0607_2_gc_coverage.R"
}

script_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
project_dir <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)

stage_dir <- Sys.getenv("STAGE_DIR", file.path("ambiguous_isolate_resolution", "blobtoolkit", "BI0607_2"))
stage_path <- if (grepl("^/", stage_dir)) stage_dir else file.path(project_dir, stage_dir)
blobdir <- file.path(stage_path, "blobdir")
taxonomy_dir <- file.path(stage_path, "taxonomy")
metrics_dir <- file.path(stage_path, "metrics")
figures_dir <- file.path(stage_path, "figures")
dir.create(metrics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

sample_id <- Sys.getenv("SAMPLE_ID", "Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7")
coverage_json <- Sys.getenv(
  "COVERAGE_JSON",
  file.path(blobdir, paste0(sample_id, ".self_contigs.sorted_cov.json"))
)
gc_json <- Sys.getenv("GC_JSON", file.path(blobdir, "gc.json"))
length_json <- Sys.getenv("LENGTH_JSON", file.path(blobdir, "length.json"))
ids_json <- Sys.getenv("IDENTIFIERS_JSON", file.path(blobdir, "identifiers.json"))
kraken_tsv <- Sys.getenv(
  "KRAKEN_TSV",
  file.path(taxonomy_dir, paste0(sample_id, ".spades_contigs.kraken2.tsv"))
)
prefix <- Sys.getenv("PLOT_PREFIX", "BI0607_2_gc_coverage")

required_packages <- c("jsonlite", "ggplot2", "scales")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop("Missing required R package(s): ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

required_files <- c(coverage_json, gc_json, length_json, ids_json, kraken_tsv)
missing_files <- required_files[!file.exists(required_files) | file.info(required_files)$size == 0]
if (length(missing_files) > 0) {
  stop("Missing or empty input file(s): ", paste(missing_files, collapse = ", "), call. = FALSE)
}

read_btk_values <- function(path) {
  parsed <- jsonlite::fromJSON(path)
  if (!"values" %in% names(parsed)) {
    stop("BlobToolKit JSON lacks a values array: ", path, call. = FALSE)
  }
  parsed$values
}

classify_taxon <- function(taxon_label, kraken_status) {
  label <- tolower(taxon_label)
  group <- rep("Other classified", length(label))
  group[kraken_status == "U" | grepl("unclassified|taxid 0", label)] <- "Unclassified"
  group[grepl("\\bvibrio\\b", label)] <- "Vibrio"
  group[grepl("\\bbacillus\\b", label)] <- "Bacillus"
  group[grepl("\\breyranella\\b", label)] <- "Reyranella"
  group
}

extract_taxid <- function(taxon_label) {
  sub("^.*\\(taxid ([0-9]+)\\).*$", "\\1", taxon_label)
}

ids <- read_btk_values(ids_json)
gc_fraction <- as.numeric(read_btk_values(gc_json))
coverage <- as.numeric(read_btk_values(coverage_json))
length_bp <- as.numeric(read_btk_values(length_json))

if (length(unique(c(length(ids), length(gc_fraction), length(coverage), length(length_bp)))) != 1) {
  stop("Identifier, GC, coverage, and length arrays do not have the same length.", call. = FALSE)
}

kraken <- read.delim(
  kraken_tsv,
  sep = "\t",
  header = FALSE,
  quote = "",
  comment.char = "",
  stringsAsFactors = FALSE,
  col.names = c("kraken_status", "contig_id", "taxon_label", "kraken_length", "lca_mapping")
)
if (nrow(kraken) != length(ids)) {
  stop("Kraken2 row count does not match BlobToolKit contig count.", call. = FALSE)
}

plot_data <- data.frame(
  contig_id = ids,
  gc_fraction = gc_fraction,
  gc_percent = gc_fraction * 100,
  coverage = coverage,
  coverage_log10 = log10(coverage + 1),
  length_bp = length_bp,
  stringsAsFactors = FALSE
)
kraken_match <- match(plot_data$contig_id, kraken$contig_id)
if (anyNA(kraken_match)) {
  stop("One or more BlobToolKit contig IDs are missing from the Kraken2 table.", call. = FALSE)
}
plot_data$kraken_status <- kraken$kraken_status[kraken_match]
plot_data$taxon_label <- kraken$taxon_label[kraken_match]
plot_data$kraken_length <- kraken$kraken_length[kraken_match]
plot_data$taxid <- extract_taxid(plot_data$taxon_label)
plot_data$broad_taxon <- classify_taxon(plot_data$taxon_label, plot_data$kraken_status)
plot_data$broad_taxon <- factor(
  plot_data$broad_taxon,
  levels = c("Vibrio", "Bacillus", "Reyranella", "Other classified", "Unclassified")
)

if (anyNA(plot_data$gc_percent) || anyNA(plot_data$coverage) || anyNA(plot_data$length_bp)) {
  stop("GC, coverage, or length values contain NA after parsing.", call. = FALSE)
}

coverage_positive <- plot_data$coverage[plot_data$coverage > 0]
coverage_quantiles <- quantile(
  plot_data$coverage,
  probs = c(0, 0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99, 1),
  names = TRUE
)
coverage_ratio <- max(coverage_positive) / max(min(coverage_positive), .Machine$double.eps)
q95_q05_ratio <- unname(coverage_quantiles["95%"] / max(coverage_quantiles["5%"], .Machine$double.eps))
recommend_log <- coverage_ratio >= 100 || q95_q05_ratio >= 10

contigs_by_taxon <- aggregate(contig_id ~ broad_taxon, data = plot_data, FUN = length)
total_bp_by_taxon <- aggregate(length_bp ~ broad_taxon, data = plot_data, FUN = sum)
median_length_by_taxon <- aggregate(length_bp ~ broad_taxon, data = plot_data, FUN = median)
median_coverage_by_taxon <- aggregate(coverage ~ broad_taxon, data = plot_data, FUN = median)
median_gc_by_taxon <- aggregate(gc_percent ~ broad_taxon, data = plot_data, FUN = median)
summary_by_taxon <- data.frame(
  broad_taxon = contigs_by_taxon$broad_taxon,
  contigs = contigs_by_taxon$contig_id,
  total_bp = total_bp_by_taxon$length_bp[match(contigs_by_taxon$broad_taxon, total_bp_by_taxon$broad_taxon)],
  median_length_bp = median_length_by_taxon$length_bp[match(contigs_by_taxon$broad_taxon, median_length_by_taxon$broad_taxon)],
  median_coverage = median_coverage_by_taxon$coverage[match(contigs_by_taxon$broad_taxon, median_coverage_by_taxon$broad_taxon)],
  median_gc_percent = median_gc_by_taxon$gc_percent[match(contigs_by_taxon$broad_taxon, median_gc_by_taxon$broad_taxon)]
)

plot_tsv <- file.path(metrics_dir, paste0(prefix, "_plot_data.tsv"))
summary_tsv <- file.path(metrics_dir, paste0(prefix, "_summary.tsv"))
taxon_summary_tsv <- file.path(metrics_dir, paste0(prefix, "_taxon_summary.tsv"))
plot_data_export <- plot_data[, c(
  "contig_id",
  "gc_fraction",
  "gc_percent",
  "coverage",
  "coverage_log10",
  "length_bp",
  "kraken_status",
  "taxon_label",
  "kraken_length",
  "taxid",
  "broad_taxon"
)]
write.table(plot_data_export, plot_tsv, sep = "\t", quote = FALSE, row.names = FALSE)

coverage_summary <- data.frame(
  metric = c(
    names(coverage_quantiles),
    "positive_coverage_max_min_ratio",
    "coverage_q95_q05_ratio",
    "recommend_log10_coverage_plot"
  ),
  value = c(
    as.numeric(coverage_quantiles),
    coverage_ratio,
    q95_q05_ratio,
    ifelse(recommend_log, "yes", "no")
  )
)
write.table(coverage_summary, summary_tsv, sep = "\t", quote = FALSE, row.names = FALSE)
write.table(summary_by_taxon, taxon_summary_tsv, sep = "\t", quote = FALSE, row.names = FALSE)

palette <- c(
  "Vibrio" = "#0072B2",
  "Bacillus" = "#D55E00",
  "Reyranella" = "#009E73",
  "Other classified" = "#7A7A7A",
  "Unclassified" = "#B7B7B7"
)

base_plot <- ggplot2::ggplot(
  plot_data,
  ggplot2::aes(x = gc_percent, y = coverage, color = broad_taxon, size = length_bp)
) +
  ggplot2::geom_point(alpha = 0.45, stroke = 0) +
  ggplot2::scale_color_manual(values = palette, drop = FALSE) +
  ggplot2::scale_size_continuous(range = c(0.2, 5), trans = "sqrt", labels = scales::comma) +
  ggplot2::labs(
    x = "GC content (%)",
    y = "Coverage",
    color = "Kraken2 group",
    size = "Contig length (bp)"
  ) +
  ggplot2::theme_bw(base_size = 11) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    legend.position = "right",
    plot.title = ggplot2::element_text(face = "bold")
  )

linear_plot <- base_plot +
  ggplot2::ggtitle("BI0607-2 contigs by GC content and coverage")

log_plot <- base_plot +
  ggplot2::scale_y_continuous(
    trans = scales::pseudo_log_trans(base = 10),
    breaks = c(0, 1, 10, 100, 1000, 10000, 100000),
    labels = scales::comma
  ) +
  ggplot2::ggtitle("BI0607-2 contigs by GC content and log-scaled coverage")

linear_png <- file.path(figures_dir, paste0(prefix, "_linear.png"))
linear_pdf <- file.path(figures_dir, paste0(prefix, "_linear.pdf"))
log_png <- file.path(figures_dir, paste0(prefix, "_log10.png"))
log_pdf <- file.path(figures_dir, paste0(prefix, "_log10.pdf"))

ggplot2::ggsave(linear_png, linear_plot, width = 8.5, height = 6, dpi = 300)
ggplot2::ggsave(linear_pdf, linear_plot, width = 8.5, height = 6)
ggplot2::ggsave(log_png, log_plot, width = 8.5, height = 6, dpi = 300)
ggplot2::ggsave(log_pdf, log_plot, width = 8.5, height = 6)

cat("Wrote plot data: ", plot_tsv, "\n", sep = "")
cat("Wrote summary: ", summary_tsv, "\n", sep = "")
cat("Wrote taxon summary: ", taxon_summary_tsv, "\n", sep = "")
cat("Wrote linear plots: ", linear_png, " and ", linear_pdf, "\n", sep = "")
cat("Wrote log-scaled plots: ", log_png, " and ", log_pdf, "\n", sep = "")
cat("Coverage max/min ratio among positive contigs: ", signif(coverage_ratio, 4), "\n", sep = "")
cat("Coverage 95th/5th percentile ratio: ", signif(q95_q05_ratio, 4), "\n", sep = "")
cat("Recommended primary view: ", ifelse(recommend_log, "log-scaled coverage", "linear coverage"), "\n", sep = "")
