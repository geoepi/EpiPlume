plot_ode_dynamics <- function(out_df) {
  
  host_melt <- out_df |>
    select(time, S, E, I, R) |>
    as.data.frame()
  
  host_melt <- reshape2::melt(host_melt, "time", variable.name = "Compartment")
  
  p <- ggplot(host_melt, aes(time, value, group = Compartment, col = Compartment)) +
    geom_line(linewidth = 1) +
    xlab("Time Step") + 
    ylab("Poultry") +
    theme_bw() +
    theme(plot.margin = unit(c(2,0.5,2,0.5),"cm"),
          legend.direction = "horizontal",
          legend.position="bottom", 
          strip.text = element_blank(), 
          strip.background = element_blank(),
          legend.key.size = unit(2,"line"),
          legend.key.width = unit(3,"line"),
          legend.text = element_text(size=16, face="bold"),
          legend.title = element_text(size=18, face="bold"),
          axis.title.x = element_text(size=24, face="bold"),
          axis.title.y = element_text(size=24, face="bold"),
          axis.text.x = element_text(face="bold", size=18, vjust=1, 
                                     hjust=1, angle=45),
          axis.text.y = element_text(size=20, face="bold"),
          plot.title = element_text(size=22, face="bold"))
  
  return(p)
}