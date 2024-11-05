#!/usr/bin/env Rscript

library(tidyverse)
library(Seurat)
library(igraph)
library(dcanr)


filename_sample_1 <- "${sample_rds[0]}"
filename_sample_2 <- "${sample_rds[1]}"

## Potential bug?:
## Replacing "_" with "." because Seurat can't handle "_" in gene names
## Normally, as.Seurat() automatically replaces "_" with "-" in gene names. However, this introduces duplicates in the gene names and this causes an error.
data_sample_1 <- readRDS(filename_sample_1)
rownames(data_sample_1) <- sub("_", ".", rownames(data_sample_1))
data_sample_1 <- as.Seurat(data_sample_1, data = NULL)

data_sample_2 <- readRDS(filename_sample_2)
rownames(data_sample_2) <- sub("_", ".", rownames(data_sample_2))
data_sample_2 <- as.Seurat(data_sample_2, data = NULL)

condition_sample_1 <- tools::file_path_sans_ext(basename(filename_sample_1))
condition_sample_2 <- tools::file_path_sans_ext(basename(filename_sample_2))

conditions <- c(rep(1, times=ncol(data_sample_1)), rep(2, times=ncol(data_sample_2)))
names(conditions) <- c(paste0('1_', colnames(data_sample_1)), paste0('2_',colnames(data_sample_2)))

## reduce number of genes due to computational complexity
n_genes <- 15000
if (nrow(data_sample_1) > n_genes) {
    data_sample_1 <- NormalizeData(data_sample_1)
    data_sample_1 <- FindVariableFeatures(data_sample_1, selection.method = "vst", nfeatures = n_genes)
    data_sample_1 <- data_sample_1[head(VariableFeatures(data_sample_1), n_genes),]
}
if (nrow(data_sample_2) > n_genes) {
    data_sample_2 <- NormalizeData(data_sample_2)
    data_sample_2 <- FindVariableFeatures(data_sample_2, selection.method = "vst", nfeatures = n_genes)
    data_sample_2 <- data_sample_2[head(VariableFeatures(data_sample_2), n_genes),]
}
gene_intersection <- rownames(data_sample_1)[which(rownames(data_sample_1) %in% rownames(data_sample_2))]
data_sample_1 <- data_sample_1[gene_intersection,]
data_sample_2 <- data_sample_2[gene_intersection,]

## perform zscore computation
data <- cbind(data_sample_1[['originalexp']]['counts'], data_sample_2[['originalexp']]['counts'])
z_scores <- dcScore(data, conditions, dc.method = 'zscore', cor.method = 'spearman')
raw_p <- dcTest(z_scores, data, conditions)
adj_p <- dcAdjust(raw_p, f = p.adjust, method = 'fdr')
dcnet <- dcNetwork(z_scores, adj_p)
edgedf <- as_data_frame(dcnet, what = 'edges')
## renaming columns from ('from', 'to', 'score', 'color') to ('node_1', 'node_2', 'score', 'color') to remove unclarities due to the column names as the method is undirected
colnames(edgedf) <- c('node_1', 'node_2', 'score', 'color')
edgedf['condition'] <- c(ifelse(edgedf['score'] >= 0, condition_sample_1, condition_sample_2))

write_csv(edgedf, "${prefix}.csv")

################################################
################################################
## VERSIONS FILE                              ##
################################################
################################################

r.version <- strsplit(version[['version.string']], ' ')[[1]][3]
seurat.version <- as.character(packageVersion('Seurat'))
tidyverse.version <- as.character(packageVersion('tidyverse'))
igraph.version <- as.character(packageVersion('igraph'))
dcanr.version <- as.character(packageVersion('dcanr'))

writeLines(
    c(
        '"${task.process}":',
        paste('    R:', r.version),
        paste('    Seurat:', seurat.version),
        paste('    tidyverse:', tidyverse.version),
        paste('    igraph:', igraph.version),
        paste('    dcanr:', dcanr.version)
    ),
'versions.yml')

################################################
################################################
################################################
################################################