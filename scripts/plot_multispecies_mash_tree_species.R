#!/usr/bin/env Rscript
# Replot a completed Mash/NJ tree without recomputing it. Reference colors are
# manifest species; Buck and SRR assemblies retain distinct sample colors.
args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 4L) stop('Usage: Rscript plot_multispecies_mash_tree_species.R PANEL REFERENCE_MANIFEST TREE OUTPUT_DIR')
if (!requireNamespace('ape', quietly=TRUE)) stop('R package ape is required')
panel <- read.delim(args[1], check.names=FALSE, stringsAsFactors=FALSE)
refs <- read.delim(args[2], check.names=FALSE, stringsAsFactors=FALSE)
tree <- ape::read.tree(args[3])
out <- args[4]
if (!all(c('genome_id','source_group','display_label') %in% names(panel)) ||
    !all(c('reference_id','notes') %in% names(refs))) stop('Input manifest columns are missing')
if (nrow(panel) != 87L || anyDuplicated(panel$genome_id) ||
    anyDuplicated(panel$display_label) || !setequal(tree$tip.label,panel$genome_id) ||
    ape::is.rooted(tree)) stop('Panel/tree IDs are missing, duplicated, or tree is rooted')
if (any(!panel$source_group %in% c('NCBI reference','Mullis reference','Buck isolate','SRR isolate'))) stop('Unknown source group')
if (dir.exists(out) && length(list.files(out, all.files=TRUE, no..=TRUE))) stop('Output directory is not empty: ',out)
if (!dir.exists(out) && !dir.create(out, recursive=TRUE)) stop('Cannot create output directory: ',out)

ref_idx <- match(panel$genome_id, refs$reference_id)
ncbi <- panel$source_group == 'NCBI reference'
if (anyNA(ref_idx[ncbi])) stop('NCBI reference absent from reference manifest')
species <- rep(NA_character_,nrow(panel))
species[panel$source_group == 'Mullis reference'] <- 'V. vulnificus'
notes <- refs$notes[ref_idx[ncbi]]
match_species <- regmatches(notes, regexpr('Vibrio [[:alpha:]]+',notes))
if (any(!nzchar(match_species))) stop('NCBI species missing from reference notes')
species[ncbi] <- sub('Vibrio ','V. ',match_species,fixed=TRUE)
known <- c('V. alginolyticus','V. cidicii','V. diabolicus','V. navarrensis',
           'V. ostreicida','V. parahaemolyticus','V. vulnificus')
if (!setequal(unique(species[!is.na(species)]),known)) stop('Unexpected reference species')
palette <- c('V. alginolyticus'='#C77C00','V. cidicii'='#7B61A8',
             'V. diabolicus'='#238B73','V. navarrensis'='#B65D8C',
             'V. ostreicida'='#7B8441','V. parahaemolyticus'='#3465B4',
             'V. vulnificus'='#805323')
color <- unname(palette[species])
color[panel$source_group == 'Buck isolate'] <- '#D43F3A'
color[panel$source_group == 'SRR isolate'] <- '#176BB3'
pch <- c('NCBI reference'=22L,'Mullis reference'=23L,'Buck isolate'=21L,'SRR isolate'=24L)[panel$source_group]
ord <- match(tree$tip.label,panel$genome_id)
project <- which(panel$source_group[ord] %in% c('Buck isolate','SRR isolate'))
if (length(project) != 11L || anyNA(color) || anyNA(pch)) stop('Expected 11 project tips and complete styling')
map <- data.frame(genome_id=panel$genome_id,source_group=panel$source_group,
                  reference_species=ifelse(is.na(species),'',species),
                  plotted_color=color,plotted_shape=pch)
write.table(map,file=file.path(out,'tip_style.tsv'),sep='\t',quote=FALSE,row.names=FALSE)

draw <- function() {
  par(mar=c(2,2,3,2),xpd=NA)
  ape::plot.phylo(tree,type='unrooted',show.tip.label=FALSE,edge.width=0.8,
                  no.margin=FALSE)
  ape::tiplabels(pch=pch[ord],bg=color[ord],col=color[ord],cex=0.65)
  xy <- get('last_plot.phylo',envir=ape::.PlotPhyloEnv)
  xrange <- diff(range(xy$xx)); yrange <- diff(range(xy$yy))
  middle <- mean(range(xy$xx))
  label_y <- xy$yy[project]
  side <- ifelse(xy$xx[project] < middle,-1,1)
  for (direction in c(-1,1)) {
    ids <- which(side == direction)
    ids <- ids[order(label_y[ids])]
    if (length(ids) > 1L) for (z in 2:length(ids)) {
      label_y[ids[z]] <- max(label_y[ids[z]],label_y[ids[z-1L]]+0.028*yrange)
    }
  }
  label_x <- xy$xx[project]+side*0.024*xrange
  segments(xy$xx[project],xy$yy[project],label_x,label_y,col=color[ord][project],lwd=0.7)
  text(label_x,label_y,labels=panel$display_label[ord][project],
       adj=ifelse(side < 0,1,0),col=color[ord][project],cex=0.7,font=2)
  title('Vibrio genome distances | Mash neighbor joining',cex.main=1.1)
  legend('topleft',legend=names(palette),pch=22,pt.bg=unname(palette),
         col=unname(palette),title='Reference species',bty='n',cex=0.82)
  legend('topright',legend=c('Buck assembly','SRR assembly','Mullis reference'),
         pch=c(21,24,23),pt.bg=c('#D43F3A','#176BB3',unname(palette['V. vulnificus'])),
         col=c('#D43F3A','#176BB3',unname(palette['V. vulnificus'])),
         title='Tip shapes',bty='n',cex=0.82)
  mtext('Unrooted exploratory Mash distance tree; only Buck and SRR tips are labeled',
        side=1,line=0.5,cex=0.75)
}
pdf(file.path(out,'unrooted_mash_nj_species.pdf'),width=16,height=13,onefile=FALSE)
draw(); dev.off()
png(file.path(out,'unrooted_mash_nj_species.png'),width=3200,height=2600,res=200)
draw(); dev.off()
svg(file.path(out,'unrooted_mash_nj_species.svg'),width=16,height=13)
draw(); dev.off()
