calculate_inverse_distance_weight <- function(distance_m, lambda = 0.001) {
  # inverse distance weight
  
  if (any(distance_m < 0, na.rm = TRUE)) {
    distance_m <- pmax(distance_m, 0) # negative values to zero
  }
  
  weight <- round(exp(-lambda * distance_m), 4)
  
  return(weight)
}
