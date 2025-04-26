extract_mesh_network <- function(mesh){
  
  # orginal source: https://github.com/timcdlucas/INLAutils
  
  d <- data.frame(x = mesh$loc[, 1], y = mesh$loc[, 2], type = 'evertices')
  levels(d$type) <- c('evertices', 'adata')
  d[mesh$idx$loc, 'type'] <- 'adata'
  
  idx = rbind(mesh$graph$tv[, 1:2, drop = FALSE], 
              mesh$graph$tv[, 2:3, drop = FALSE], 
              mesh$graph$tv[, c(3, 1), drop = FALSE])
  
  segments <- data.frame(mesh$loc[idx[, 1], 1:2], mesh$loc[idx[, 2], 1:2], type = 'bsegments')
  
  innerouter <- data.frame(mesh$loc[mesh$segm$bnd$idx[, 1], 1:2],
                           mesh$loc[mesh$segm$bnd$idx[, 2], 1:2],
                           type = 'cbinding', stringsAsFactors = FALSE)
  
  if(nrow(mesh$segm$int$idx) > 0){
    innerouter <- rbind(innerouter,
                        data.frame(mesh$loc[mesh$segm$int$idx[, 1], 1:2],
                                   mesh$loc[mesh$segm$int$idx[, 2], 1:2],
                                   type = 'dinternal'))
  } else {
    innerouter$type = factor(innerouter$type, levels = c('dinternal', 'cbinding'))
  }
  
  names(segments) <- c('x1', 'y1', 'x2', 'y2', 'type')
  names(innerouter) <- c('x1', 'y1', 'x2', 'y2', 'type')
  
  segments <- rbind(segments, innerouter)
  
  mesh_data <- list()
  mesh_data[["nodes"]] <- d
  mesh_data[["edges"]] <- segments
  
  return(mesh_data)
}