animate_plume_simple <- function(traj_data, group_col = NULL, point_size = 0.5, source_loc=source_loc) {
  require(ggplot2)
  require(dplyr)
  require(gganimate)
  
  # uses the 'hour' column
  if (!"hour" %in% names(traj_data)) {
    stop("traj_data must include an 'hour' column indicating the time step for each point.")
  }
  

  if (!is.null(group_col)) {
    traj_data[[group_col]] <- as.factor(traj_data[[group_col]])

    traj_data <- traj_data %>%
      group_by(hour, !!sym(group_col)) %>%
      slice_tail(n = 1) %>%
      ungroup()
  } else {

    traj_data <- traj_data %>%
      group_by(hour) %>%
      slice_tail(n = 1) %>%
      ungroup()
  }
  
  # to plot the source location
  source_loc <- as.data.frame(
    cbind(
      x = source_origin[1],
      y = source_origin[2]
      )
    )
  
  # base ggplot (no background)
  p <- ggplot(traj_data, aes(x = lon, y = lat)) + 
    geom_point(aes(color = if(!is.null(group_col)) .data[[group_col]] else NULL),
               size = point_size) +
    geom_point(data=source_loc, aes(x, y),
                 size = 5, shape= 17, col="black") +
    coord_equal() +
    theme_classic() +
    labs(title = "Post Emission: Hour {frame_time}",
         x = "Longitude", y = "Latitude") +
    theme_minimal() +
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
  
  return(p)
}
