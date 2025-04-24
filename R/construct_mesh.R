construct_mesh <- function(
    grid_raster = study_area$grid,
    farm_locs = study_area$farm_locs,
    cutoff = 500,
    max.edge = c(500, 5000),
    offset = c(500,3000),
    min.angle = 30,
    seed = 123
    ) {
  
  require(raster)
  select <- dplyr::select
  
  grid_extent_poly <- vect(ext(grid_raster), crs = crs(grid_raster))
  
  # INLA functions require Spatial objects
  points_sp <- as(farm_locs, "Spatial")
  dom_bnds <-  as(grid_extent_poly, "Spatial")
  dom_bnds <- inla.sp2segment(dom_bnds)
  
  set.seed(seed)
  mesh.dom <- inla.mesh.2d(boundary = dom_bnds, 
                           loc = points_sp,
                           cutoff = cutoff, 
                           max.edge = max.edge,
                           offset = offset,
                           min.angle = min.angle) 
  
  return(mesh.dom)
  
}
  