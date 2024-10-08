
read_features <- function(path_ada, path_maj) {
  df_ada <- read_csv(path_ada, col_types=cols(), progress=FALSE)
  df_maj <- read_csv(path_maj, col_types=cols(), progress=FALSE)
  
  df <- cbind(df_maj, df_ada)
  return(df)
}


get_palette <- function(df, col, palette="Set1") {
  unq <- as.character(unique(df[[col]])) %>% sort()
  pal <- c(RColorBrewer::brewer.pal(length(unq), palette))
  names(pal) <- c(unq)
  return(pal)
}


plot_umap_color_metadata <- function(df_feat_aug, col) {
  
  df_feat_aug[[col]] <- df_feat_aug[[col]] %>%
    as.character() %>%
    replace_na("IH Database")
  
  pal <- get_palette(df_feat_aug, col)
  pal["IH Database"] <- "gray"
  
  ggplot(df_feat_aug, aes(x=umap1, y=umap2, color=.data[[col]])) +
    geom_point(size=0.75, aes(alpha=if_else( is.na(.data[[col]]), 0.5, 1 ))) +
    scale_color_manual(values=pal) +
    guides(color = guide_legend(override.aes = list(alpha = 1, size = 2, shape = 19)),
           alpha="none") + 
    ggtitle("Study samples and technical controls in relation to historical IH samples") +
    theme_bw(base_size=14)
}


plot_proportions_bar <- function(df_feat, feat_names, major=FALSE) {
  df_tall <- df_feat %>%
    mutate(File = str_remove(file, "MDIPA_")) %>%
    pivot_longer(all_of(feat_names), names_to="feature", values_to="proportion")
  
  x_lab <- if_else(major, "% of total", "% of parent")
  
  ggplot(df_tall, aes(x=proportion, y=File, fill=File)) +
    geom_col() +
    scale_fill_viridis_d() +
    facet_wrap(~feature, scales="free_x", ncol=5) +
    xlab(x_lab) +
    guides(fill="none", color="none") +
    theme_bw(base_size=12) +
    theme(axis.text = element_text(size=7),
          axis.text.x = element_text(angle=45),
          strip.background = element_rect(fill="white", color="white"),
          strip.text = element_text(size=10))
}


plot_cv_bar <- function(df_feat, feat_names, lim = 0.25) {
  df_cv <- df_feat %>%
    select(all_of(c("file", feat_names))) %>%
    filter(grepl("HD", file)) %>%
    pivot_longer(all_of(feat_names), 
                 names_to="Cell type", 
                 values_to="Proportion") %>%
    group_by(`Cell type`) %>%
    summarise(m = mean(Proportion), s = sd(Proportion)) %>%
    mutate(CV = s/m)
  
  M <- max(lim, max(df_cv$CV))
  # m <- min(min(df_cv$m),1e-5)
  my_breaks <- 10^seq(-5,0)
  ggplot(df_cv, aes(x=`Cell type`, y=CV, fill=m)) +
    geom_col() +
    geom_hline(yintercept = 0.25, linetype="dashed") +
    scale_fill_viridis_c(name="% of parent", option="inferno", trans="log",
                         breaks=my_breaks, labels=my_breaks) +
    coord_cartesian(ylim=c(0,M)) +
    ylab("Coefficient of variation (CV = sd/mean)") +
    theme_bw() +
    theme(axis.text.x = element_text(angle=90, vjust=0.5, hjust=1))
}

plot_box <- function(df_feat_aug, feat_names, col) {
  df_tall <- df_feat_aug %>%
    filter(!is.na(.data[[col]])) %>%
    pivot_longer(all_of(feat_names), names_to="Feature", values_to="Value")
  
  pal <- get_palette(df_feat_aug, col)
  
  ggplot(df_tall, aes(x=.data[[col]], y=Value, color=.data[[col]])) +
    geom_boxplot() +
    scale_color_manual(values=pal) +
    facet_wrap(~Feature, scales="free_y", labeller = labeller(Feature = label_wrap_gen(15))) +
    ylab("% of parent") +
    theme_bw(base_size=14) +
    theme(strip.background = element_rect(fill="white", color="white"),
          strip.text = element_text(size=9),
          axis.text.x = element_text(angle=90, hjust=1, vjust=0.5, size=9),
          axis.text.y = element_text(size=9))
}


