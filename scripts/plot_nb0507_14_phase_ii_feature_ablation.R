#!/usr/bin/env Rscript
## Common-coordinate cluster comparisons for the NB0507-14 phase II ablation.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript scripts/plot_nb0507_14_phase_ii_feature_ablation.R RUN_DIR")
run_dir <- args[[1L]]
read_table <- function(name) {
  path <- file.path(run_dir, name)
  if (!file.exists(path)) stop("Missing input: ", path)
  read.delim(path, check.names = FALSE, stringsAsFactors = FALSE)
}
features <- read_table("features_raw.tsv")
assignments <- read_table("assignments.tsv")
metrics <- read_table("cluster_metrics.tsv")
ari <- read_table("adjusted_rand.tsv")
models <- c("full", "gc_coverage", "gc_length", "length_coverage")
ks <- 2:8
if (nrow(features) != 13807L || anyDuplicated(features$contig_id) ||
    nrow(assignments) != 13807L * 4L * 7L || nrow(metrics) != 28L ||
    nrow(ari) != 42L) stop("Unexpected input dimensions")
fig_dir <- file.path(run_dir, "figures")
if (dir.exists(fig_dir)) stop("Figure directory already exists: ", fig_dir)
dir.create(fig_dir)
palette <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7",
             "#E69F00", "#56B4E9", "#882255", "#999999")
for (k in ks) {
  out <- file.path(fig_dir, sprintf("cluster_structure_k%d.pdf", k))
  if (file.exists(out)) stop("Refusing to replace: ", out)
  pdf(out, width = 11, height = 8.5, useDingbats = FALSE)
  par(mfrow = c(2, 2), mar = c(4.2, 4.2, 3, 1), oma = c(0, 0, 2, 0))
  for (name in models) {
    sub <- assignments[assignments$model == name & assignments$k == k, ]
    ix <- match(features$contig_id, sub$contig_id)
    if (nrow(sub) != 13807L || anyNA(ix) || anyDuplicated(sub$contig_id))
      stop("Incomplete assignments for ", name, " k=", k)
    cluster <- sub$cluster[ix]
    if (!setequal(unique(cluster), 0:(k - 1L))) stop("Missing cluster for ", name)
    plot(features$gc_percent, features$log10_coverage_plus_1,
         pch = 16, cex = 0.25, col = adjustcolor(palette[cluster + 1L], alpha.f = 0.45),
         xlab = "GC (%)", ylab = "log10(self-mapping coverage + 1)",
         main = gsub("_", " + ", name), xlim = range(features$gc_percent),
         ylim = range(features$log10_coverage_plus_1))
    legend("topright", legend = paste0(0:(k-1L), " (", tabulate(cluster + 1L, nbins=k), ")"),
           col = palette[seq_len(k)], pch = 16, cex = 0.65, bty = "n", ncol = 2)
  }
  mtext(sprintf("NB0507-14 feature ablation, k=%d; same projection for all models", k),
        outer = TRUE, cex = 1.1)
  dev.off()
}
out <- file.path(fig_dir, "ablation_summary.pdf")
if (file.exists(out)) stop("Refusing to replace: ", out)
pdf(out, width = 11, height = 8.5, useDingbats = FALSE)
par(mfrow = c(2, 1), mar = c(4.2, 5, 2.8, 1))
plot(NA, xlim = c(2, 8), ylim = range(metrics$silhouette_sampled),
     xlab = "k", ylab = "Sampled silhouette", main = "Euclidean silhouette on the same seeded 2,000-contig sample")
for (i in seq_along(models)) {
  sub <- metrics[metrics$model == models[i], ]
  lines(sub$k, sub$silhouette_sampled, type = "b", pch = i, col = palette[i], lwd = 2)
}
legend("topright", models, col = palette[seq_along(models)], pch = seq_along(models), lty = 1, bty = "n")
plot(NA, xlim = c(2, 8), ylim = range(ari$adjusted_rand_index),
     xlab = "k", ylab = "Adjusted Rand index", main = "Full model agreement with each two-feature model")
for (i in 2:4) {
  sub <- ari[ari$model_a == "full" & ari$model_b == models[i], ]
  if (nrow(sub) != 7L) stop("Missing full-model ARI comparison: ", models[i])
  lines(sub$k, sub$adjusted_rand_index, type = "b", pch = i, col = palette[i], lwd = 2)
}
legend("bottomleft", models[2:4], col = palette[2:4], pch = 2:4, lty = 1, bty = "n")
dev.off()
cat("Wrote 7 cluster structure PDFs and ablation_summary.pdf\n")
