#!/usr/bin/env Rscript
# ABRCMS Fig. 2: old Buck NB0507-14 original versus nominal 25x assembly.
# Biological question: how do assembled-contig GC, self-mapping coverage, and
# provisional broad Kraken2 labels differ after read subsampling/reassembly?
# Usage: Rscript scripts/plot_nb0507_14_gc_coverage_two_panel.R ORIGINAL_MASTER DOWNSAMPLED_MASTER NEW_OUTPUT_DIR
# Input: BlobToolKit master TSVs with short_id, contig_id, length_bp, gc_percent,
# coverage, and broad_taxon. Output: PDF, SVG, 600 DPI PNG, summary TSV, caption.
# The output directory must not exist. No read mapping or Kraken2 is performed.

suppressPackageStartupMessages({
  library(ggplot2)
  library(cowplot)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: Rscript scripts/plot_nb0507_14_gc_coverage_two_panel.R ORIGINAL_MASTER DOWNSAMPLED_MASTER NEW_OUTPUT_DIR")
if (!requireNamespace("ragg", quietly = TRUE)) stop("Required package: ragg")
if (dir.exists(args[3]) || file.exists(args[3])) stop("Output path already exists: ", args[3])

classes <- c("Vibrio", "Reyranella", "Bacillus", "Other classified", "Unclassified")
colors <- c(Vibrio = "#0072B2", Reyranella = "#009E73", Bacillus = "#D55E00",
            `Other classified` = "#CC79A7", Unclassified = "#666666")

load_master <- function(path, expected_id) {
  if (!file.exists(path) || file.info(path)$size <= 0) stop("Missing or empty master TSV: ", path)
  x <- read.delim(path, sep = "\t", quote = "", comment.char = "", check.names = FALSE,
                  stringsAsFactors = FALSE)
  needed <- c("short_id", "contig_id", "length_bp", "gc_percent", "coverage", "broad_taxon")
  if (!all(needed %in% names(x))) stop("Missing required columns in: ", path)
  x <- x[, needed]
  if (nrow(x) == 0L || anyNA(x) || anyDuplicated(x$contig_id) ||
      !identical(unique(x$short_id), expected_id)) stop("Invalid contig rows or condition ID: ", path)
  for (column in c("length_bp", "gc_percent", "coverage")) {
    x[[column]] <- suppressWarnings(as.numeric(x[[column]]))
    if (any(!is.finite(x[[column]]))) stop("Invalid numeric ", column, ": ", path)
  }
  if (any(x$length_bp <= 0) || any(x$gc_percent < 0 | x$gc_percent > 100) ||
      any(x$coverage < 0) || any(!x$broad_taxon %in% classes)) stop("Out-of-range master values: ", path)
  x$broad_taxon <- factor(x$broad_taxon, levels = classes)
  x
}

original <- load_master(args[1], "NB0507_14")
downsampled <- load_master(args[2], "NB0507_14_25x")
if (nrow(original) != 72565L || nrow(downsampled) != 6113L ||
    sum(original$length_bp) != 46406154 || sum(downsampled$length_bp) != 8012250)
  stop("Source table counts/span differ from the audited 2026-11-12 inputs")

summary <- data.frame(
  condition = c("original_full_reads", "nominal_25x"),
  contigs = c(nrow(original), nrow(downsampled)),
  assembled_bp = c(sum(original$length_bp), sum(downsampled$length_bp)),
  plotted_positive_coverage_contigs = c(sum(original$coverage > 0), sum(downsampled$coverage > 0)),
  omitted_zero_coverage_contigs = c(sum(original$coverage == 0), sum(downsampled$coverage == 0))
)

# Draw neutral categories first so the focal colors remain legible where points overlap.
prepare_points <- function(x) {
  x <- x[x$coverage > 0, ]
  x[order(match(as.character(x$broad_taxon),
                c("Unclassified", "Other classified", "Bacillus", "Reyranella", "Vibrio"))), ]
}
original_plot <- prepare_points(original)
downsampled_plot <- prepare_points(downsampled)

base_theme <- theme_minimal(base_size = 14, base_family = "sans") +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        panel.grid.major.y = element_line(color = "#E4E8EB", linewidth = 0.25),
        axis.line = element_line(color = "#263746", linewidth = 0.35),
        axis.ticks = element_line(color = "#263746", linewidth = 0.35),
        plot.title = element_text(face = "bold", size = 17, color = "#223447", margin = margin(b = 5)),
        plot.subtitle = element_text(size = 11.5, color = "#536577", margin = margin(b = 9)),
        axis.title = element_text(size = 13, color = "#263746"),
        axis.text = element_text(size = 11, color = "#425466"),
        legend.title = element_blank(), legend.text = element_text(size = 11),
        legend.key.width = unit(0.36, "in"), legend.spacing.x = unit(0.12, "in"),
        plot.margin = margin(12, 14, 12, 14))

main_panel <- function(x, title, subtitle, show_y = TRUE) {
  ggplot(x, aes(x = gc_percent, y = coverage, color = broad_taxon)) +
    geom_point(size = 0.48, alpha = 0.18, stroke = 0) +
    scale_color_manual(values = colors, limits = classes, drop = FALSE,
                       guide = guide_legend(override.aes = list(size = 3.5, alpha = 1), nrow = 1)) +
    scale_x_continuous(limits = c(10, 100), breaks = seq(20, 100, by = 20), expand = c(0, 0)) +
    scale_y_log10(limits = c(0.1, 10000), breaks = c(0.1, 1, 10, 100, 1000, 10000),
                  labels = c("0.1", "1", "10", "100", "1,000", "10,000"), expand = c(0, 0)) +
    labs(title = title, subtitle = subtitle, x = "Contig GC content (%)",
         y = if (show_y) "Self-mapping coverage (×; log scale)" else NULL) +
    base_theme + if (!show_y) theme(axis.text.y = element_blank(), axis.ticks.y = element_blank()) else theme()
}

panel_a <- main_panel(original_plot, "A  Original full-read assembly",
                      "72,565 contigs  ·  46.41 Mb assembled")
panel_b <- main_panel(downsampled_plot, "B  Nominal 25× reassembly",
                      "6,113 contigs  ·  8.01 Mb assembled")

# Labeled detail view within B: preserves the identical main axes while showing
# the dense low-coverage portion of the 25x population at readable scale.
inset <- ggplot(downsampled_plot, aes(gc_percent, coverage, color = broad_taxon)) +
  geom_point(size = 0.35, alpha = 0.24, stroke = 0) +
  scale_color_manual(values = colors, limits = classes, guide = "none") +
  scale_x_continuous(breaks = c(20, 50, 80), expand = c(0, 0)) +
  scale_y_log10(breaks = c(0.5, 1, 3, 10),
                labels = c("0.5", "1", "3", "10"), expand = c(0, 0)) +
  coord_cartesian(xlim = c(20, 85), ylim = c(0.5, 10)) +
  labs(title = "25× detail · 0.5–10×", x = "GC (%)", y = "Coverage (×)") +
  theme_bw(base_size = 8) +
  theme(plot.background = element_rect(fill = "white", color = "#7D8A95", linewidth = 0.5),
        panel.grid = element_line(color = "#EEF0F1", linewidth = 0.2),
        plot.title = element_text(size = 9, face = "bold", margin = margin(b = 2)),
        axis.title = element_text(size = 8), axis.text = element_text(size = 7),
        plot.margin = margin(5, 7, 5, 5))
legend_table <- ggplotGrob(panel_a + theme(legend.position = "bottom"))
legend <- legend_table$grobs[[which(legend_table$layout$name == "guide-box-bottom")]]
if (inherits(legend, "zeroGrob")) stop("Shared legend could not be extracted")
panel_a_canvas <- cowplot::ggdraw(panel_a + theme(legend.position = "none"))
panel_b_canvas <- cowplot::ggdraw(panel_b + theme(legend.position = "none")) +
  cowplot::draw_plot(inset, x = 0.56, y = 0.53, width = 0.41, height = 0.37)
panels <- cowplot::plot_grid(panel_a_canvas, panel_b_canvas, nrow = 1, align = "hv", axis = "tblr")
title_block <- cowplot::ggdraw() +
  cowplot::draw_label("NB0507-14 | contig GC, self-coverage and Kraken2 classification",
                      x = 0.02, y = 0.68, hjust = 0, size = 21, fontface = "bold", color = "#223447") +
  cowplot::draw_label("Old Buck run · original paired reads versus nominal 25× sampled reads, assembled independently",
                      x = 0.02, y = 0.19, hjust = 0, size = 12, color = "#536577")
legend_block <- cowplot::ggdraw() + cowplot::draw_grob(legend, x = 0.1, y = 0.03, width = 0.8, height = 0.94)
caption_block <- cowplot::ggdraw() +
  cowplot::draw_label("Each point is one contig; zero-coverage contigs omitted. Colors are provisional Kraken2 contig groups.",
                      x = 0.02, y = 0.74, hjust = 0, size = 9.5, color = "#536577") +
  cowplot::draw_label("Coverage maps each read set to its own assembly; nominal 25× is a read-subsampling target, not mapped coverage.",
                      x = 0.02, y = 0.26, hjust = 0, size = 9.5, color = "#536577")
figure <- cowplot::plot_grid(title_block, panels, legend_block, caption_block,
                             ncol = 1, rel_heights = c(0.11, 0.72, 0.08, 0.09))

dir.create(args[3], recursive = TRUE, showWarnings = FALSE)
stem <- file.path(args[3], "nb0507_14_gc_coverage_original_vs_25x")
paths <- c(paste0(stem, c(".pdf", ".svg", ".png")),
           file.path(args[3], "figure_summary.tsv"), file.path(args[3], "figure_caption.md"))
if (any(file.exists(paths))) stop("Refusing to replace an existing figure output")
ggsave(paths[1], figure, device = cairo_pdf, width = 15, height = 8.5, units = "in", bg = "white")
ggsave(paths[2], figure, device = grDevices::svg, width = 15, height = 8.5, units = "in", bg = "white")
ggsave(paths[3], figure, device = ragg::agg_png, width = 15, height = 8.5,
       units = "in", dpi = 600, bg = "white")
write.table(summary, paths[4], sep = "\t", quote = FALSE, row.names = FALSE)
writeLines(c("# NB0507-14 GC × coverage × Kraken2 figure caption", "",
             "Original full-read assembly (A) and nominal 25× sampled-read reassembly (B) of the old Buck NB0507-14 run. Each point represents one contig, positioned by GC percentage and self-mapping read coverage on identical logarithmic coverage axes; the inset expands 0.5–10× in panel B. Colors show provisional broad Kraken2 contig assignments. Panels contain 72,565 contigs/46.41 Mb and 6,113 contigs/8.01 Mb, respectively. Zero-coverage contigs (410 and 18) are omitted from the scatterplots but included in the assembly totals. Both read sets were mapped to their own assemblies. The nominal 25× target reflects sampled read bases per assumed genome, not mapped coverage. Composition shifts do not establish contaminant removal or species identity."), paths[5])
cat("Created outputs in ", args[3], "\n", sep = "")
