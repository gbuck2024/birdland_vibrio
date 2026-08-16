#!/usr/bin/env Rscript

args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args_all[grepl(file_arg, args_all)])
if (length(script_path) == 0) {
  script_path <- "scripts/plot_fastani_matrix_heatmap.R"
}

script_dir <- dirname(normalizePath(script_path, mustWork = TRUE))
project_dir <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)

stage_dir <- Sys.getenv("STAGE_DIR", file.path("ani", "reference_panel_plus_unknown_matrix"))
stage_path <- if (grepl("^/", stage_dir)) stage_dir else file.path(project_dir, stage_dir)
metrics_dir <- file.path(stage_path, "metrics")
figures_dir <- file.path(stage_path, "figures")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

matrix_file <- Sys.getenv("ANI_MATRIX_FILE", file.path(metrics_dir, "fastani_genome_matrix.tsv"))
af_matrix_file <- Sys.getenv("AF_MATRIX_FILE", file.path(metrics_dir, "fastani_alignment_fraction_matrix.tsv"))
af_threshold <- as.numeric(Sys.getenv("AF_THRESHOLD", "0.50"))
query_manifest_file <- Sys.getenv("QUERY_METADATA_FILE", file.path(metrics_dir, "query_manifest.normalized.tsv"))
reference_manifest_file <- Sys.getenv("REFERENCE_METADATA_FILE", file.path(metrics_dir, "reference_manifest.normalized.tsv"))
prefix <- Sys.getenv("HEATMAP_PREFIX", basename(normalizePath(stage_path, mustWork = FALSE)))
unknown_ids <- strsplit(Sys.getenv(
  "UNKNOWN_IDS",
  paste(
    "Buck_BI0607_1_WKDL250009588-1A_233TFCLT4_L7",
    "Buck_BI0607_2_WKDL250009588-1A_233TFCLT4_L7",
    "Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7",
    "Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7",
    "Buck_NB0507_14_WKDL250009588-1A_233TFCLT4_L7",
    "Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7",
    sep = ","
  )
), ",", fixed = TRUE)[[1]]
unknown_ids <- trimws(unknown_ids[nzchar(trimws(unknown_ids))])

if (!file.exists(matrix_file) || file.info(matrix_file)$size == 0) {
  stop("ANI matrix is missing or empty: ", matrix_file, call. = FALSE)
}
if (!file.exists(query_manifest_file) || file.info(query_manifest_file)$size == 0) {
  stop("Query metadata is missing or empty: ", query_manifest_file, call. = FALSE)
}
if (!file.exists(reference_manifest_file) || file.info(reference_manifest_file)$size == 0) {
  stop("Reference metadata is missing or empty: ", reference_manifest_file, call. = FALSE)
}
if (!is.finite(af_threshold) || af_threshold < 0 || af_threshold > 1) {
  stop("AF_THRESHOLD must be a number from 0 to 1.", call. = FALSE)
}

read_tsv <- function(path) {
  read.delim(path, sep = "\t", header = TRUE, stringsAsFactors = FALSE, check.names = FALSE)
}

short_label <- function(x) {
  x <- sub("^mullis2019_", "M", x)
  x <- sub("^Buck_", "Buck_", x)
  x <- gsub("_WKDL250009588-1A_233TFCLT4_L7", "", x, fixed = TRUE)
  x
}

read_matrix <- function(path) {
  tab <- read_tsv(path)
  if (ncol(tab) < 2) {
    stop("ANI matrix must contain one ID column and at least one value column: ", path, call. = FALSE)
  }
  row_ids <- tab[[1]]
  value_tab <- tab[, -1, drop = FALSE]
  mat <- as.matrix(value_tab)
  storage.mode(mat) <- "numeric"
  rownames(mat) <- row_ids
  colnames(mat) <- colnames(value_tab)
  mat
}

metadata_order <- function(ids, metadata) {
  metadata <- metadata[match(ids, metadata$genome_id), , drop = FALSE]
  metadata$genome_id[is.na(metadata$genome_id)] <- ids[is.na(metadata$genome_id)]
  metadata$species[is.na(metadata$species)] <- "unknown"
  metadata$is_unknown[is.na(metadata$is_unknown)] <- ifelse(ids[is.na(metadata$is_unknown)] %in% unknown_ids, "yes", "no")
  order(metadata$species, metadata$is_unknown != "yes", metadata$genome_id)
}

