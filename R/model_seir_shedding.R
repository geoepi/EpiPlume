model_seir_shedding <- function(
    beta, sigma, gamma, qV, Vh, Q, lamd,
    flock_size, Ei, Ii, Ri, Vi,
    sim_days,
    infect_date = NULL
) {
  require(deSolve)
  require(dplyr)
  
  parms <- list(beta = beta, sigma = sigma, gamma = gamma,
                qV = qV, Vh = Vh, Q = Q, lamd = lamd)
  state <- c(S = flock_size - 1, E = Ei, I = Ii, R = Ri, V = Vi)
  SEIR <- function(t, y, p) {
    with(as.list(c(y, p)), {
      N  <- S+E+I+R
      dS <- -beta*S*I/N
      dE <-  beta*S*I/N - sigma*E
      dI <-  sigma*E - gamma*I
      dR <-  gamma*I
      source <- qV * I
      dV <- (source/Vh) - (lamd + Q/Vh) * V # loss in viability + ventilation (removal)
      list(c(dS,dE,dI,dR,dV))
    })
  }
  
  times <- seq(0, sim_days, by = 1/24)
  out   <- as.data.frame(ode(state, times, SEIR, parms))
  
  if (!is.null(infect_date)) {
    out <- out %>%
      mutate(datetime = as.POSIXct(infect_date) + time * 86400)
  }
  
  return(out)
}
