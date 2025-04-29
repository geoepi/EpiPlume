calibrate_lambda <- function(distance_target_m, weight_target = 0.5) {
  lambda <- -log(weight_target) / distance_target_m
  return(lambda)
}
