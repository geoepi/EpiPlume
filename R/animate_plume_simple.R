animate_plume_simple <- function(
    traj_data,
    group_col  = NULL,
    point_size = 0.5,
    source_loc,
    fps        = 2,            # frames per second
    width      = 800,          # px
    height     = 600,          # px
    renderer   = gifski_renderer(loop = FALSE)
) {
  options(bitmapType = "cairo")
  
  require(ggplot2)
  require(dplyr)
  require(gganimate)
  
  # check for hour
  if (!"hour" %in% names(traj_data)) {
    stop("traj_data must include an 'hour' column.")
  }
  
  #thin to last point per group/hour
  if (!is.null(group_col)) {
    traj_data[[group_col]] <- as.factor(traj_data[[group_col]])
    traj_data <- traj_data %>%
      group_by(hour, .data[[group_col]]) %>%
      slice_tail(n = 1) %>%
      ungroup()
  } else {
    traj_data <- traj_data %>%
      group_by(hour) %>%
      slice_tail(n = 1) %>%
      ungroup()
  }
  
  # source location
  source_df <- data.frame(
    lon = source_loc[1],
    lat = source_loc[2]
  )
  
  # plot with transition
  p <- ggplot(traj_data, aes(x = lon, y = lat)) +
    geom_point(aes(color = if (!is.null(group_col)) .data[[group_col]] else NULL),
               size = point_size) +
    geom_point(data = source_df, aes(lon, lat),
               size = 5, shape = 17) +
    coord_equal() +
    theme_minimal() +
    labs(
      title = 'Post Emission: Hour {frame_time}',
      x     = "Longitude",
      y     = "Latitude"
    ) +
    theme(
      plot.margin    = unit(c(0.25, 0.25, 0.25, 0.25), "cm"),
      legend.position = "none",
      strip.text     = element_text(size = 18, face = "bold", color = "gray40"),
      axis.title.x   = element_text(size = 22, face = "bold"),
      axis.title.y   = element_text(size = 22, face = "bold"),
      axis.text.x    = element_text(size = 18, face = "bold"),
      axis.text.y    = element_text(size = 18, face = "bold"),
      plot.title     = element_text(size = 22, face = "bold", hjust = 0.5)
    ) +
    transition_time(hour) +
    ease_aes('linear')
  
  # animate
  nframes <- length(unique(traj_data$hour))
  anim <- gganimate::animate(
    p,
    nframes  = nframes,
    fps      = fps,
    width    = width,
    height   = height,
    renderer = renderer
  )
  
  return(anim)
}
