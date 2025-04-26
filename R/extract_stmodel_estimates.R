extract_stmodel_estimates <- function(model = bin_gamma_model,
                                      stack = joint.stack,
                                      stack_targ = "dens.0",
                                      match_data = comb_data_in,
                                      grid_label = "concen",
                                      raster_template = study_area$grid){
  
  idat <- inla.stack.index(stack, stack_targ)$data
  
  parti_fits <- model$summary.fitted.values[idat,c(1:5)]
  names(parti_fits) <- c("mean", "sd", "low", "med", "high")
  parti_fits <- cbind(match_data, parti_fits) %>%
    filter(set == grid_label)
  
  
  hours <- sort(unique(parti_fits$hour))
  dens_rast_lst <- vector("list", length(hours))
  names(dens_rast_lst) <- paste0("Hour ", hours)
  
  for (j in seq_along(hours)) {
    h <- hours[j]
    tmp_hour <- parti_fits %>% 
      filter(hour == h)
    
    tmp_pnts <- vect(tmp_hour, 
                     geom = c("x","y"), 
                     crs = crs(raster_template))
    
    tmp_r    <- rasterize(tmp_pnts, 
                          raster_template, 
                          "mean", 
                          background = NA)
    
    names(tmp_r) <- paste0("Hour ", h)
    
    dens_rast_lst[[j]] <- tmp_r
  }
  
  dens_stack <- rast(dens_rast_lst)
  
  return(dens_stack)
}