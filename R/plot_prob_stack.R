plot_prob_stack <- function(rast_stack=rast_stack,
                              farm_locs = study_area$farm_locs,
                              save_name = NULL,
                              save_dir = here("assets")){
  
  df <- as.data.frame(rast_stack, xy = TRUE)
  
  df_long <- pivot_longer(
    df,
    cols       = -c(x, y),
    names_to   = "hour_layer",
    values_to  = "hour_value"
  )
  
  sf_farms <- st_as_sf(farm_locs)
  
  ggp <- ggplot(df_long, aes(x = x, y = y, fill = hour_value)) +
    geom_raster() +
    facet_wrap(~ hour_layer, ncol = 3) +
    coord_equal(expand = FALSE) +
    #scale_fill_viridis_c(option = "turbo", na.value = "transparent") +
    scale_fill_gradientn(
      colors = rev(pals::cubehelix(30)[1:28]),
      na.value = "white",
      limits = c(0, 1),
      name = "Probability"
    ) +
    theme_minimal() +
    theme(
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.title = element_text(size = 16, face = "bold"),
      legend.text = element_text(size = 10, face = "bold"),
      legend.key.width = unit(3, "line"),
      legend.key.height = unit(1, "line"),
      strip.text     = element_text(size = 18, face = "bold", color = "gray40"),
      axis.title.x   = element_text(size = 20, face = "bold"),
      axis.title.y   = element_text(size = 20, face = "bold"),
      axis.text.x    = element_text(size = 10, hjust = 0.5, angle = 45, face = "bold"),
      axis.text.y    = element_text(size = 10, face = "bold"),
      plot.title     = element_text(size = 22, face = "bold", hjust = 0.5)
    ) +
    labs(fill = "Hour",
         title = "Particle Probabilty",
         x = "Easting", y = "Northing") +
    geom_sf(
      data        = sf_farms,
      aes(shape = farm),
      fill        = "yellow",
      color       = "red",
      size        = 3,
      stroke      = 1,
      inherit.aes = FALSE
    ) +
    scale_shape_manual(
      name   = "Farm type",
      values = c(source = 24, sim = 21)
    )
  
  if(!is.null(save_name)){
    
    ggsave(
      filename = paste0(save_name, ".png"),
      plot = ggp,
      path = save_dir,
      width = 11,
      height = 8.5,
      units = "in",
      dpi = 100,
      device = "png",
      bg = "white"
    )
  }
  
  return(ggp)
  
}