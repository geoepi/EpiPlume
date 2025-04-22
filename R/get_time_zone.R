# given long and lat, return utm projection
get_time_zone <- function(source_origin) {
  # validate input
  if (!is.numeric(source_origin) || length(source_origin) != 2) {
    stop("must be a numeric vector of length 2: c(lon, lat)")
  }
  
  lon <- source_origin[1]
  lat <- source_origin[2]
  
  # compute UTM zone (1–60)
  zone <- floor((lon + 180) / 6) + 1
  
  # hemisphere suffix
  hemi <- if (lat >= 0) "+north" else "+south"
  
  # assemble proj4 string
  sprintf("+proj=utm +zone=%d %s +datum=WGS84 +units=m +no_defs",
          zone, hemi)
}