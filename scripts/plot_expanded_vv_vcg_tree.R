#!/usr/bin/env Rscript

args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args_all[grepl(file_arg, args_all)])
if (length(script_path) == 0) {
  script_path <- "scripts/plot_expanded_vv_vcg_tree.R"
}

script_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
project_dir <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)

tree_file <- file.path(project_dir, "phylogeny", "expanded_vv_46", "vcg_tree", "tree", "expanded_vv_46_vcg.fasttree.nwk")
calls_file <- file.path(project_dir, "phylogeny", "expanded_vv_46", "vcg_tree", "metadata", "expanded_vv_46_vcg_calls.tsv")
manifest_file <- file.path(project_dir, "configs", "expanded_vv_46_genome_manifest.tsv")
out_dir <- file.path(project_dir, "phylogeny", "expanded_vv_46", "vcg_tree", "figures")
pdf_file <- file.path(out_dir, "expanded_vv_46_vcg_tree.pdf")
png_file <- file.path(out_dir, "expanded_vv_46_vcg_tree.png")
x_axis_label <- "Evolutionary distance (substitutions per site)"

for (pkg in c("ape")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Missing required R package: ", pkg, call. = FALSE)
  }
}
has_ggtree <- requireNamespace("ggtree", quietly = TRUE) && requireNamespace("ggplot2", quietly = TRUE)

for (path in c(tree_file, calls_file, manifest_file)) {
  if (!file.exists(path) || file.info(path)$size == 0) {
    stop("Required input is missing or empty: ", path, call. = FALSE)
  }
}

read_tsv <- function(path) {
  read.delim(path, sep = "\t", header = TRUE, stringsAsFactors = FALSE, check.names = FALSE)
}

simplify_buck_label <- function(x) {
  replacements <- c(
    buck_BS0607_9_50x = "BS0607_9",
    Buck_BS0607_9 = "BS0607_9",
    buck_CB0707_82_25x = "CB0707_82",
    Buck_CB0707_82 = "CB0707_82",
    buck_NB0507_8_100x = "NB0507_8",
    Buck_NB0507_8 = "NB0507_8"
  )
  ifelse(x %in% names(replacements), replacements[x], x)
}

parse_source <- function(genome_id, reference_format, notes) {
  source <- rep("not_reported", length(genome_id))
  source[grepl("^buck_", genome_id, ignore.case = TRUE)] <- "Buck"
  source[grepl("^atcc_27562$", genome_id, ignore.case = TRUE)] <- "ATCC"
  has_source <- grepl("Source:", notes, ignore.case = TRUE)
  source[has_source] <- sub("^.*Source:[[:space:]]*([^.;]+).*$", "\\1", notes[has_source], ignore.case = TRUE)
  source
}

parse_group <- function(genome_id, reference_format) {
  group <- reference_format
  group[grepl("mullis2019", reference_format, ignore.case = TRUE)] <- "Mullis"
  group[grepl("^buck_", genome_id, ignore.case = TRUE)] <- "Buck"
  group[grepl("^atcc_27562$", genome_id, ignore.case = TRUE)] <- "ATCC"
  group
}

tip_to_genome_id <- function(label) {
  sub("\\|.*$", "", label)
}

manifest <- read_tsv(manifest_file)
if (!"genome_id" %in% names(manifest) && "reference_id" %in% names(manifest)) {
  manifest$genome_id <- manifest$reference_id
}
if (!"reference_format" %in% names(manifest)) {
  manifest$reference_format <- "not_reported"
}
if (!"notes" %in% names(manifest)) {
  manifest$notes <- ""
}
manifest$source <- if ("source" %in% names(manifest)) manifest$source else parse_source(manifest$genome_id, manifest$reference_format, manifest$notes)
manifest$group <- if ("group" %in% names(manifest)) manifest$group else parse_group(manifest$genome_id, manifest$reference_format)

calls <- read_tsv(calls_file)
required_calls <- c("genome_id", "best_vcg_call")
missing_calls <- setdiff(required_calls, names(calls))
if (length(missing_calls) > 0) {
  stop("VCG calls file missing column(s): ", paste(missing_calls, collapse = ", "), call. = FALSE)
}

tree <- ape::read.tree(tree_file)
tip_genome_id <- tip_to_genome_id(tree$tip.label)
manifest_match <- match(tip_genome_id, manifest$genome_id)
calls_match <- match(tip_genome_id, calls$genome_id)

tip_meta <- data.frame(
  plot_label = tree$tip.label,
  genome_id = tip_genome_id,
  best_vcg_call = calls$best_vcg_call[calls_match],
  source = manifest$source[manifest_match],
  group = manifest$group[manifest_match],
  stringsAsFactors = FALSE
)
tip_meta$best_vcg_call[is.na(tip_meta$best_vcg_call)] <- "not_reported"
tip_meta$source[is.na(tip_meta$source)] <- "unmatched_metadata"
tip_meta$group[is.na(tip_meta$group)] <- "unmatched_metadata"
tip_meta$is_buck <- grepl("^buck_", tip_meta$genome_id, ignore.case = TRUE)
tip_meta$is_highlight <- tip_meta$is_buck | grepl("^atcc_27562$", tip_meta$genome_id, ignore.case = TRUE)
tip_meta$display_id <- simplify_buck_label(tip_meta$genome_id)
tip_meta$display_label <- paste0(tip_meta$display_id, " (", tip_meta$best_vcg_call, ")")
tip_meta$display_label <- ifelse(tip_meta$is_highlight, paste0("*", tip_meta$display_label), tip_meta$display_label)

