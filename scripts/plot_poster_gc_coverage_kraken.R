#!/usr/bin/env Rscript
# Plot existing BlobToolKit master tables for the ABRCMS poster.
# Input manifest columns: isolate,depth,master_table. Output filenames are
# "[isolate] at [depth].png/pdf"; all paths must be unused before any write.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript scripts/plot_poster_gc_coverage_kraken.R MANIFEST OUTPUT_DIR")
if (!requireNamespace("ggplot2", quietly = TRUE) || !requireNamespace("scales", quietly = TRUE))
  stop("Required R packages: ggplot2, scales")
manifest <- read.delim(args[1], sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
required <- c("isolate", "depth", "master_table")
if (!identical(names(manifest), required) || nrow(manifest) == 0L) stop("Manifest must have isolate, depth, master_table and at least one row")
if (anyNA(manifest) || any(!nzchar(as.matrix(manifest))) || anyDuplicated(paste(manifest$isolate, manifest$depth))) stop("Empty, missing or duplicate manifest value")
if (any(grepl("[/\\\\]", manifest$isolate)) || any(grepl("[/\\\\]", manifest$depth))) stop("Isolate and depth must not contain path separators")
out <- args[2]
if (dir.exists(out) && length(list.files(out, all.files = TRUE, no.. = TRUE))) stop("Output directory is not empty: ", out)
paths <- unlist(lapply(seq_len(nrow(manifest)), function(i) file.path(out, paste0(manifest$isolate[i], " at ", manifest$depth[i], c(".png", ".pdf")))))
if (any(file.exists(paths))) stop("An output already exists")
tables <- lapply(seq_len(nrow(manifest)), function(i) {
  path <- manifest$master_table[i]
  if (!file.exists(path) || file.info(path)$size == 0) stop("Missing master table: ", path)
  x <- read.delim(path, sep = "\t", quote = "", comment.char = "", stringsAsFactors = FALSE, check.names = FALSE)
  cols <- c("short_id", "gc_percent", "coverage", "length_bp", "broad_taxon")
  if (!all(cols %in% names(x))) stop("Missing plotting column in: ", path)
  if (anyNA(x[, cols]) || any(!is.finite(x$gc_percent)) || any(!is.finite(x$coverage)) ||
      any(x$gc_percent < 0 | x$gc_percent > 100) || any(x$coverage < 0) || any(x$length_bp <= 0)) stop("Invalid plotting values: ", path)
  if (length(unique(x$short_id)) != 1L || unique(x$short_id) != manifest$isolate[i]) stop("Isolate mismatch: ", path)
  x
})
palette <- c(Vibrio = "#0072B2", Bacillus = "#D55E00", Reyranella = "#009E73",
             `Other classified` = "#7A7A7A", Unclassified = "#B7B7B7")
if (any(!unlist(lapply(tables, function(x) unique(x$broad_taxon))) %in% names(palette))) stop("Unknown Kraken2 broad taxon")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
for (i in seq_len(nrow(manifest))) {
  x <- tables[[i]]
  x <- x[x$coverage > 0, ] # log10 undefined at zero; count is recorded below
  if (nrow(x) == 0L) stop("No positive-coverage contigs: ", manifest$master_table[i])
  p <- ggplot2::ggplot(x, ggplot2::aes(gc_percent, coverage, color = broad_taxon, size = length_bp)) +
    ggplot2::geom_point(alpha = 0.45, stroke = 0) +
    ggplot2::scale_y_log10(labels = scales::comma) +
    ggplot2::scale_color_manual(values = palette, limits = names(palette), drop = FALSE) +
    ggplot2::scale_size_continuous(range = c(0.2, 5), trans = "sqrt", labels = scales::comma) +
    ggplot2::labs(title = paste(manifest$isolate[i], "at", manifest$depth[i]),
                  x = "GC content (%)", y = "Self-mapping coverage (log10 scale)",
                  color = "Kraken2 contig group", size = "Contig length (bp)") +
    ggplot2::theme_bw(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), plot.title = ggplot2::element_text(face = "bold"))
  stem <- file.path(out, paste(manifest$isolate[i], "at", manifest$depth[i]))
  ggplot2::ggsave(paste0(stem, ".png"), p, width = 8.5, height = 6, dpi = 300, bg = "white")
  ggplot2::ggsave(paste0(stem, ".pdf"), p, width = 8.5, height = 6, bg = "white")
  cat(manifest$isolate[i], manifest$depth[i], nrow(tables[[i]]), nrow(x), "\n", sep = "\t")
}
