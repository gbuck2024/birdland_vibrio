#!/usr/bin/env Rscript

args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args_all[grepl(file_arg, args_all)])
if (length(script_path) == 0) {
  script_path <- "scripts/plot_expanded_vv_raxml_tree.R"
}

trailing_args <- commandArgs(trailingOnly = TRUE)
root_atcc <- "--root-atcc" %in% trailing_args

script_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
project_dir <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)

tree_file <- file.path(project_dir, "phylogeny", "expanded_vv_46", "tree", "raxmlng", "expanded_vv_46.raxml.support")
metadata_file <- file.path(project_dir, "configs", "expanded_vv_46_genome_manifest.tsv")
vcg_file <- file.path(project_dir, "vcg_mining", "results", "vcg_best_hits_summary.tsv")
out_dir <- file.path(project_dir, "phylogeny", "expanded_vv_46", "tree", "raxmlng")
pdf_file <- file.path(out_dir, "expanded_vv_46_raxml_tree.pdf")
png_file <- file.path(out_dir, "expanded_vv_46_raxml_tree.png")

missing_required <- character()
for (pkg in c("ape")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    missing_required <- c(missing_required, pkg)
  }
}
if (length(missing_required) > 0) {
  stop("Missing required R package(s): ", paste(missing_required, collapse = ", "), call. = FALSE)
}

has_ggtree <- requireNamespace("ggtree", quietly = TRUE) &&
  requireNamespace("ggplot2", quietly = TRUE)

if (!file.exists(tree_file) || file.info(tree_file)$size == 0) {
  stop("Input tree is missing or empty: ", tree_file, call. = FALSE)
}
if (!file.exists(metadata_file) || file.info(metadata_file)$size == 0) {
  stop("Input metadata is missing or empty: ", metadata_file, call. = FALSE)
}

read_tsv <- function(path) {
  read.delim(path, sep = "\t", header = TRUE, stringsAsFactors = FALSE, check.names = FALSE)
}

clean_tree_id <- function(x) {
  x <- sub("\\.fna\\.ref$", "", x)
  x <- sub("\\.fna$", "", x)
  x
}

clean_unique_tree_id <- function(x) {
  sub("__dup[0-9]+$", "", x)
}

canonical_buck_id <- function(x) {
  lower <- tolower(x)
  lower <- sub("^buck_", "buck_", lower)
  parts <- strsplit(lower, "_", fixed = TRUE)
  vapply(parts, function(p) {
    if (length(p) >= 4 && p[1] == "buck") {
      paste(p[c(1, 2, 3, length(p))], collapse = "_")
    } else {
      paste(p, collapse = "_")
    }
  }, character(1))
}

simplify_buck_label <- function(x) {
  # Buck assembly filenames include project and coverage tokens that are useful
  # for file tracking but too verbose for a publication figure.
  replacements <- c(
    buck_BS0607_9_50x = "BS0607_9",
    buck_CB0707_82_25x = "CB0707_82",
    buck_NB0507_8_100x = "NB0507_8"
  )
  ifelse(x %in% names(replacements), replacements[x], x)
}

parse_source <- function(reference_id, reference_format, notes) {
  source <- rep("not_reported", length(reference_id))
  source[grepl("^buck_", reference_id, ignore.case = TRUE)] <- "Buck"
  source[grepl("^atcc_27562$", reference_id, ignore.case = TRUE)] <- "ATCC 27562"
  has_source <- grepl("Source:", notes, ignore.case = TRUE)
  source[has_source] <- sub("^.*Source:[[:space:]]*([^.;]+).*$", "\\1", notes[has_source], ignore.case = TRUE)
  source
}

parse_group <- function(reference_id, reference_format) {
  group <- reference_format
  group[grepl("mullis2019", reference_format, ignore.case = TRUE)] <- "Mullis 2019"
  group[grepl("^buck_", reference_id, ignore.case = TRUE)] <- "Buck isolate"
  group[grepl("^atcc_27562$", reference_id, ignore.case = TRUE)] <- "ATCC reference"
  group
}

metadata <- read_tsv(metadata_file)
if (!"genome_id" %in% names(metadata) && "reference_id" %in% names(metadata)) {
  metadata$genome_id <- metadata$reference_id
  message("Metadata does not contain genome_id; using reference_id as genome_id.")
}

required_cols <- c("genome_id", "reference_format", "notes")
missing_cols <- setdiff(required_cols, names(metadata))
if (length(missing_cols) > 0) {
  stop("Metadata is missing required column(s): ", paste(missing_cols, collapse = ", "), call. = FALSE)
}