cat("\nUnmatched tree tips:\n")
unmatched <- tip_meta$plot_label[tip_meta$source == "unmatched_metadata"]
cat(if (length(unmatched) == 0) "  none\n" else paste0("  ", unmatched, collapse = "\n"), "\n", sep = "")

cat("\nTip count summary by source/group/vcg call:\n")
summary_counts <- aggregate(plot_label ~ source + group + best_vcg_call, data = tip_meta, FUN = length)
names(summary_counts)[names(summary_counts) == "plot_label"] <- "count"
print(summary_counts)

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

if (has_ggtree) {
  plot_data <- tip_meta
  rownames(plot_data) <- plot_data$plot_label
  tree_depth <- max(ape::node.depth.edgelength(tree))
  x_limit <- tree_depth * 1.75
  group_values <- sort(unique(plot_data$group))
  group_shapes <- setNames(rep(c(21, 22, 24, 23, 25), length.out = length(group_values)), group_values)
  attach_data <- get("%<+%", envir = asNamespace("ggtree"))
  p <- attach_data(ggtree::ggtree(tree, layout = "rectangular"), plot_data) +
    ggtree::geom_tiplab(
      ggplot2::aes(label = display_label, color = source, fontface = ifelse(is_highlight, "bold", "plain")),
      size = 2.5,
      align = TRUE,
      linetype = "dotted",
      linesize = 0.2,
      offset = tree_depth * 0.012
    ) +
    ggtree::geom_tippoint(ggplot2::aes(color = source, shape = group, fill = best_vcg_call), size = 2.4, stroke = 0.7) +
    ggplot2::scale_shape_manual(values = group_shapes) +
    ggplot2::xlim(0, x_limit) +
    ggplot2::labs(
      title = "Expanded V. vulnificus 46-genome vcg-marker FastTree",
      color = "Source",
      shape = "Group",
      fill = "VCG call"
    ) +
    ggtree::theme_tree2() +
    ggplot2::xlab(x_axis_label) +
    ggplot2::theme(
      legend.position = "right",
      plot.title = ggplot2::element_text(size = 12),
      axis.title.x = ggplot2::element_text(size = 10, margin = ggplot2::margin(t = 10)),
      axis.text.x = ggplot2::element_text(size = 8),
      plot.margin = ggplot2::margin(t = 12, r = 48, b = 34, l = 12)
    )
  ggplot2::ggsave(pdf_file, p, width = 15, height = 10, units = "in")
  ggplot2::ggsave(png_file, p, width = 15, height = 10, units = "in", dpi = 300)
} else {
  message("ggtree/ggplot2 unavailable; using ape fallback plot.")
  sources <- sort(unique(tip_meta$source))
  groups <- sort(unique(tip_meta$group))
  source_cols <- setNames(grDevices::rainbow(length(sources), s = 0.7, v = 0.75), sources)
  group_pch <- setNames(seq(21, length.out = length(groups)), groups)

  draw_ape_plot <- function() {
    tree_to_plot <- tree
    tree_to_plot$tip.label <- tip_meta$display_label
    tree_depth <- max(ape::node.depth.edgelength(tree_to_plot))
    op <- par(mar = c(4, 1, 3, 14), xpd = NA)
    on.exit(par(op), add = TRUE)
    ape::plot.phylo(
      tree_to_plot,
      type = "phylogram",
      cex = 0.55,
      label.offset = tree_depth * 0.01,
      tip.color = source_cols[tip_meta$source],
      font = ifelse(tip_meta$is_highlight, 2, 1),
      x.lim = c(0, tree_depth * 1.75),
      main = "Expanded V. vulnificus 46-genome vcg-marker FastTree"
    )
    ape::axisPhylo(cex = 0.7)
    mtext(x_axis_label, side = 1, line = 2.5, cex = 0.8)
    ape::tiplabels(pch = group_pch[tip_meta$group], col = "black", bg = source_cols[tip_meta$source], cex = 0.75)
    ape::add.scale.bar(cex = 0.7)
    legend("topright", inset = c(-0.36, 0), legend = sources, col = source_cols, pch = 19, cex = 0.65, title = "Source", bty = "n")
    legend("right", inset = c(-0.36, 0), legend = groups, pt.bg = "white", pch = group_pch, cex = 0.65, title = "Group", bty = "n")
    legend("bottomright", inset = c(-0.36, 0), legend = sort(unique(tip_meta$best_vcg_call)), cex = 0.65, title = "VCG call", bty = "n")
  }

  grDevices::pdf(pdf_file, width = 15, height = 10)
  draw_ape_plot()
  grDevices::dev.off()
  grDevices::png(png_file, width = 4500, height = 3000, res = 300)
  draw_ape_plot()
  grDevices::dev.off()
}

cat("\nOutput PDF:", pdf_file, "\n")
cat("Output PNG:", png_file, "\n")
