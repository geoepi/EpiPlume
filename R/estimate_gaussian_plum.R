# Simple Gaussian Plume Dispersion Model  
## Thanks to the source: https://github.com/dholstius/plume

# Pasquill–Gifford sigma function
stability_class <- function(stability = "D") {
  if (stability == "A") {
    sigma <- function(x) {
      x.km <- x / 1000
      breaks <- c(0, 0.10, 0.15, 0.20, 0.25, 0.30, 0.40, 0.50, 100.0)
      i <- as.integer(cut(x.km, breaks, right = TRUE))
      a <- c(122.800, 158.080, 170.220, 179.520, 217.410, 258.890, 346.750, 453.850)[i]
      b <- c(0.94470, 1.05420, 1.09320, 1.12620, 1.26440, 1.40940, 1.72830, 2.11660)[i]
      sgz <- a * x.km^b
      sgz <- pmin(5000.0, sgz)
      Tc <- 24.1670
      Td <- 2.5334
      Theta <- 0.017453293 * (Tc - Td * log(x.km))
      sgy <- 465.11628 * x.km * tan(Theta)
      list(y = sgy, z = sgz)
    }
  } else if (stability == "B") {
    sigma <- function(x) {
      x.km <- x / 1000
      breaks <- c(0, 0.20, 0.40, 100.0)
      i <- as.integer(cut(x.km, breaks, right = TRUE))
      a <- c(90.673, 98.483, 109.300)[i]
      b <- c(0.93198, 0.98332, 1.09710)[i]
      sgz <- a * x.km^b
      sgz <- pmin(5000.0, sgz)
      Tc <- 18.3330
      Td <- 1.8096
      Theta <- 0.017453293 * (Tc - Td * log(x.km))
      sgy <- 465.11628 * x.km * tan(Theta)
      list(y = sgy, z = sgz)
    }
  } else if (stability == "C") {
    sigma <- function(x) {
      x.km <- x / 1000
      a <- 61.141
      b <- 0.91465
      sgz <- a * x.km^b
      sgz <- pmin(5000.0, sgz)
      Tc <- 12.5000
      Td <- 1.0857
      Theta <- 0.017453293 * (Tc - Td * log(x.km))
      sgy <- 465.11628 * x.km * tan(Theta)
      list(y = sgy, z = sgz)
    }
  } else if (stability == "D") {  # Neutral conditions
    sigma <- function(x) {
      x.km <- x / 1000
      breaks <- c(0, 0.30, 1.00, 3.00, 10.00, 30.00, 100.0)
      i <- as.integer(cut(x.km, breaks, right = TRUE))
      a <- c(34.459, 32.093, 32.093, 33.504, 36.650, 44.053)[i]
      b <- c(0.86974, 0.81066, 0.64403, 0.60486, 0.56589, 0.51179)[i]
      sgz <- a * x.km^b
      sgz <- pmin(5000.0, sgz)
      Tc <- 8.3330
      Td <- 0.72382
      Theta <- 0.017453293 * (Tc - Td * log(x.km))
      sgy <- 465.11628 * x.km * tan(Theta)
      list(y = sgy, z = sgz)
    }
  } else if (stability == "E") {  # Moderately stable
    sigma <- function(x) {
      x.km <- x / 1000
      breaks <- c(0, 0.30, 1.00, 3.00, 10.00, 30.00, 100.0)
      i <- as.integer(cut(x.km, breaks, right = TRUE))
      a <- c(24.259, 23.331, 21.628, 21.628, 22.534, 24.703)[i]
      b <- c(0.83660, 0.81956, 0.75660, 0.63077, 0.57154, 0.50527)[i]
      sgz <- a * x.km^b
      sgz <- pmin(5000.0, sgz)
      Tc <- 6.2500
      Td <- 0.54287
      Theta <- 0.017453293 * (Tc - Td * log(x.km))
      sgy <- 465.11628 * x.km * tan(Theta)
      list(y = sgy, z = sgz)
    }
  } else if (stability == "F") {  # Very stable conditions
    sigma <- function(x) {
      x.km <- x / 1000
      breaks <- c(0, 0.30, 1.00, 3.00, 10.00, 30.00, 100.0)
      i <- as.integer(cut(x.km, breaks, right = TRUE))
      a <- c(15.209, 14.457, 13.953, 13.953, 14.823, 16.187)[i]
      b <- c(0.81558, 0.78407, 0.68465, 0.63227, 0.54503, 0.46490)[i]
      sgz <- a * x.km^b
      sgz <- pmin(5000.0, sgz)
      Tc <- 4.1667
      Td <- 0.36191
      Theta <- 0.017453293 * (Tc - Td * log(x.km))
      sgy <- 465.11628 * x.km * tan(Theta)
      list(y = sgy, z = sgz)
    }
  } else {
    stop("Stability class must be one of A, B, C, D, E, F.")
  }
  return(sigma)
}


# GaussianPlume
estimate_gaussian_plum <- function(Q, H, u, sigma = stability_class("D")) {
  # Q: emission rate (g/s)
  # H: source height (m)
  # u: wind speed (m/s)
  # sigma: function returning a list with sigma_y and sigma_z given x (meters)
  plume_FUN <- function(receptors) {
    # receptors: a matrix or data frame with columns x, y and optionally z.
    if (inherits(receptors, "Spatial")) {
      coords <- sp::coordinates(receptors)
    } else {
      coords <- as.matrix(receptors)
    }
    x <- coords[, 1]
    y <- coords[, 2]
    if (ncol(coords) == 2) {
      # default receptor height if z is not provided (human height)
      z <- rep(1.8, length(x))
      warning("No z values supplied. Defaulting to 1.8 m.")
    } else if (ncol(coords) >= 3) {
      z <- coords[, 3]
    } else {
      stop("Invalid coordinate dimensions.")
    }
    # dispersion parameters from sigma()
    sg <- sigma(x)
    # Gaussian plume equation:
    # f(y) is the horizontal Gaussian distribution,
    # g(z) is the sum of two vertical distributions (for reflection at the ground)
    f_y <- dnorm(y, mean = 0, sd = sg$y)
    g1 <- dnorm(z - H, mean = 0, sd = sg$z)
    g2 <- dnorm(z + H, mean = 0, sd = sg$z)
    concentration <- Q / u * f_y * (g1 + g2)
    return(concentration)
  }
  return(plume_FUN)
}