plot_lasso <- function(df_feat_aug, feat_names, col) {
  pal <- get_palette(df_feat_aug, col)
  
  df_valid <- df_feat_aug %>% 
    filter(!is.na(.data[[col]]) & .data[[col]]!="HD") 
  
  x <- df_valid %>% select(all_of(feat_names)) %>% as.matrix() %>% scale()
  vals <- unique(df_valid[[col]])
  y <- if_else(df_valid[[col]] == vals[1], 0, 1)
  tab <- table(y)
  w <- if_else(y==0, tab["1"]/length(y), tab["0"]/length(y))
  
  fit <- glmnet::glmnet(x = x, y = y, w=w, family="binomial",
                alpha = 0.5, pmax = 10) 
  coeff <- coef(fit)[,length(fit$lambda)]
  coeff_print <- coeff[which(coeff!=0)]
  coeff_print <- coeff_print[order(-abs(coeff_print))]

  ypred <- predict(fit, newx=x, type="response")[,length(fit$lambda)]
  
  df_res <- tibble(`Ground Truth` = if_else(y==0, vals[1], vals[2]), 
                   Prob = ypred,
                   Pred = if_else(ypred>0.5, vals[2], vals[1]))
  
  acc <- length(which(df_res$Pred==df_res$`Ground Truth`)) / length(y)
  
  pos <- names(which(coeff_print > 0 & names(coeff_print) != "(Intercept)"))
  neg <- names(which(coeff_print < 0 & names(coeff_print) != "(Intercept)"))

  subt <- paste0("Higher in ", vals[1], ": ", paste(neg, collapse=", "),
                 "\n",
                 "Higher in ", vals[2], ": ", paste(pos, collapse=", "))
  
  ggplot(df_res, aes(y=`Ground Truth`, x=Prob, color=`Ground Truth`)) +
    geom_boxplot() +
    xlab(paste("Predicted probability of", vals[2])) +
    ylab(col) +
    geom_vline(xintercept=0.5, linetype="dotted") +
    scale_color_manual(values=pal, name=col) +
    ggtitle(label=paste0("LASSO model accuracy=", round(acc,2)),
            subtitle=subt) +
    theme_bw(base_size=14)
  
}


plot_cleanup_stats <- function(df_stats) {
  df_stats_tall <- df_stats %>%
    mutate(Status = case_when(n_live_gate < 5e4 ~ "Few viable events",
                              n_live_gate / n_events < 0.75 ~ "Many events lost to cleanup",
                              TRUE ~ "OK")) %>%
    pivot_longer(where(is.numeric), names_to="Gate", values_to="Count") %>%
    mutate(Gate = factor(Gate, levels=names(df_stats[-1])))
  
  pal <- RColorBrewer::brewer.pal("Dark2", n=6)
  names(pal) <- c("OK", "Few viable events", "", "", "", "Many events lost to cleanup")
  ggplot(df_stats_tall, aes(x=Gate, y=Count, group=file, color=Status)) +
    geom_line() +
    expand_limits(y=0) +
    geom_text(data=df_stats_tall %>% filter(Status!="OK" & Gate=="n_live_gate"), 
              aes(label=file), color="black", size=2.5) +
    scale_color_manual(values=pal) +
    theme_bw(base_size=14) +
    ggtitle("Event counts per file during Bead, Gaussian and Live gates") +
    theme(axis.text.x = element_text(angle=90, hjust=1, vjust=0.5, size=9))
}



############### JS / QC functions 


normalize_density <- function(df) {
  df %>%
    mutate(density = if_else(density>0, density, 0)) %>%
    group_by(file, channel) %>%
    dplyr::mutate(density = density / sum(density)) %>%
    ungroup()
}


run_cell_type_js <- function(ct, df_kde, dir_out, n_sd_cutoff=1.5, min_cutoff=0.1) {
  df_ct <- df_kde %>% 
    filter(cell_type==ct) 
  df_for_js <- normalize_density(df_ct)
  
  if (nrow(df_ct)==0) {
    js_score <- tibble(file=c("0"),
                       js_score=c(0),
                       qc_pass=c(TRUE))
    names(js_score)[c(2,3)] <- paste0(names(js_score)[c(2,3)], "_", ct)
    return(js_score[-1,])
  }
  
  js <- get_js(df_for_js)
  js_score <- average_js_score(js, n_sd_cutoff = n_sd_cutoff, min_cutoff = min_cutoff)
  
  n <- nrow(js_score)
  siz <- max(n*8/12, 6)
  
  # p <- plot_js_all(js, ct)
  # ggsave(p, filename = paste0(dir_out, "js_all_", ct, ".png"), width=4+siz, height=3+siz)
  
  df_for_univariate <- inner_join(df_ct, js_score, by="file")
  p <- plot_univariate_all(df_for_univariate, ct)
  ggsave(p, filename = paste0(dir_out, "qc_univariate_", ct, ".png"), width=12, height=12)
  
  names(js_score)[c(2,3)] <- paste0(names(js_score)[c(2,3)], "_", ct)
  return(js_score)
}


