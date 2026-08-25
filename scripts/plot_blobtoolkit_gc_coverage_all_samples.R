#!/usr/bin/env Rscript

# Generate per-sample and faceted GC x coverage plots from the validated
# BlobToolKit master contig table without modifying upstream results.

args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args_all[grepl(file_arg, args_all)])
if (length(script_path) == 0) {
  script_path <- "scripts/plot_blobtoolkit_gc_coverage_all_samples.R"
}

script_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
project_dir <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)

input_tsv <- Sys.getenv(
  "MASTER_CONTIG_TABLE",
  file.path(
    project_dir,
    "ambiguous_isolate_resolution",
    "blobtoolkit",
    "metrics",
    "all_samples.master_contig_table.tsv"
  )
)
blobtoolkit_dir <- file.path(project_dir, "ambiguous_isolate_resolution", "blobtoolkit")
overview_figures_dir <- file.path(blobtoolkit_dir, "metrics", "figures")

required_packages <- c("ggplot2", "scales")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop("Missing required R package(s): ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

if (!file.exists(input_tsv) || file.info(input_tsv)$size == 0) {
  stop("Missing or empty master contig table: ", input_tsv, call. = FALSE)
}

taxon_levels <- c("Vibrio", "Bacillus", "Reyranella", "Other classified", "Unclassified")
taxon_palette <- c(
  "Vibrio" = "#0072B2",
  "Bacillus" = "#D55E00",
  "Reyranella" = "#009E73",
  "Other classified" = "#7A7A7A",
  "Unclassified" = "#B7B7B7"
)

needed_columns <- c("short_id", "gc_percent", "coverage", "length_bp", "broad_taxon")

table_header <- names(utils::read.delim(
  input_tsv,
  sep = "\t",
  header = TRUE,
  nrows = 0,
  check.names = FALSE
))

missing_columns <- setdiff(needed_columns, table_header)
if (length(missing_columns) > 0) {
  stop("Master table is missing required column(s): ", paste(missing_columns, collapse = ", "), call. = FALSE)
}

col_classes <- rep("NULL", length(table_header))
names(col_classes) <- table_header
col_classes[c("short_id", "broad_taxon")] <- "character"
col_classes[c("gc_percent", "coverage", "length_bp")] <- "numeric"

plot_data <- utils::read.delim(
  input_tsv,
  sep = "\t",
  header = TRUE,
  quote = "",
  comment.char = "",
  check.names = FALSE,
  colClasses = col_classes,
  stringsAsFactors = FALSE
)

bad_rows <- !stats::complete.cases(plot_data[, needed_columns])
if (any(bad_rows)) {
  stop("Required plotting columns contain NA in ", sum(bad_rows), " row(s).", call. = FALSE)
}

if (any(plot_data$coverage < 0)) {
  stop("Coverage contains negative value(s), which cannot be plotted on a log10 scale.", call. = FALSE)
}

unexpected_taxa <- setdiff(unique(plot_data$broad_taxon), taxon_levels)
if (length(unexpected_taxa) > 0) {
  stop("Unexpected broad_taxon value(s): ", paste(unexpected_taxa, collapse = ", "), call. = FALSE)
}

sample_ids <- sort(unique(plot_data$short_id))
if (length(sample_ids) != 6) {
  stop("Expected exactly six samples; found ", length(sample_ids), ": ", paste(sample_ids, collapse = ", "), call. = FALSE)
}

missing_sample_dirs <- file.path(blobtoolkit_dir, sample_ids)[!dir.exists(file.path(blobtoolkit_dir, sample_ids))]
if (length(missing_sample_dirs) > 0) {
  stop("Missing sample BlobToolKit directorie(s): ", paste(missing_sample_dirs, collapse = ", "), call. = FALSE)
}

plot_data$short_id <- factor(plot_data$short_id, levels = sample_ids)
plot_data$broad_taxon <- factor(plot_data$broad_taxon, levels = taxon_levels)

gc_limits <- range(plot_data$gc_percent)
length_limits <- range(plot_data$length_bp)

make_gc_coverage_plot <- function(data, sample_label = NULL, log10_y = FALSE, facet = FALSE) {
  plot_title <- if (facet) {
    "Six-sample contig GC content and log10-scaled coverage"
  } else if (log10_y) {
    paste0(sample_label, " contigs by GC content and log10-scaled coverage")
  } else {
    paste0(sample_label, " contigs by GC content and coverage")
  }

  p <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = gc_percent, y = coverage, color = broad_taxon, size = length_bp)
  ) +
    ggplot2::geom_point(alpha = 0.45, stroke = 0) +
    ggplot2::scale_x_continuous(limits = gc_limits) +
    ggplot2::scale_color_manual(values = taxon_palette, breaks = taxon_levels, drop = FALSE) +
    ggplot2::scale_size_continuous(
      range = c(0.2, 5),
      trans = "sqrt",
      limits = length_limits,
      labels = scales::comma
    ) +
    ggplot2::labs(
      title = plot_title,
      x = "GC content (%)",
      y = if (log10_y) "Coverage (log10 scale)" else "Coverage",
      color = "Broad taxon",
      size = "Contig length (bp)"
    ) +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "right",
      plot.title = ggplot2::element_text(face = "bold")
    )

  if (log10_y) {
    p <- p +
      ggplot2::scale_y_log10(labels = scales::comma) +
      ggplot2::annotation_logticks(sides = "l", outside = FALSE)
  }

  if (facet) {
    p <- p +
      ggplot2::facet_wrap(ggplot2::vars(short_id), ncol = 3) +
      ggplot2::theme(strip.text = ggplot2::element_text(face = "bold"))
  }

  p
}

