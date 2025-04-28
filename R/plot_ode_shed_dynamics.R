plot_ode_shed_dynamics <- function(out_df, date_axis = FALSE, vline = NULL, vline_text = NULL) {
  
  require(patchwork)
  require(reshape2)
  
  # which column to map
  if (date_axis) {
    xvar <- "datetime"
    xlab <- "Date"
    scale_x <- scale_x_datetime(
      date_breaks = "5 days",
      date_labels = "%Y-%m-%d"
    )
  } else {
    xvar <- "time"
    xlab <- "Time (days)"
    scale_x <- NULL
  }
  xvar_sym <- sym(xvar)
  
  host_long <- if (date_axis) {
    melt(out_df,
         id.vars       = "datetime",
         measure.vars  = c("S","E","I","R"),
         variable.name = "Compartment",
         value.name    = "value")
  } else {
    melt(out_df,
         id.vars       = "time",
         measure.vars  = c("S","E","I","R"),
         variable.name = "Compartment",
         value.name    = "value")
  }
  
  # theme
  base_theme <- theme_bw() +
    theme(
      plot.margin     = unit(c(2,0.5,2,0.5), "cm"),
      legend.direction = "horizontal",
      legend.position  = "bottom",
      strip.text       = element_blank(),
      strip.background = element_blank(),
      legend.key.size  = unit(2, "line"),
      legend.key.width = unit(3, "line"),
      legend.text      = element_text(size = 16, face = "bold"),
      legend.title     = element_text(size = 16, face = "bold"),
      axis.title.x     = element_text(size = 20, face = "bold"),
      axis.title.y     = element_text(size = 20, face = "bold"),
      axis.text.x      = element_text(size = 12, face = "bold"),
      axis.text.y      = element_text(size = 18, face = "bold"),
      plot.title       = element_text(size = 22, face = "bold")
    )
  
  # compartments
  p1 <- ggplot(host_long, aes(
    x      = !!xvar_sym,
    y      = .data$value,
    colour = .data$Compartment,
    group  = .data$Compartment
  )) +
    geom_line(linewidth = 1) +
    labs(x = xlab, y = "Poultry") +
    base_theme +
    scale_x
  
  # airborne
  p2 <- ggplot(out_df, aes(
    x = !!xvar_sym,
    y = .data$V
  )) +
    geom_line(colour = "purple", linewidth = 1) +
    labs(x = xlab,
         y = expression("Airborne virus  (EID"[50]*"  m"^-3*")")) +
    base_theme +
    theme(legend.position = "none") +
    scale_x
  
  if (!is.null(vline)) {
    if (date_axis) {
      vline <- as.POSIXct(vline, tz = "UTC")
    }
    p1 <- p1 +
      geom_vline(xintercept = vline,
                 linetype     = "dotdash",
                 linewidth    = 1,
                 colour       = "black") +
      annotate("text",
               x           = vline,
               y           = Inf,
               label       = vline_text,
               angle       = 90,
               vjust       = -0.5,
               hjust       = 1.1,
               size        = 5)
    p2 <- p2 +
      geom_vline(xintercept = vline,
                 linetype     = "dotdash",
                 linewidth    = 1,
                 colour       = "black") +
      annotate("text",
               x           = vline,
               y           = Inf,
               label       = vline_text,
               angle       = 90,
               vjust       = -0.5,
               hjust       = 1.1,
               size        = 5)
  }
  
  # combine
  combined <- p1 / p2
  
  return(combined)
}