draw_heatmap <- function(mat, query_meta, ref_meta, output_stem, title_text, af_mat = NULL) {
  row_order <- metadata_order(rownames(mat), query_meta)
  col_order <- metadata_order(colnames(mat), ref_meta)
  mat <- mat[row_order, col_order, drop = FALSE]
  if (!is.null(af_mat)) {
    if (!setequal(rownames(mat), rownames(af_mat)) || !setequal(colnames(mat), colnames(af_mat))) {
      stop("AF matrix row/column IDs do not match ANI matrix IDs.", call. = FALSE)
    }
    af_mat <- af_mat[rownames(mat), colnames(mat), drop = FALSE]
  }

  query_meta <- query_meta[match(rownames(mat), query_meta$genome_id), , drop = FALSE]
  ref_meta <- ref_meta[match(colnames(mat), ref_meta$genome_id), , drop = FALSE]

  query_unknown <- rownames(mat) %in% unknown_ids | query_meta$is_unknown == "yes"
  ref_unknown <- colnames(mat) %in% unknown_ids | ref_meta$is_unknown == "yes"

  plot_mat <- mat
  plot_mat[is.na(plot_mat)] <- 0
  plot_mat[plot_mat < 0] <- 0
  plot_mat[plot_mat > 100] <- 100
  low_af <- matrix(FALSE, nrow = nrow(plot_mat), ncol = ncol(plot_mat), dimnames = dimnames(plot_mat))
  if (!is.null(af_mat)) {
    low_af <- is.na(af_mat) | af_mat < af_threshold
  }

  n_rows <- nrow(plot_mat)
  n_cols <- ncol(plot_mat)
  row_cex <- max(0.25, min(0.75, 13 / max(n_rows, 1)))
  col_cex <- max(0.25, min(0.75, 16 / max(n_cols, 1)))
  width_in <- max(8, min(28, 3 + n_cols * 0.18))
  height_in <- max(6, min(28, 3 + n_rows * 0.18))

  draw_one <- function() {
    layout(matrix(c(1, 2), nrow = 1), widths = c(5, 1))
    par(mar = c(8, 10, 4, 1))
    colors <- colorRampPalette(c("blue", "white", "red"))(101)
    image(
      x = seq_len(n_cols),
      y = seq_len(n_rows),
      z = t(plot_mat[n_rows:1, , drop = FALSE]),
      col = colors,
      zlim = c(0, 100),
      axes = FALSE,
      xlab = "",
      ylab = "",
      main = title_text
    )
    box()

    if (any(low_af)) {
      low_af_plot <- low_af[n_rows:1, , drop = FALSE]
      for (i in seq_len(n_rows)) {
        for (j in seq_len(n_cols)) {
          if (low_af_plot[i, j]) {
            rect(j - 0.5, i - 0.5, j + 0.5, i + 0.5, col = "gray82", border = NA)
          }
        }
      }
      rect(0.5, 0.5, n_cols + 0.5, n_rows + 0.5, border = "gray55", lwd = 0.5)
    }

    display_rows <- rev(seq_len(n_rows))
    row_labels <- short_label(rownames(plot_mat))
    col_labels <- short_label(colnames(plot_mat))

    text(
      x = par("usr")[1] - 0.15,
      y = seq_len(n_rows),
      labels = rev(row_labels),
      adj = 1,
      xpd = NA,
      cex = row_cex,
      col = ifelse(rev(query_unknown), "black", "gray20"),
      font = ifelse(rev(query_unknown), 2, 1)
    )
    text(
      x = seq_len(n_cols),
      y = par("usr")[3] - 0.15,
      labels = col_labels,
      srt = 90,
      adj = 1,
      xpd = NA,
      cex = col_cex,
      col = ifelse(ref_unknown, "black", "gray20"),
      font = ifelse(ref_unknown, 2, 1)
    )

    row_species <- query_meta$species
    row_breaks <- which(row_species[-1] != row_species[-length(row_species)])
    for (b in row_breaks) {
      y <- n_rows - b + 0.5
      segments(0.5, y, n_cols + 0.5, y, col = "gray30", lwd = 0.7)
    }
    col_species <- ref_meta$species
    col_breaks <- which(col_species[-1] != col_species[-length(col_species)])
    for (b in col_breaks) {
      x <- b + 0.5
      segments(x, 0.5, x, n_rows + 0.5, col = "gray30", lwd = 0.7)
    }

    for (i in which(query_unknown)) {
      y <- n_rows - i + 1
      rect(0.5, y - 0.5, n_cols + 0.5, y + 0.5, border = "black", lwd = 1.4)
    }
    for (j in which(ref_unknown)) {
      rect(j - 0.5, 0.5, j + 0.5, n_rows + 0.5, border = "black", lwd = 1.4)
    }

    par(mar = c(8, 2, 4, 4))
    image(
      x = 1,
      y = seq(0, 100, length.out = 101),
      z = matrix(seq(0, 100, length.out = 101), ncol = 101),
      col = colors,
      zlim = c(0, 100),
      axes = FALSE,
      xlab = "",
      ylab = ""
    )
    axis(4, at = c(0, 80, 90, 95, 100), labels = c("0/NA", "80", "90", "95", "100"), las = 1)
    mtext("ANI (%)", side = 4, line = 2.5)
    if (!is.null(af_mat)) {
      rect(0.62, -16, 1.38, -9, col = "gray82", border = "gray55", xpd = NA)
      mtext(paste0("Gray: AF < ", sprintf("%.2f", af_threshold)), side = 1, line = 4.5, cex = 0.75)
    }
  }

  pdf_file <- file.path(figures_dir, paste0(output_stem, ".pdf"))
  png_file <- file.path(figures_dir, paste0(output_stem, ".png"))

  pdf(pdf_file, width = width_in, height = height_in)
  draw_one()
  dev.off()

  png(png_file, width = width_in, height = height_in, units = "in", res = 220)
  draw_one()
  dev.off()

  cat("Output PDF:", pdf_file, "\n")
  cat("Output PNG:", png_file, "\n")
}