metadata$tree_id <- metadata$genome_id
metadata$source <- if ("source" %in% names(metadata)) metadata$source else parse_source(metadata$genome_id, metadata$reference_format, metadata$notes)
metadata$group <- if ("group" %in% names(metadata)) metadata$group else parse_group(metadata$genome_id, metadata$reference_format)
metadata$vcg_status <- if ("vcg_status" %in% names(metadata)) metadata$vcg_status else "not_reported"

if (file.exists(vcg_file) && file.info(vcg_file)$size > 0) {
  vcg <- read_tsv(vcg_file)
  if (all(c("sample_id", "best_hit_found", "qseqid") %in% names(vcg))) {
    vcg$tree_id <- canonical_buck_id(vcg$sample_id)
    vcg$vcg_status <- ifelse(
      vcg$best_hit_found == "yes",
      ifelse(vcg$qseqid == "AY626578.1", "vcgC",
        ifelse(vcg$qseqid == "AY626579.1", "vcgE", vcg$qseqid)
      ),
      "no_vcg_hit"
    )
    matched_vcg <- vcg$vcg_status[match(tolower(metadata$tree_id), vcg$tree_id)]
    metadata$vcg_status <- ifelse(is.na(matched_vcg), metadata$vcg_status, matched_vcg)
  } else {
    warning("VCG summary exists but lacks sample_id, best_hit_found, or qseqid columns: ", vcg_file)
  }
}

tree <- ape::read.tree(tree_file)
tree_match_id <- clean_tree_id(tree$tip.label)
tree$tip.label <- make.unique(tree_match_id, sep = "__dup")

if (root_atcc) {
  atcc_tip <- tree$tip.label[tree_match_id == "atcc_27562"]
  if (length(atcc_tip) >= 1) {
    tree <- ape::root(tree, outgroup = atcc_tip[1], resolve.root = TRUE)
    message("Rooted tree on ATCC 27562 by request.")
  } else {
    warning("Could not safely root on ATCC 27562; leaving tree unrooted.")
  }
}
tree_match_id <- clean_unique_tree_id(tree$tip.label)

matched_index <- match(tree_match_id, metadata$tree_id)
tip_meta <- metadata[matched_index, , drop = FALSE]
unmatched_tree_tips <- tree$tip.label[is.na(matched_index)]
unmatched_metadata_rows <- metadata$tree_id[!metadata$tree_id %in% tree_match_id]

cat("\nUnmatched tree tips:\n")
if (length(unmatched_tree_tips) == 0) {
  cat("  none\n")
} else {
  cat("  ", paste(unmatched_tree_tips, collapse = "\n  "), "\n", sep = "")
}

cat("\nMetadata rows not found in tree:\n")
if (length(unmatched_metadata_rows) == 0) {
  cat("  none\n")
} else {
  cat("  ", paste(unmatched_metadata_rows, collapse = "\n  "), "\n", sep = "")
}

if (all(is.na(matched_index))) {
  stop("No tree tip labels matched metadata genome_id values.", call. = FALSE)
}

if (length(unmatched_tree_tips) > 0) {
  tip_meta$tree_id[is.na(matched_index)] <- unmatched_tree_tips
  tip_meta$genome_id[is.na(matched_index)] <- unmatched_tree_tips
  tip_meta$source[is.na(matched_index)] <- "unmatched_metadata"
  tip_meta$group[is.na(matched_index)] <- "unmatched_metadata"
  tip_meta$vcg_status[is.na(matched_index)] <- "not_reported"
}

tip_meta$is_highlight <- grepl("^buck_", tip_meta$tree_id, ignore.case = TRUE) | tip_meta$tree_id == "atcc_27562"
tip_meta$plot_label <- tree$tip.label
tip_meta$display_id <- tree_match_id
tip_meta$display_id <- simplify_buck_label(tip_meta$display_id)
duplicate_match_id <- duplicated(tree_match_id) | duplicated(tree_match_id, fromLast = TRUE)
tip_meta$display_id[duplicate_match_id] <- paste0(tip_meta$display_id[duplicate_match_id], " [", tip_meta$plot_label[duplicate_match_id], "]")
tip_meta$display_label <- ifelse(tip_meta$is_highlight, paste0("*", tip_meta$display_id), tip_meta$display_id)
tip_meta$display_label <- ifelse(
  tip_meta$vcg_status != "not_reported",
  paste0(tip_meta$display_label, " (", tip_meta$vcg_status, ")"),
  tip_meta$display_label
)

cat("\nMetadata count summary by source/group/vcg_status:\n")
summary_counts <- aggregate(
  tree_id ~ source + group + vcg_status,
  data = tip_meta,
  FUN = length
)
names(summary_counts)[names(summary_counts) == "tree_id"] <- "count"
print(summary_counts)

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

