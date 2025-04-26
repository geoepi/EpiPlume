plot_mesh <- function(mesh,
                      node_cols   = c(evertices = "gray40",
                                      adata     = "darkred"),
                      node_sizes  = c(evertices = 0.8,
                                      adata     = 3.0),
                      node_shapes = c(evertices = 19,
                                      adata     = 19),
                      edge_cols   = c(bsegments = "gray60",
                                      cbinding  = "gray10",
                                      dinternal = "gray40"),
                      edge_widths = c(bsegments = 0.5,
                                      cbinding  = 1.2,
                                      dinternal = 1)){
  
  mesh_df <- extract_mesh_network(mesh)
  
  all_cols <- c(node_cols, edge_cols)
  
  ggplot() +
    geom_segment(
      data = mesh_df$edges,
      aes(x        = x1,
          y        = y1,
          xend     = x2,
          yend     = y2,
          colour   = type,
          linewidth = type)
    ) +
    geom_point(
      data = mesh_df$nodes,
      aes(x      = x,
          y      = y,
          colour = type,
          size   = type,
          shape  = type)
    ) +
    scale_colour_manual(values = all_cols, guide = "none")        +
    scale_linewidth_manual(values = edge_widths, guide = "none")  +
    scale_size_manual(values = node_sizes, guide = "none")        +
    scale_shape_manual(values = node_shapes, guide = "none")      +
    labs(x = "Easting", y = "Northing") +
    theme_minimal() +
    theme(
      plot.margin      = unit(rep(0.5,4), "cm"),
      axis.title       = element_text(size = 18, face = "bold"),
      axis.text        = element_text(size = 12, face = "bold"),
      legend.position  = "none"
    )
}
