model_seir_shedding <- function(config_file = "demo_2025-04-21", infect_date = NULL) {
  
  require(deSolve)
  
  # read configuration
  cfg <- yaml::read_yaml(here("config", paste0(config_file, ".yaml")))
  
  # parameter estimation
  # virus viability
  halflife <- calculate_half_life(viability_days = cfg$virus$viability_hours/24, # convert hours to days
                                  viability_threshold = cfg$virus$viability_threshold)
  
  lambda_d <- log(2) / halflife    # days
  
  # poultry house
  Q_day <- cfg$poultry$Q_m3_h * 24 # convert to m3 per day
  
  # SERI_v input params
  parms <- list(
    beta  = cfg$seir$beta,
    sigma = 1/cfg$seir$sigma,
    gamma = 1/cfg$seir$gamma,
    qV    = cfg$virus$qV,
    Vh    = cfg$poultry$house_vol,
    Q     = Q_day,
    lamd  = lambda_d
  )
  
  # initial conditions
  state <- c(S = cfg$poultry$flock_size - 1, 
             E = cfg$seir$Ei, 
             I = cfg$seir$Ii, 
             R = cfg$seir$Ri, 
             V = cfg$seir$Vi)

  SEIR_poultry_shed <- function(t, y, p){
    with(as.list(c(y, p)),{
      N  <- S + E + I + R
      dS <- -beta * S * I / N
      dE <-  beta * S * I / N - sigma * E
      dI <-  sigma * E - gamma * I
      dR <-  gamma * I
      
      source <- qV * I
      dV <- (source / Vh) - (lamd + Q / Vh) * V
      
      list(c(dS,dE,dI,dR,dV))
    })
  }
  
  times <- seq(0, cfg$seir$sim_days, 1/24)
  
  shed_out <- as.data.frame(
    deSolve::ode(state, times, SEIR_poultry_shed, parms)
  )
  
  if(!is.null(infect_date) && is.Date(infect_date)){
    
    shed_out <- shed_out %>%
      mutate(
        datetime = as.POSIXct(infect_date) + time * 86400
      )
  }
  
  return(shed_out)
}