if (has_ggtree) {
  plot_data <- cbind(plot_label = tip_meta$plot_label, tip_meta[, setdiff(names(tip_meta), "plot_label"), drop = FALSE])
  rownames(plot_data) <- plot_data$plot_label
  group_values <- sort(unique(plot_data$group))
  group_shapes <- setNames(rep(c(21, 22, 24, 23, 25), length.out = length(group_values)), group_values)
  tree_depth <- max(ape::node.depth.edgelength(tree))
  # Extra x-axis room prevents right-side tip labels from being clipped and
  # creates separation between aligned labels and the legend block.
  x_limit <- tree_depth * 2.35
  ggtree_attach_data <- get("%<+%", envir = asNamespace("ggtree"))
  p <- ggtree_attach_data(ggtree::ggtree(tree, layout = "rectangular"), plot_data) +
    ggtree::geom_tiplab(
      ggplot2::aes(label = display_label, color = source, fontface = ifelse(is_highlight, "bold", "plain")),
      size = 2.5,
      align = TRUE,
      linetype = "dotted",
      linesize = 0.2,
      offset = tree_depth * 0.015
    ) +
    ggtree::geom_tippoint(ggplot2::aes(color = source, shape = group, fill = vcg_status), size = 2.4, stroke = 0.7) +
    ggplot2::scale_shape_manual(values = group_shapes) +
    ggplot2::xlim(0, x_limit) +
    ggplot2::labs(
      title = "Expanded V. vulnificus 46-genome RAxML-NG support tree",
      # Branch lengths are measured as expected substitutions per nucleotide site.
      x = "Evolutionary distance (substitutions per site)",
      color = "Source",
      shape = "Group",
      fill = "VCG status"
    ) +
    ggtree::theme_tree2() +
    ggplot2::theme(
      legend.position = "right",
      legend.box.margin = ggplot2::margin(0, 0, 0, 24),
      plot.title = ggplot2::element_text(size = 12),
      legend.text = ggplot2::element_text(size = 8),
      axis.title.x = ggplot2::element_text(size = 10, margin = ggplot2::margin(t = 8)),
      # Wider outer margins preserve label and legend whitespace in exported files.
      plot.margin = ggplot2::margin(t = 12, r = 48, b = 14, l = 12)
    )

  ggplot2::ggsave(pdf_file, p, width = 15, height = 10, units = "in")
  ggplot2::ggsave(png_file, p, width = 15, height = 10, units = "in", dpi = 300)
} else {
  message("ggtree/ggplot2 unavailable; using ape fallback plot.")
  sources <- sort(unique(tip_meta$source))
  groups <- sort(unique(tip_meta$group))
  vcg_statuses <- sort(unique(tip_meta$vcg_status))
  source_cols <- setNames(grDevices::rainbow(length(sources), s = 0.7, v = 0.75), sources)
  group_pch <- setNames(seq(21, length.out = length(groups)), groups)
  label_cols <- source_cols[tip_meta$source]
  label_font <- ifelse(tip_meta$is_highlight, 2, 1)

  draw_ape_plot <- function() {
    tree_to_plot <- tree
    tree_to_plot$tip.label <- tip_meta$display_label
    tree_depth <- max(ape::node.depth.edgelength(tree_to_plot))
    x_limit <- tree_depth * 2.35
    # The right margin is deliberately broad so long tip labels and legends
    # remain visible in static PDF/PNG exports.
    op <- par(mar = c(4, 1, 3, 14), xpd = NA)
    on.exit(par(op), add = TRUE)
    ape::plot.phylo(
      tree_to_plot,
      type = "phylogram",
      cex = 0.55,
      label.offset = 0.002,
      tip.color = label_cols,
      font = label_font,
      no.margin = FALSE,
      x.lim = c(0, x_limit),
      main = "Expanded V. vulnificus 46-genome RAxML-NG support tree"
    )
    # Branch length units represent expected nucleotide substitutions per site.
    ape::axisPhylo(cex = 0.7)
    mtext("Evolutionary distance (substitutions per site)", side = 1, line = 2.5, cex = 0.8)
    ape::tiplabels(
      pch = group_pch[tip_meta$group],
      col = "black",
      bg = label_cols,
      cex = 0.75,
      adj = c(0.5, 0.5)
    )
    ape::add.scale.bar(cex = 0.7)
    legend("topright", inset = c(-0.36, 0), legend = sources, col = source_cols, pch = 19, cex = 0.65, title = "Source", bty = "n")
    legend("right", inset = c(-0.36, 0), legend = groups, pt.bg = "white", pch = group_pch, cex = 0.65, title = "Group", bty = "n")
    legend("bottomright", inset = c(-0.36, 0), legend = vcg_statuses, cex = 0.65, title = "VCG status", bty = "n")
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
