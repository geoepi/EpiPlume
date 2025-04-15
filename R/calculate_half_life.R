calculate_half_life <- function(viability_days, viability_threshold) {
  # viability_days: total time (units = days) after which the fraction viable is viability_threshold
  # viability_threshold: the fraction of the virus that remains viable at viability_days
  
  # Using the exponential decay model:
  # f(t) = exp(-lambda * t) with lambda = ln(2) / half_life.
  half_life <- (viability_days * log(2)) / (-log(viability_threshold))
  return(half_life)
}