query_meta <- read_tsv(query_manifest_file)
ref_meta <- read_tsv(reference_manifest_file)
mat <- read_matrix(matrix_file)
af_mat <- NULL
if (file.exists(af_matrix_file) && file.info(af_matrix_file)$size > 0) {
  af_mat <- read_matrix(af_matrix_file)
} else {
  warning("AF matrix is missing or empty; heatmap will not gray low-AF cells: ", af_matrix_file, call. = FALSE)
}

required_meta <- c("genome_id", "species", "is_unknown")
missing_query <- setdiff(required_meta, names(query_meta))
missing_ref <- setdiff(required_meta, names(ref_meta))
if (length(missing_query) > 0) {
  stop("Query metadata missing column(s): ", paste(missing_query, collapse = ", "), call. = FALSE)
}
if (length(missing_ref) > 0) {
  stop("Reference metadata missing column(s): ", paste(missing_ref, collapse = ", "), call. = FALSE)
}

draw_heatmap(
  mat,
  query_meta,
  ref_meta,
  paste0(prefix, "_genome_heatmap"),
  paste0("fastANI genome matrix (AF >= ", sprintf("%.2f", af_threshold), " colored)"),
  af_mat
)

species_max_file <- file.path(metrics_dir, "fastani_species_max_matrix.tsv")
if (file.exists(species_max_file) && file.info(species_max_file)$size > 0) {
  species_mat <- read_matrix(species_max_file)
  species_meta <- data.frame(
    genome_id = union(rownames(species_mat), colnames(species_mat)),
    species = union(rownames(species_mat), colnames(species_mat)),
    is_unknown = ifelse(union(rownames(species_mat), colnames(species_mat)) == "unknown", "yes", "no"),
    stringsAsFactors = FALSE
  )
  draw_heatmap(species_mat, species_meta, species_meta, paste0(prefix, "_species_max_heatmap"), "fastANI species max matrix")
}
