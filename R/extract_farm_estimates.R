extract_farm_estimates <- function(model = bin_gamma_model,
                                   stack = joint.stack,
                                   stack_targ = "dens.0",
                                   match_data = comb_data_in){
  #index locations
  idat <- inla.stack.index(stack, stack_targ)$data
  
  # pull from model
  parti_fits <- model$summary.fitted.values[idat,c(1:5)]
  names(parti_fits) <- c("mean", "sd", "low", "med", "high")
  parti_fits <- cbind(match_data, parti_fits) %>%
    filter(set == "farm")
  
  # clean up labels
  parti_fits$label <- gsub("farm_", "Farm ", parti_fits$name)
  parti_fits$label <- gsub("source_farm", "Source", parti_fits$label)
  farm_names <- unique(parti_fits$label[parti_fits$label != "Source"])
  
  farm_order <- paste0(
    "Farm ",
    sort(as.integer(sub("^Farm\\s+", "", farm_names)), decreasing=TRUE)
  )
  
  parti_fits$label <- factor(parti_fits$label, levels = c(farm_order, "Source"))
  
  ## Prepare data table
  intro_prob <- parti_fits %>%
    select(name, label, low, med, high, flock)
  
  row.names(intro_prob) <- 1:dim(intro_prob)[1]
  
  intro_prob[,c("low","med","high")] <- round(intro_prob[,c("low","med","high")], 4)
  
  
  # plot
  max_hr <- max(parti_fits$hour)
  
  ggp <- ggplot(parti_fits, aes(as.factor(hour), label, fill = med)) +
    geom_tile() +
    scale_fill_gradientn(
      colors = rev(pals::cubehelix(100)[1:99]),
      #colors = rev(pals::parula(100)),
       na.value = "white",
       breaks = seq(0, 1, 0.20),
       limits = c(0, 1),
       name = "Probability"
    ) +
    #scale_x_discrete(breaks = seq(0, max_hr, 1), 
    #                   labels = seq(0, max_hr, 1), 
    #                   limits = c(0, max_hr)) +
    theme_minimal() +
    theme(
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      plot.margin     = unit(c(0.2,0.2,0.2,0.2), "cm"),
      legend.direction = "vertical",
      legend.position  = "right",
      strip.text       = element_blank(),
      strip.background = element_blank(),
      legend.key.size  = unit(2, "line"),
      legend.key.width = unit(3, "line"),
      legend.text      = element_text(size = 16, face = "bold"),
      legend.title     = element_text(size = 16, face = "bold"),
      axis.title.x     = element_text(size = 20, face = "bold"),
      axis.title.y     = element_text(size = 20, face = "bold"),
      axis.text.x      = element_text(size = 20, face = "bold"),
      axis.text.y      = element_text(size = 18, face = "bold"),
      plot.title       = element_text(size = 22, face = "bold")
    ) +
    labs(title = "Particle Introduction Probability",
         x = "Hour Post-emission", y = " ")
  
  return(
    list(
      table = intro_prob,
      plot = ggp
    )
  )
  
}