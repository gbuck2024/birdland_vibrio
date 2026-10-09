#!/usr/bin/env Rscript
# Generate compact comparison figures for the NB0507-14 resequencing stage.

stage <- "comparison_nb0507_14_resequencing"
metrics_dir <- file.path(stage, "metrics")
figures_dir <- file.path(stage, "figures")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

read_table <- function(path) {
  if (!file.exists(path) || file.info(path)$size == 0) {
    return(data.frame())
  }
  read.delim(path, sep = "\t", header = TRUE, stringsAsFactors = FALSE, check.names = FALSE)
}

save_plot <- function(name, expr, width = 8, height = 5) {
  plot_expr <- substitute(expr)
  pdf(file.path(figures_dir, paste0(name, ".pdf")), width = width, height = height)
  eval(plot_expr, parent.frame())
  dev.off()
  png(file.path(figures_dir, paste0(name, ".png")), width = width, height = height, units = "in", res = 160)
  eval(plot_expr, parent.frame())
  dev.off()
}

labels <- c(
  A_old_full = "Old full",
  B_old_downsampled = "Old downsampled",
  C_new = "New"
)
cols <- c(A_old_full = "#4C78A8", B_old_downsampled = "#F58518", C_new = "#54A24B")

matched <- read_table(file.path(metrics_dir, "matched_isolate_comparison.tsv"))
assembly <- read_table(file.path(metrics_dir, "assembly_comparison.tsv"))
coverage <- read_table(file.path(metrics_dir, "coverage_comparison.tsv"))
taxonomy <- read_table(file.path(metrics_dir, "taxonomy_comparison.tsv"))

if (nrow(matched) > 0) {
  matched$paired_retained <- suppressWarnings(as.numeric(matched$paired_retained))
  matched$input_pairs <- suppressWarnings(as.numeric(matched$input_pairs))
  matched$retention_pct <- 100 * matched$paired_retained / matched$input_pairs
  save_plot("raw_vs_trimmed_read_retention", {
    par(mar = c(7, 5, 3, 1))
    vals <- matched$retention_pct
    names(vals) <- labels[matched$condition]
    barplot(vals, col = cols[matched$condition], las = 2, ylab = "Trimmed paired reads retained (%)", ylim = c(0, 105))
    title("Raw versus trimmed read retention")
  })
}

if (nrow(assembly) > 0) {
  assembly$n50_bp <- suppressWarnings(as.numeric(assembly$n50_bp))
  assembly$contig_count <- suppressWarnings(as.numeric(assembly$contig_count))
  assembly$assembly_size_bp <- suppressWarnings(as.numeric(assembly$assembly_size_bp))
  save_plot("n50_and_contig_count", {
    par(mfrow = c(1, 2), mar = c(7, 5, 3, 1))
    n50 <- assembly$n50_bp
    names(n50) <- labels[assembly$condition]
    barplot(n50, col = cols[assembly$condition], las = 2, ylab = "N50 (bp)", main = "N50")
    contigs <- assembly$contig_count
    names(contigs) <- labels[assembly$condition]
    barplot(contigs, col = cols[assembly$condition], las = 2, ylab = "Contigs", main = "Contig count")
  }, width = 9, height = 5)
  save_plot("assembly_size", {
    par(mar = c(7, 5, 3, 1))
    vals <- assembly$assembly_size_bp / 1e6
    names(vals) <- labels[assembly$condition]
    barplot(vals, col = cols[assembly$condition], las = 2, ylab = "Assembly size (Mbp)")
    title("Assembly size")
  })
}

master_paths <- list(
  A_old_full = "ambiguous_isolate_resolution/blobtoolkit/NB0507_14/metrics/NB0507_14.master_contig_table.tsv",
  B_old_downsampled = file.path(stage, "downsampled_old_self_mapping/NB0507_14_downsampled/metrics/NB0507_14_downsampled.master_contig_table.tsv"),
  C_new = "ambiguous_isolate_resolution/blobtoolkit_sra/SRR37852095/metrics/SRR37852095.master_contig_table.tsv"
)
masters <- lapply(master_paths, read_table)
masters <- masters[vapply(masters, nrow, numeric(1)) > 0]

