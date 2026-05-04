#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grepl(file_arg, args)])
if (length(script_path) == 0) {
  script_path <- "scripts/plot_vcg_tree.R"
}

script_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
project_dir <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)

tree_file <- file.path(project_dir, "vcg_mining", "tree", "all_vcg_sequences.fasttree.nwk")
pdf_file <- file.path(project_dir, "vcg_mining", "tree", "all_vcg_sequences.fasttree.pdf")

if (!file.exists(tree_file) || file.info(tree_file)$size == 0) {
  stop("Input tree is missing or empty: ", tree_file, call. = FALSE)
}

if (!requireNamespace("ape", quietly = TRUE)) {
  stop("R package 'ape' is not available. Install/load ape, then rerun this script.", call. = FALSE)
}

tree <- ape::read.tree(tree_file)

pdf(pdf_file, width = 8, height = 5)
par(mar = c(1, 1, 2, 1))
ape::plot.phylo(
  tree,
  type = "phylogram",
  cex = 0.85,
  no.margin = TRUE,
  main = "vcg single-gene FastTree"
)
ape::add.scale.bar(cex = 0.75)
dev.off()

cat("Output PDF:", pdf_file, "\n")
