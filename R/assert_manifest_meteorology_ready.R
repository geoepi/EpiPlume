assert_manifest_meteorology_ready <- function(preparation) {
  if (!is.list(preparation) || !identical(preparation$status, "ready") || any(!preparation$run_readiness$meteorology_ready)) stop("Manifest meteorology readiness is required before HYSPLIT execution.", call. = FALSE)
  invisible(preparation)
}
