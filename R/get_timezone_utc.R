get_timezone_utc <- function(center_coord, date_time = Sys.time()) {
  # center_coord: numeric vector c(lon, lat) in WGS84 geographic coordinates
  # date_time: POSIXct date-time for which the UTC offset is determined (default is current time)
  
  require(lutz)
  
  # IANA time zone name using lutz.
  tz_name <- lutz::tz_lookup_coords(lat = center_coord[2], 
                                    lon = center_coord[1],
                                    method = "fast", 
                                    warn = FALSE)
  
  offset_raw <- format(date_time, "%z", tz = tz_name)
  
  sign <- substr(offset_raw, 1, 1)
  hours <- substr(offset_raw, 2, 3)
  minutes <- substr(offset_raw, 4, 5)
  
  # format
  utc_offset <- paste0("utc", sign, hours, ":", minutes)
  
  return(utc_offset)
}

