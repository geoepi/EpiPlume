plot_ode_shed_dynamics <- function(out_df){
  
  base_theme <- theme_bw() +
    theme(plot.margin  = unit(c(2,0.5,2,0.5),"cm"),
          legend.direction = "horizontal",
          legend.position  = "bottom",
          strip.text       = element_blank(),
          strip.background = element_blank(),
          legend.key.size  = unit(2,"line"),
          legend.key.width = unit(3,"line"),
          legend.text  = element_text(size = 16, face = "bold"),
          legend.title = element_text(size = 18, face = "bold"),
          axis.title.x = element_text(size = 24, face = "bold"),
          axis.title.y = element_text(size = 24, face = "bold"),
          axis.text.x  = element_text(size = 18, face = "bold"),
          axis.text.y  = element_text(size = 20, face = "bold"),
          plot.title   = element_text(size = 22, face = "bold"))
  
  host_long <- out_df |>
    select(time, S, E, I, R) |>
    reshape2::melt(id.vars = "time", variable.name = "Compartment")
  
  p1 <- ggplot(host_long,
               aes(time, value, colour = Compartment, group = Compartment))+
    geom_line(linewidth = 1) +
    labs(x = "Time (days)", y = "Poultry") +
    base_theme
  
  # airborne
  p2 <- ggplot(out_df, aes(time, V))+
    geom_line(colour = "purple", linewidth = 1) +
    labs(x = "Time (days)",
         y = expression("Airborne virus  (EID"[50]*"  m"^-3*")")) +
    base_theme +
    theme(legend.position = "none")
  
  p_combined <- p1 / p2 
  
  return(p_combined)
}