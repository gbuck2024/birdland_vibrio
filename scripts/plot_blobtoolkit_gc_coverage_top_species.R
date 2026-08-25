#!/usr/bin/env Rscript

# Generate per-sample and faceted GC x coverage plots from the validated
# BlobToolKit master contig table, highlighting the top three Vibrio
# species-level Kraken2 contig hits, other Vibrio contigs, and the top three
# non-Vibrio classified contig hits in each sample.

args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args_all[grepl(file_arg, args_all)])
if (length(script_path) == 0) {
  script_path <- "scripts/plot_blobtoolkit_gc_coverage_top_species.R"
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
summary_tsv <- file.path(
  blobtoolkit_dir,
  "metrics",
  "top_species_gc_coverage_highlight_summary.tsv"
)

required_packages <- c("ggplot2", "scales")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop("Missing required R package(s): ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

if (!file.exists(input_tsv) || file.info(input_tsv)$size == 0) {
  stop("Missing or empty master contig table: ", input_tsv, call. = FALSE)
}

needed_columns <- c(
  "short_id",
  "gc_percent",
  "coverage",
  "length_bp",
  "taxon_label",
  "broad_taxon"
)

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
col_classes[c("short_id", "taxon_label", "broad_taxon")] <- "character"
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

sample_ids <- sort(unique(plot_data$short_id))
if (length(sample_ids) != 6) {
  stop("Expected exactly six samples; found ", length(sample_ids), ": ", paste(sample_ids, collapse = ", "), call. = FALSE)
}

missing_sample_dirs <- file.path(blobtoolkit_dir, sample_ids)[!dir.exists(file.path(blobtoolkit_dir, sample_ids))]
if (length(missing_sample_dirs) > 0) {
  stop("Missing sample BlobToolKit directorie(s): ", paste(missing_sample_dirs, collapse = ", "), call. = FALSE)
}

clean_species_label <- function(taxon_label) {
  cleaned <- sub(" \\(taxid [0-9]+\\)$", "", taxon_label)
  cleaned[cleaned == "" | grepl("^unclassified", cleaned, ignore.case = TRUE)] <- NA_character_
  cleaned
}

count_top_labels <- function(candidates, top_n = 3) {
  if (nrow(candidates) == 0) {
    character(0)
  } else {
    counts <- aggregate(
      cbind(contigs = rep(1, nrow(candidates)), total_bp = candidates$length_bp) ~ species_label,
      data = candidates,
      FUN = sum
    )
    counts <- counts[order(-counts$contigs, -counts$total_bp, counts$species_label), , drop = FALSE]
    head(counts$species_label, top_n)
  }
}

is_species_level_vibrio <- function(species_label) {
  !is.na(species_label) &
    grepl("^Vibrio [^ ]+", species_label) &
    !grepl("^Vibrio sp\\.?($| )", species_label) &
    species_label != "Vibrio" &
    !grepl(" subgroup$| group$", species_label)
}

top_vibrio_species_for_sample <- function(sample_data) {
  candidates <- sample_data[
    sample_data$broad_taxon == "Vibrio" &
      is_species_level_vibrio(sample_data$species_label),
    ,
    drop = FALSE
  ]
  count_top_labels(candidates, top_n = 3)
}

top_other_species_for_sample <- function(sample_data) {
  broad_labels <- c("Bacteria", "cellular organisms")
  candidates <- sample_data[
    sample_data$broad_taxon != "Vibrio" &
      sample_data$broad_taxon != "Unclassified" &
      !is.na(sample_data$species_label) &
      !(sample_data$species_label %in% broad_labels),
    ,
    drop = FALSE
  ]
  count_top_labels(candidates, top_n = 3)
}

plot_data$species_label <- clean_species_label(plot_data$taxon_label)
plot_data$short_id <- factor(plot_data$short_id, levels = sample_ids)

gc_limits <- range(plot_data$gc_percent)
length_limits <- range(plot_data$length_bp)
highlight_palette <- c(
  "#0072B2", # Top Vibrio 1: strong blue
  "#E69F00", # Top Vibrio 2: strong orange
  "#009E73", # Top Vibrio 3: strong green
  "#666666", # Other Vibrio: medium/dark gray
  "#CC79A7", # Other species 1: purple
  "#56B4E9", # Other species 2: cyan/light blue
  "#D81B60", # Other species 3: reddish magenta
  "#F0E442", # Extra cross-sample faceted label: yellow
  "#000000"  # Extra cross-sample faceted label: black
)

make_sample_plot_data <- function(sample_data, top_vibrio_species, top_other_species) {
  sample_data$plot_group <- NA_character_
  sample_data$species_rank <- NA_integer_
  sample_data$display_label <- NA_character_

  other_vibrio_hit <- sample_data$broad_taxon == "Vibrio"
  sample_data$plot_group[other_vibrio_hit] <- "Other Vibrio"
  sample_data$display_label[other_vibrio_hit] <- "Other Vibrio"

  for (rank in seq_along(top_vibrio_species)) {
    hit <- sample_data$species_label == top_vibrio_species[rank]
    sample_data$plot_group[hit] <- top_vibrio_species[rank]
    sample_data$species_rank[hit] <- rank
    sample_data$display_label[hit] <- top_vibrio_species[rank]
  }

  other_offset <- length(top_vibrio_species)
  for (rank in seq_along(top_other_species)) {
    hit <- sample_data$species_label == top_other_species[rank]
    sample_data$plot_group[hit] <- top_other_species[rank]
    sample_data$species_rank[hit] <- other_offset + rank
    sample_data$display_label[hit] <- top_other_species[rank]
  }

  sample_data <- sample_data[!is.na(sample_data$plot_group), , drop = FALSE]
  sample_data$plot_group <- factor(
    sample_data$plot_group,
    levels = c(top_vibrio_species, "Other Vibrio", top_other_species)
  )
  sample_data
}

make_gc_coverage_plot <- function(data, sample_label = NULL, log10_y = FALSE, facet = FALSE) {
  plot_levels <- levels(droplevels(data$plot_group))
  if (length(plot_levels) > length(highlight_palette)) {
    stop(
      "High-contrast highlight palette supports up to ",
      length(highlight_palette),
      " visibly separated highlighted groups, but this plot has ",
      length(plot_levels),
      ": ",
      paste(plot_levels, collapse = ", "),
      call. = FALSE
    )
  }
  color_values <- stats::setNames(highlight_palette[seq_along(plot_levels)], plot_levels)

  plot_title <- if (facet) {
    if (log10_y) {
      "Six-sample contig GC content and log10-scaled coverage"
    } else {
      "Six-sample contig GC content and coverage"
    }
  } else if (log10_y) {
    paste0(sample_label, " top Vibrio and other species contigs by GC content and log10-scaled coverage")
  } else {
    paste0(sample_label, " top Vibrio and other species contigs by GC content and coverage")
  }

  p <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = gc_percent, y = coverage, color = plot_group, size = length_bp)
  ) +
    ggplot2::geom_point(alpha = 0.45, stroke = 0) +
    ggplot2::scale_x_continuous(limits = gc_limits) +
    ggplot2::scale_color_manual(values = color_values, breaks = plot_levels, drop = FALSE) +
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
      color = "Kraken2 contig group",
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
sample_plot_rows <- list()
for (sample_id in sample_ids) {
  sample_data <- plot_data[plot_data$short_id == sample_id, , drop = FALSE]
  top_vibrio_species <- top_vibrio_species_for_sample(sample_data)
  top_other_species <- top_other_species_for_sample(sample_data)
  sample_plot_data <- make_sample_plot_data(sample_data, top_vibrio_species, top_other_species)
  if (nrow(sample_plot_data) == 0) {
    stop("No Vibrio or top species contigs available to plot for ", sample_id, call. = FALSE)
  }

  log_data <- sample_plot_data[sample_plot_data$coverage > 0, , drop = FALSE]
  if (nrow(log_data) == 0) {
    stop("No positive-coverage highlighted contigs available for log10 plotting in ", sample_id, call. = FALSE)
  }

  figures_dir <- file.path(blobtoolkit_dir, sample_id, "figures")
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

  linear_plot <- make_gc_coverage_plot(sample_plot_data, sample_label = sample_id, log10_y = FALSE)
  log_plot <- make_gc_coverage_plot(log_data, sample_label = sample_id, log10_y = TRUE)

  linear_png <- file.path(figures_dir, paste0(sample_id, "_top_species_gc_coverage_linear.png"))
  linear_pdf <- file.path(figures_dir, paste0(sample_id, "_top_species_gc_coverage_linear.pdf"))
  log_png <- file.path(figures_dir, paste0(sample_id, "_top_species_gc_coverage_log10.png"))
  log_pdf <- file.path(figures_dir, paste0(sample_id, "_top_species_gc_coverage_log10.pdf"))

  generated_paths <- c(
    save_plot_pair(linear_plot, linear_png, linear_pdf, width = 8.5, height = 6),
    save_plot_pair(log_plot, log_png, log_pdf, width = 8.5, height = 6)
  )

  top_counts <- table(sample_plot_data$display_label)
  summary_rows[[sample_id]] <- data.frame(
    short_id = sample_id,
    highlighted_contigs = nrow(sample_plot_data),
    positive_coverage_highlighted_contigs = nrow(log_data),
    zero_coverage_highlighted_contigs_omitted_from_log = sum(sample_plot_data$coverage == 0),
    top_vibrio_species_labels = paste(top_vibrio_species, collapse = "; "),
    top_other_species_labels = paste(top_other_species, collapse = "; "),
    highlighted_group_counts = paste(names(top_counts), as.integer(top_counts), sep = "=", collapse = "; "),
    figure_paths = paste(generated_paths, collapse = "; "),
    stringsAsFactors = FALSE
  )

  sample_plot_rows[[sample_id]] <- sample_plot_data
}

dir.create(dirname(summary_tsv), recursive = TRUE, showWarnings = FALSE)
plot_summary <- do.call(rbind, summary_rows)
utils::write.table(plot_summary, summary_tsv, sep = "\t", quote = FALSE, row.names = FALSE)

combined_plot_data <- do.call(rbind, sample_plot_rows)
combined_plot_levels <- unique(as.character(combined_plot_data$plot_group))
combined_plot_data$plot_group <- factor(as.character(combined_plot_data$plot_group), levels = combined_plot_levels)
dir.create(overview_figures_dir, recursive = TRUE, showWarnings = FALSE)

facet_linear_plot <- make_gc_coverage_plot(combined_plot_data, log10_y = FALSE, facet = TRUE)
facet_linear_png <- file.path(overview_figures_dir, "all_samples_top_species_gc_coverage_linear_faceted.png")
facet_linear_pdf <- file.path(overview_figures_dir, "all_samples_top_species_gc_coverage_linear_faceted.pdf")
facet_linear_paths <- save_plot_pair(facet_linear_plot, facet_linear_png, facet_linear_pdf, width = 12, height = 8)

facet_log_data <- combined_plot_data[combined_plot_data$coverage > 0, , drop = FALSE]
facet_log_plot <- make_gc_coverage_plot(facet_log_data, log10_y = TRUE, facet = TRUE)
facet_log_png <- file.path(overview_figures_dir, "all_samples_top_species_gc_coverage_log10_faceted.png")
facet_log_pdf <- file.path(overview_figures_dir, "all_samples_top_species_gc_coverage_log10_faceted.pdf")
facet_log_paths <- save_plot_pair(facet_log_plot, facet_log_png, facet_log_pdf, width = 12, height = 8)

cat("Top-species GC x coverage plotting summary\n")
cat("Wrote highlight summary: ", summary_tsv, "\n", sep = "")
for (i in seq_len(nrow(plot_summary))) {
  cat(
    plot_summary$short_id[i], ": ",
    "highlighted_contigs=", plot_summary$highlighted_contigs[i], "; ",
    "positive_coverage_highlighted_contigs=", plot_summary$positive_coverage_highlighted_contigs[i], "; ",
    "zero_coverage_highlighted_contigs_omitted_from_log=",
    plot_summary$zero_coverage_highlighted_contigs_omitted_from_log[i], "\n",
    "  top Vibrio species: ", plot_summary$top_vibrio_species_labels[i], "\n",
    "  top other species: ", plot_summary$top_other_species_labels[i], "\n",
    "  figures: ", plot_summary$figure_paths[i], "\n",
    sep = ""
  )
}
cat("Faceted linear overview figures: ", paste(facet_linear_paths, collapse = "; "), "\n", sep = "")
cat("Faceted log10 overview figures: ", paste(facet_log_paths, collapse = "; "), "\n", sep = "")
