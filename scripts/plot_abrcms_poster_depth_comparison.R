#!/usr/bin/env Rscript
# Six per-isolate distributions: contig length, GC, self-coverage, Kraken2 bp share.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript plot_abrcms_poster_depth_comparison.R METRICS_DIR OUTPUT_DIR")
for (pkg in c("ggplot2", "patchwork"))
  if (!requireNamespace(pkg, quietly = TRUE)) stop("Missing R package: ", pkg)
metrics <- args[1]
out <- args[2]
if (file.exists(out)) stop("Refusing to replace an existing figure directory: ", out)
dist <- read.delim(file.path(metrics, "contig_distribution_plot_data.tsv"), sep="\t", stringsAsFactors=FALSE)
broad <- read.delim(file.path(metrics, "kraken_broad_composition.tsv"), sep="\t", stringsAsFactors=FALSE)
selected <- read.delim(file.path(metrics, "selected_depth.tsv"), sep="\t", stringsAsFactors=FALSE)
if (nrow(dist) == 0L || length(unique(dist$isolate)) != 6L || length(unique(dist$short_id)) != 18L || nrow(broad) != 90L || nrow(selected) != 6L)
  stop("Expected six isolates, 18 conditions, 90 broad-taxon rows and six selections")
if (anyNA(dist[, c("length_bp", "gc_percent", "coverage")]) || any(dist$length_bp <= 0 | dist$coverage < 0 | dist$gc_percent < 0 | dist$gc_percent > 100))
  stop("Invalid contig distribution values")
depths <- c("25x", "50x", "100x")
depth_colors <- c("25x"="#2C7FB8", "50x"="#27A59B", "100x"="#D95F0E")
taxon_colors <- c("Vibrio"="#0072B2", "Bacillus"="#D55E00", "Reyranella"="#009E73", "Other classified"="#7A7A7A", "Unclassified"="#B7B7B7")
dir.create(out, recursive=TRUE, showWarnings=FALSE)
for (isolate in sort(unique(dist$isolate))) {
  d <- dist[dist$isolate == isolate, ]
  b <- broad[broad$isolate == isolate, ]
  choice <- selected$selected_depth[match(isolate, selected$isolate)]
  if (nrow(d) == 0L || nrow(b) != 15L || is.na(choice)) stop("Incomplete isolate: ", isolate)
  d$depth <- factor(d$depth, levels=depths)
  b$depth <- factor(b$depth, levels=depths)
  b$broad_taxon <- factor(b$broad_taxon, levels=names(taxon_colors))
  d$log10_length <- log10(d$length_bp)
  d$log10_coverage_plus_1 <- log10(d$coverage + 1)
  theme <- ggplot2::theme_bw(base_size=11) + ggplot2::theme(panel.grid.minor=ggplot2::element_blank())
  p_length <- ggplot2::ggplot(d, ggplot2::aes(log10_length, color=depth)) +
    ggplot2::geom_density(linewidth=0.8) + ggplot2::scale_color_manual(values=depth_colors) +
    ggplot2::labs(title="Contig length distribution", x="log10(contig bp)", y="Density by contig count") + theme
  p_gc <- ggplot2::ggplot(d, ggplot2::aes(gc_percent, color=depth)) +
    ggplot2::geom_density(linewidth=0.8) + ggplot2::scale_color_manual(values=depth_colors) +
    ggplot2::labs(title="GC distribution", x="Contig GC (%)", y="Density by contig count") + theme
  p_cov <- ggplot2::ggplot(d, ggplot2::aes(log10_coverage_plus_1, color=depth)) +
    ggplot2::geom_density(linewidth=0.8) + ggplot2::scale_color_manual(values=depth_colors) +
    ggplot2::labs(title="Self-mapping coverage distribution", x="log10(coverage + 1)", y="Density by contig count") + theme
  p_tax <- ggplot2::ggplot(b, ggplot2::aes(depth, assembled_bp_pct, fill=broad_taxon)) +
    ggplot2::geom_col(width=0.7) + ggplot2::scale_fill_manual(values=taxon_colors, drop=FALSE) +
    ggplot2::scale_y_continuous(expand=c(0,0)) + ggplot2::coord_cartesian(ylim=c(0,100)) +
    ggplot2::labs(title="Kraken2 broad composition", x="Nominal depth", y="Assembled bp (%)", fill="Provisional class") + theme
  combined <- (p_length + p_gc) / (p_cov + p_tax) +
    patchwork::plot_annotation(title=paste0(isolate, ": depth comparison; selected ", choice),
      subtitle="Contig distributions are count-based; Kraken2 bars are assembled-bp weighted. Self-mapping is assembly-derived.")
  stem <- file.path(out, paste0(isolate, "_depth_distributions"))
  ggplot2::ggsave(paste0(stem, ".pdf"), combined, width=13, height=9, bg="white")
  ggplot2::ggsave(paste0(stem, ".png"), combined, width=13, height=9, dpi=180, bg="white")
  message("Wrote ", stem, ".{pdf,png}")
}
