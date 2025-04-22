random_infect_dates <- function(year, month, fast_detect = 7, slow_detect = 20) {

  stopifnot(is.numeric(year), length(year) == 1,
            is.numeric(month), length(month) == 1,
            month %in% 1:12)
  
  # first day of that month
  start <- as.Date(sprintf("%04d-%02d-01", year, month))
  
  # first day of the next, then back one
  next_month_start <- seq.Date(start, length = 2, by = "1 month")[2]
  end <- next_month_start - 1
  
  # possible dates, sample one at random
  candidates <- seq.Date(start, end, by = "day")
  
  # infection date. Between 7 nad 20 days to detect
  inf_date <- round(runif(1, fast_detect, slow_detect), 0)
  release_date = sample(candidates, 1)
  infection_date = release_date - days(inf_date)
  
  return(
    
    list(
      release_date = release_date,
      infection_date = infection_date
    )
  )

}