get_js <- function (hist) {
  files <- unique(hist$file)
  
  channels <- hist %>% 
    group_by(channel) %>%
    summarise(n = length(unique(file))) %>%
    filter(n == length(files)) %>%
    pull(channel)
  
  js_all <- lapply(channels, function(ch) {
    hist_ch <- hist %>% 
      filter(channel == ch) %>% 
      select(file, expression, density) %>% 
      pivot_wider(names_from = "file", values_from = "density") %>% 
      select(-expression) %>% 
      as.matrix()
    js_mat <- js_matrix(hist_ch)
    colnames(js_mat) <- files
    js_df <- js_mat %>% as_tibble() %>% mutate(file1 = files) %>% 
      pivot_longer(-file1, names_to = "file2", values_to = "js_div") %>% 
      mutate(channel = ch)
    return(js_df)
  }) %>% do.call(what = rbind)
  return(js_all)
}


average_js_score <- function (js, cutoff = NULL, n_sd_cutoff = 1.5, 
                              min_cutoff=0.1, precision = 3) {
  js_with_score <- js %>% 
    group_by(file1) %>% 
    dplyr::summarise(js_score = round(mean(js_div), precision))
  
  m <- mean(js_with_score$js_score)
  s <- sd(js_with_score$js_score)
  
  if (is.null(cutoff)) 
    cutoff <- max(min_cutoff,m + n_sd_cutoff * s)
  
  if (is.na(s))
    cutoff <- min_cutoff
  message(paste0("Mean JS score: ", round(m, precision), "; sd: ", 
                 round(s, precision), "; cutoff:", round(cutoff, precision), 
                 "."))
  js_with_score <- js_with_score %>% 
    mutate(QC_result = if_else(js_score < cutoff, "Pass", "Flagged")) %>% 
    mutate(file = file1, .keep = "unused") %>% 
    relocate(file)
  
  n_pass <- length(which(js_with_score$QC_result=="Pass"))
  n_fail <- length(which(!js_with_score$QC_result=="Pass"))
  message(paste0(n_pass, " files passed QC and ", n_fail, 
                 " failed."))
  
  return(js_with_score)
}


plot_univariate_all <- function(df, ct) {

  if (ct == "all")
    ct <- "all viable cells"
  
  ggplot(df,
         aes(x=expression, y=density, group=file, color=QC_result)) +
    geom_path() +
    scale_color_manual(values = c("Pass" = "black", "Flagged" = "red")) +
    xlab("Expression (asinh-transformed)") +
    ylab("Density (scaled to max)") +
    facet_wrap(~channel) +
    ggtitle(paste("Univariate expression in", ct)) +
    theme_minimal(base_size=16) +
    theme(plot.background = element_rect(fill="white", color="white"))
}


plot_js_across_cell_types <- function(js_scores, dir_out) {
  js_scores_long <- pivot_js_scores(js_scores)
  p <- plot_js_tile(js_scores_long)
  
  n <- nrow(js_scores)
  m <- (ncol(js_scores)-1)/2
  w <- max(m*4/12,3) + 4
  h <- max(n*4/12,3) + 3
  
  ggsave(p, filename=paste0(dir_out, "qc_summary.png"), width=w, height=h)
  return(p)
}


pivot_js_scores <- function(js_scores) {
  js_scores_long <- js_scores %>%
    select(!matches("score")) %>%
    pivot_longer(matches("QC"), names_to="cell_type", values_to="QC_result") %>%
    mutate(cell_type = str_remove(cell_type, "QC_result_"))
}


plot_js_tile <- function(js_scores_long, batch="all") {
  switch (batch,
          "all" = {title = "QC in all samples"},
          "control" = {title = "QC in control samples"},
          {title = paste("QC in batch", batch)}
  )
  
  ggplot(js_scores_long, aes(x=cell_type, y=file, fill=QC_result)) +
    geom_tile(color="black") +
    scale_fill_manual(values=c("Pass"="white", "Flagged"="red")) +
    theme_bw(base_size=16) +
    ggtitle(title) +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))
}



