get_spatial_rf <- function(model = model.0,
                           field_sp = sp_indices$field.sp,
                           raster_template = study_area$grid,
                           mesh = mesh.dom
){
  
  blank.r <- raster_template
  blank.r[!is.na(blank.r)] <- 0
  
  grid_pnts <- as.points(blank.r)
  names(grid_pnts) <- "cell_value"
  
  grid_coords <- grid_pnts %>%
    geom() %>%
    as.data.frame() 
  
  Ap <- inla.spde.make.A(mesh, 
                         loc = cbind(grid_coords[,"x"], 
                                     grid_coords[,"y"]))
  
  mrf_pf <- cbind(model$summary.random$field.sp$mean, 
                  field_sp$field.sp.group)
  
  mrf_pf_v <- list()
  mrf_pf_v  <- split(mrf_pf[,1], mrf_pf[,2])
  
  rst_list <- vector("list", length(mrf_pf_v))
  for(i in 1:length(mrf_pf_v)){
    
    grid_pnts$tmp_attr <- drop(Ap %*% mrf_pf_v[[i]]) 
    
    tmp_r <- rasterize(grid_pnts, 
                       blank.r, 
                       "tmp_attr",
                       background = NA)
    
    names(tmp_r) <- paste0("Hour ", i)
    rst_list[[i]] <- tmp_r
    
  }
  
  hour_stack <- rast(rst_list)
  
  return(hour_stack)
  
}