if (length(masters) > 0) {
  save_plot("coverage_distributions", {
    par(mar = c(7, 5, 3, 1))
    covs <- lapply(masters, function(x) suppressWarnings(as.numeric(x$coverage)))
    covs <- lapply(covs, function(x) log10(x[x > 0]))
    boxplot(covs, names = labels[names(covs)], col = cols[names(covs)], las = 2, ylab = "log10(contig mean coverage)")
    title("Self-mapping coverage distributions")
  })
  save_plot("gc_x_coverage_side_by_side", {
    par(mfrow = c(1, length(masters)), mar = c(5, 5, 3, 1))
    for (nm in names(masters)) {
      tab <- masters[[nm]]
      gc <- suppressWarnings(as.numeric(tab$gc_percent))
      cov <- suppressWarnings(as.numeric(tab$coverage))
      len <- suppressWarnings(as.numeric(tab$length_bp))
      size <- pmax(0.4, pmin(2.5, sqrt(len) / 120))
      plot(gc, cov, log = "y", pch = 16, cex = size, col = adjustcolor(cols[nm], alpha.f = 0.55),
           xlab = "GC (%)", ylab = "Contig mean coverage", main = labels[nm])
    }
  }, width = 12, height = 4.5)
}

if (nrow(taxonomy) > 0) {
  taxonomy$read_dominant_genus_pct <- suppressWarnings(as.numeric(taxonomy$read_dominant_genus_pct))
  taxonomy$read_unclassified_pct <- suppressWarnings(as.numeric(taxonomy$read_unclassified_pct))
  save_plot("kraken_composition", {
    par(mar = c(7, 5, 3, 1))
    mat <- rbind(
      dominant_genus = taxonomy$read_dominant_genus_pct,
      unclassified = taxonomy$read_unclassified_pct,
      other = pmax(0, 100 - taxonomy$read_dominant_genus_pct - taxonomy$read_unclassified_pct)
    )
    colnames(mat) <- labels[taxonomy$condition]
    barplot(mat, beside = FALSE, las = 2, ylab = "Read classification (%)",
            col = c("#4C78A8", "#9D9DA3", "#E45756"), legend.text = rownames(mat),
            args.legend = list(x = "topright", bty = "n"))
    title("Kraken2 read composition")
  })
}

if (nrow(assembly) > 0 && nrow(coverage) > 0 && nrow(taxonomy) > 0) {
  merged <- merge(assembly, coverage, by = c("condition", "sample_id"), all = TRUE)
  merged <- merge(merged, taxonomy, by = c("condition", "sample_id"), all = TRUE)
  merged$n50_mbp <- suppressWarnings(as.numeric(merged$n50_bp)) / 1e6
  merged$coverage_cv_contig_mean <- suppressWarnings(as.numeric(merged$coverage_cv_contig_mean))
  merged$read_unclassified_pct <- suppressWarnings(as.numeric(merged$read_unclassified_pct))
  save_plot("old_full_vs_downsampled_vs_new_summary", {
    par(mfrow = c(1, 3), mar = c(7, 5, 3, 1))
    vals <- merged$n50_mbp
    names(vals) <- labels[merged$condition]
    barplot(vals, col = cols[merged$condition], las = 2, ylab = "N50 (Mbp)", main = "Assembly")
    vals <- merged$coverage_cv_contig_mean
    names(vals) <- labels[merged$condition]
    barplot(vals, col = cols[merged$condition], las = 2, ylab = "Coverage CV", main = "Coverage")
    vals <- merged$read_unclassified_pct
    names(vals) <- labels[merged$condition]
    barplot(vals, col = cols[merged$condition], las = 2, ylab = "Unclassified reads (%)", main = "Kraken2")
  }, width = 11, height = 4.5)
}

message("Wrote NB0507-14 resequencing figures to ", figures_dir)
