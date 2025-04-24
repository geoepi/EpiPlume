project_to_mesh <- function(comb_data = comb_data,
                            mesh = mesh.dom,
                            prior.range=c(500, 0.6),
                            prior.sigma=c(1, 0.01)
){
    # time knots
    k <- length(unique(comb_data$hour))
    
    locs <- cbind(comb_data$x, comb_data$y)
    
    # match locations to mesh
    A.mat <- inla.spde.make.A(mesh.dom, 
                              alpha = 2,
                              loc=locs,
                              group = comb_data$hour)
    
    # spatial prior
    spde0 <- inla.spde2.pcmatern(mesh.dom, alpha = 2,
                                 prior.range=prior.range, 
                                 prior.sigma=prior.sigma,
                                 constr = TRUE)
    
    # spatial field (index)
    field.sp.1 <- inla.spde.make.index("field.sp.1", 
                                     spde0$n.spde,
                                     n.group=k)
    
    field.sp.2 <- inla.spde.make.index("field.sp.2", 
                                       spde0$n.spde,
                                       n.group=k)
    return(
      list(
        A.mat=A.mat,
        spde0=spde0,
        field.sp.1=field.sp.1,
        field.sp.2=field.sp.2
      )
    )

}