save_plot_pair <- function(plot, png_path, pdf_path, width, height) {
  ggplot2::ggsave(png_path, plot, width = width, height = height, dpi = 300, bg = "white")
  ggplot2::ggsave(pdf_path, plot, width = width, height = height, bg = "white")
  c(png_path, pdf_path)
}

summary_rows <- list()
for (sample_id in sample_ids) {
  sample_data <- plot_data[plot_data$short_id == sample_id, , drop = FALSE]
  log_data <- sample_data[sample_data$coverage > 0, , drop = FALSE]
  figures_dir <- file.path(blobtoolkit_dir, sample_id, "figures")
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

  linear_plot <- make_gc_coverage_plot(sample_data, sample_label = sample_id, log10_y = FALSE)
  log_plot <- make_gc_coverage_plot(log_data, sample_label = sample_id, log10_y = TRUE)

  linear_png <- file.path(figures_dir, paste0(sample_id, "_master_gc_coverage_linear.png"))
  linear_pdf <- file.path(figures_dir, paste0(sample_id, "_master_gc_coverage_linear.pdf"))
  log_png <- file.path(figures_dir, paste0(sample_id, "_master_gc_coverage_log10.png"))
  log_pdf <- file.path(figures_dir, paste0(sample_id, "_master_gc_coverage_log10.pdf"))

  generated_paths <- c(
    save_plot_pair(linear_plot, linear_png, linear_pdf, width = 8.5, height = 6),
    save_plot_pair(log_plot, log_png, log_pdf, width = 8.5, height = 6)
  )

  summary_rows[[sample_id]] <- data.frame(
    short_id = sample_id,
    total_contigs = nrow(sample_data),
    positive_coverage_contigs = nrow(log_data),
    zero_coverage_contigs_omitted_from_log = sum(sample_data$coverage == 0),
    figure_paths = paste(generated_paths, collapse = "; "),
    stringsAsFactors = FALSE
  )
}

dir.create(overview_figures_dir, recursive = TRUE, showWarnings = FALSE)
facet_data <- plot_data[plot_data$coverage > 0, , drop = FALSE]
facet_plot <- make_gc_coverage_plot(facet_data, log10_y = TRUE, facet = TRUE)
facet_png <- file.path(overview_figures_dir, "all_samples_gc_coverage_log10_faceted.png")
facet_pdf <- file.path(overview_figures_dir, "all_samples_gc_coverage_log10_faceted.pdf")
facet_paths <- save_plot_pair(facet_plot, facet_png, facet_pdf, width = 12, height = 8)

plot_summary <- do.call(rbind, summary_rows)

cat("GC x coverage plotting summary\n")
for (i in seq_len(nrow(plot_summary))) {
  cat(
    plot_summary$short_id[i], ": ",
    "total_contigs=", plot_summary$total_contigs[i], "; ",
    "positive_coverage_contigs=", plot_summary$positive_coverage_contigs[i], "; ",
    "zero_coverage_contigs_omitted_from_log=", plot_summary$zero_coverage_contigs_omitted_from_log[i], "\n",
    "  figures: ", plot_summary$figure_paths[i], "\n",
    sep = ""
  )
}
cat("Faceted log10 overview figures: ", paste(facet_paths, collapse = "; "), "\n", sep = "")
