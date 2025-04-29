plot_distance_decay <- function(
    distance_max_m = 25000,
    distance_step_m = 100,
    lambda_target,
    weight_target,
    lambda_variation = 0.00002
) {
 
  distances <- seq(0, distance_max_m, by = distance_step_m)
  
  # Lambda variations
  lambdas <- c(lambda_target - lambda_variation, lambda_target, lambda_target + lambda_variation)
  lambda_labels <- paste0("λ = ", signif(lambdas, 3))
  
  plot_data <- expand.grid(
    distance_m = distances,
    lambda = lambdas
  )
  
  plot_data$weight <- exp(-plot_data$lambda * plot_data$distance_m)
  plot_data$lambda_label <- factor(lambda_labels[match(plot_data$lambda, lambdas)],
                                   levels = lambda_labels)
  
  p <- ggplot(plot_data, aes(x = distance_m / 1000, y = weight, color = lambda_label)) +
    geom_line(size = 1.2) +
    geom_hline(yintercept = weight_target, linetype = "dashed", color = "black", size = 1) +
    labs(
      x = "Distance (km)",
      y = "Inverse Distance Weight",
      title = "Inverse Distance Decay",
      color = "Lambda"
    ) +
    scale_y_continuous(breaks = seq(0, 1, 0.25),
                       labels = scales::label_number(accuracy = 0.1)) +
    theme_minimal() +
    theme(legend.direction = "vertical",
          legend.position  = "right",
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
  
  return(p)
}
