library(tidyverse)
source("R/utils.R")
Rcpp::sourceCpp("R/js.cpp")

### input and output directories, modify as necessary
args <- commandArgs(trailingOnly = TRUE)

dir_in <- Sys.getenv("INPUT_DIR")
dir_out <- Sys.getenv("OUTPUT_DIR")

dir.create(paste0(dir_out, "/QC_all"))
dir.create(paste0(dir_out, "/QC_controls"))


### read file containing metadata for cohort of interest
# path_to_meta <- paste0(dir_in,"/metadata.csv")
# meta <- read_csv(path_to_meta, col_types=cols()) 

### select metadata column to highlight in plots 
### (later we could pass as parameter)
# col <- "Visit"


### assemble table of all features present in input dirs
files_ada <- list.files(dir_in, pattern="feat_adaptive", recursive = TRUE)
files_maj <- str_replace_all(files_ada, "adaptive", "major")

df_feat_list <- Map(read_features, 
                    paste0(dir_in, "/", files_ada), 
                    paste0(dir_in, "/", files_maj)) 

df_feat <- df_feat_list %>%
  do.call(what=plyr::rbind.fill) %>%
  as_tibble() %>%
  select(!matches("out of")) %>%
  replace(is.na(.), 0)

feat_names <- names(df_feat %>% select(-file))
  

# ### build umap dimensional reduction
# set.seed(0)
# mat <- df_feat %>% select(where(is.numeric)) %>% as.matrix() %>% scale()
# um <- uwot::umap(mat, min_dist = 0.2, n_neighbors = 7)
# 
# df_feat_aug <- df_feat %>%
#   mutate(umap1 = um[,1], umap2 = um[,2]) %>%
#   left_join(meta)


### make and save plots
# 
# p <- plot_umap_color_metadata(df_feat_aug, col = col)
# ggsave(p, filename=paste0(dir_out, "/umap.png"), width=12, height=9)
# 
# p <- plot_box(df_feat_aug, feat_names, col)
# ggsave(p, filename=paste0(dir_out, "/boxplots.png"), width=12, height=9)
# 
# p <- plot_lasso(df_feat_aug, feat_names, col)
# ggsave(p, filename=paste0(dir_out, "/lasso.png"), width=12, height=4)

# for interim report only: file-wise bar charts
# WARNING: scales poorly with number of samples, only use with up to 20
feat_major <- feat_names[which(!grepl("T cell |NK cell |B cell |Monocyte ", feat_names))]
p <- plot_proportions_bar(df_feat, feat_major, major=TRUE)
ggsave(p, filename=paste0(dir_out, "/proportions_bar_major.png"), width=12, height=8)

feat_cd4 <- feat_names[grep("T cell CD4", feat_names)]
p <- plot_proportions_bar(df_feat, feat_cd4)
ggsave(p, filename=paste0(dir_out, "/proportions_bar_cd4.png"), width=12, height=12)

feat_cd8_nk <- feat_names[grep("T cell CD8|NK cell ", feat_names)]
p <- plot_proportions_bar(df_feat, feat_cd8_nk)
ggsave(p, filename=paste0(dir_out, "/proportions_bar_cd8.png"), width=12, height=8)

feat_other <- feat_names[grep("B cell |Monocyte ", feat_names)]
p <- plot_proportions_bar(df_feat, feat_other)
ggsave(p, filename=paste0(dir_out, "/proportions_bar_other.png"), width=12, height=4)


p <- plot_cv_bar(df_feat, feat_names)
ggsave(p, filename=paste0(dir_out, "/cv_bar.png"), width=12, height=6)



### cleanup stats

files_stats <- list.files(dir_in, pattern="cleanup_stats")

df_stats <- lapply(paste0(dir_in, "/", files_stats), function(path) {
  read_csv(path, col_types = cols(), progress=FALSE)
}) %>% do.call(what=rbind)

p <- plot_cleanup_stats(df_stats)
ggsave(p, filename=paste0(dir_out, "/cleanup.png"), width=12, height=9)




### QC plots based on density estimates across all channels

files_kde <- list.files(dir_in, pattern=".csv")
files_kde <- files_kde[which(!grepl("major|adaptive|cleanup|metadata", files_kde))]
paths_kde <- paste0(dir_in, "/", files_kde)

df_kde <- lapply(paths_kde, read_csv, col_types=cols()) %>%
  do.call(what=rbind)

cell_types <- c("Neutrophil", "B cell", "T cell CD4", "T cell CD8")

# all files in the study

js_scores <- lapply(cell_types, run_cell_type_js, 
                    df_kde=df_kde, dir_out=paste0(dir_out, "/QC_all/"),
                    n_sd_cutoff=1.5, min_cutoff=0.1) %>%
  Reduce(f=full_join)

plot_js_across_cell_types(js_scores, dir_out=paste0(dir_out, "/QC_all/"))


# just the technical controls

js_scores <- lapply(cell_types, run_cell_type_js, 
                    df_kde=df_kde %>% filter(grepl("HD", file)), 
                    dir_out=paste0(dir_out, "/QC_controls/"),
                    n_sd_cutoff=1.5, min_cutoff=0.1) %>%
  Reduce(f=full_join) 

plot_js_across_cell_types(js_scores, dir_out=paste0(dir_out, "/QC_controls/"))


## in all viable cells
run_cell_type_js("all", df_kde=df_kde %>% filter(grepl("HD", file)), 
                 dir_out=paste0(dir_out, "/QC_controls/"),
                 n_sd_cutoff=1.5, min_cutoff=0.1)

message("Done!")



