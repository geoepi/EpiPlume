run_spatiotemporal <- function(field.sp.1 = sp_indices_dens$field.sp.1,
                               field.sp.2 = sp_indices_dens$field.sp.2,
                               spde_prior = sp_indices_dens$spde0,
                               est.stk=joint.stack,
                               verbose = FALSE,
                               save = here("local/assets")
){
  
  #pcprior_1 <- list(prec = list(prior="pc.prec", param = c(1, 0.01))) 
  rho_pc <- list(rho = list(prior = "pc.cor1", param = c(0, 0.9))) 
  cont_g <- list(model = "ar1", hyper = rho_pc)
  
  beta_prior <- list(prior = 'gaussian', param = c(0,1))
  pcgprior <- list(prior = 'pc.gamma', param = 1)
  cff <- list(list(), list(hyper = list(prec = pcgprior)))
  
  #hc1 = list(theta = list(prior = "normal", param = c(0, 10)))
  #ctr.g = list(model = "iid", hyper = hc1) # sanity check
  
  
  formula.1 <- Y ~ -1 + intercept1 +
                        intercept2 +
    f(field.sp.1,
      model=spde_prior,
      group = field.sp.1.group,
      control.group=cont_g) +
    f(field.sp.2,
      copy="field.sp.1",
      group =field.sp.2.group,
      hyper = list(beta = beta_prior),
      fixed=FALSE)
  
  model.0 <- inla(formula.1,
                  #num.threads = 12,
                  data = inla.stack.data(est.stk),
                  family = c("binomial","gamma"),
                  control.family = cff,
                  verbose = verbose,
                  control.fixed = list(prec = 1, prec.intercept=1),
                  control.predictor = list(
                                  A = inla.stack.A(est.stk), 
                            compute = TRUE,
                               link = link), 
                  #control.mode = list(restart = TRUE, theta = theta_1),
                  control.inla = list(strategy="adaptive",
                                      int.strategy = "eb"),
                  control.compute=list(dic = FALSE, cpo = FALSE, waic = FALSE)) 
  
  if(!is.null(save)){
    
    saveRDS(model.0, paste0(save, "/bg_model_", Sys.Date(), ".rds"))
  }
  
  return(model.0)
  
}