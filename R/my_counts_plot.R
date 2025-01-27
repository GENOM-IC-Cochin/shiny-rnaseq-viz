my_counts_plot <- function(plot_data,
                           variable,
                           logy = TRUE,
                           boxplot = FALSE,
                           levels,
                           config,
                           zero,
                           ratio = 1,
                           theme = "Classic with gridlines",
                           angle_x = 0,
                           hjust = 0.5,
                           vjust = 0.5) {
  samples_to_var <- config %>%
    select(all_of(c("Name", variable)))

  res <- plot_data %>%
    tidyr::pivot_longer(!Row.names, names_to = "Name") %>%
    inner_join(samples_to_var, by = "Name") %>%
    filter(.data[[variable]] %in% levels) %>%
    mutate(value = value + ifelse(logy, 0.5, 0)) %>%
    dplyr::rename(Sample = Name, Gene = Row.names) %>%
    ggplot(aes_string(x = variable, y = "value"))
  if (boxplot) {
    res <- res + geom_boxplot()
  } else {
    res <- res + geom_point(position = position_jitter(w = 0.1, h = 0))
  }
  res <- res + facet_wrap(~Gene,
    scales = "free_y"
  ) +
    labs(y = "Normalized count") +
    switch(theme,
      "Gray" = theme_gray(),
      "Classic" = theme_classic(),
      "Classic with gridlines" = theme_bw()
    ) +
    theme(
      aspect.ratio = ratio,
      axis.text.x = element_text(
        angle = angle_x,
        hjust = hjust,
        vjust = vjust
      )
    )
  if (logy) {
    res <- res +
      scale_y_log10(limits = c(ifelse(zero, 0.5, NA), NA))
  } else {
    res <- res +
      scale_y_continuous(limits = c(ifelse(zero, 0, NA), NA))
  }
  res
}
