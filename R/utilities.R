source_dir <- function(directory_path) {
  
  if (!dir.exists(directory_path)) {
    stop("The specified directory does not exist.")
  }
  
  file_list <- list.files(path = directory_path, pattern = "\\.R$", full.names = TRUE)
  
  for (file in file_list) {
    source(file)
  }
}


convert_doy_to_date <- function(year, day_of_year) {
  as.Date(paste(year, day_of_year, sep="-"), format="%Y-%j")
}

convert_decimal_date <- function(decimal_date) {
  
  year <- floor(decimal_date)
  fraction <- decimal_date - year
  
  if (leap_year(year)) {
    days_in_year <- 366
  } else {
    days_in_year <- 365
  }
  
  days <- fraction * days_in_year
  
  date <- ymd(paste0(year, "-01-01")) + days
  
  return(format(date, "%Y-%m-%d"))
}

get_gamma_params <- function(mean, range) {
  
  variance <- (range[2] - range[1])^2 / 16
  alpha <- mean^2 / variance
  beta <- variance / mean
  
  return(list(shape = alpha, scale = beta))
}