run_spatiotemporal <- function(field.sp = sp_indices$field.sp, 
                               spde_prior = sp_indices$spde0,
                               est.stk=est.stk,
                               verbose = TRUE
){
  
  pcprior_1 <- list(prec = list(prior="pc.prec", param = c(1, 0.01))) 
  rho_pc <- list(rho = list(prior = "pc.cor1", param = c(0, 0.9))) 
  cont_g <- list(model = "ar1", hyper = rho_pc)
  
  #hc1 = list(theta = list(prior = "normal", param = c(0, 10)))
  #ctr.g = list(model = "iid", hyper = hc1) #sanity check
  
  
  formula.1 <- Y ~ -1 + intercept1 +
    f(field.sp,
      model=spde_prior,
      group = field.sp.group,
      control.group=cont_g)
  
  model.0 <- inla(formula.1,
                  #num.threads = 12,
                  data = inla.stack.data(est.stk),
                  family = c("binomial"), # sanity check
                  verbose = verbose,
                  control.fixed = list(prec = 1, prec.intercept=1),
                  control.predictor = list(
                    A = inla.stack.A(est.stk), 
                    compute = TRUE,
                    link = 1), 
                  # control.mode = list(restart = TRUE, theta = theta_1),
                  control.inla = list(strategy="adaptive",
                                      int.strategy = "eb"),
                  control.compute=list(dic = FALSE, cpo = FALSE, waic = FALSE)) 
  
  return(model.0)
  
}