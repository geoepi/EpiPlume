#' Combine compatible one-run exchange tables without collapsing runs
combine_source_receptor_exchanges <- function(exchange_tables) {
  if (!length(exchange_tables)) return(data.frame())
  schemas <- lapply(exchange_tables, names); if (!all(vapply(schemas, identical, logical(1), schemas[[1]]))) stop("Exchange tables have incompatible schemas.", call. = FALSE)
  out <- do.call(rbind, exchange_tables); if (!nrow(out)) return(data.frame())
  out$release_start <- as.POSIXct(out$release_start, tz = "UTC")
  out$release_date <- as.Date(out$release_start); out$release_hour_utc <- as.integer(format(out$release_start, "%H", tz = "UTC")); out$release_week <- format(out$release_start, "%G-W%V", tz = "UTC"); out$release_month <- format(out$release_start, "%Y-%m", tz = "UTC"); out$source_receptor_id <- paste(out$source_id, out$receptor_id, sep = "__")
  out <- out[order(out$release_start, out$source_id, out$receptor_id, out$run_id), ]; rownames(out) <- NULL; out
}
