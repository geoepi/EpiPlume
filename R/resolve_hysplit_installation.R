#' Resolve the HYSPLIT binary directory used by splitr
resolve_hysplit_installation <- function(cfg, must_exist = TRUE) {
  configured <- cfg$hysplit$hysplit_install_directory
  if (is.null(configured) || length(configured) != 1L || is.na(configured) || !nzchar(trimws(configured))) {
    configured <- Sys.getenv("HYSPLIT_INSTALL_DIRECTORY", unset = NA_character_)
  }
  if (is.na(configured) || !nzchar(trimws(configured))) {
    if (requireNamespace("splitr", quietly = TRUE)) {
      platform <- switch(.Platform$OS.type, windows = "win", unix = if (Sys.info()[["sysname"]] == "Darwin") "osx" else "linux-amd64")
      configured <- system.file(platform, package = "splitr")
    }
  }
  if (is.null(configured) || length(configured) != 1L || is.na(configured) || !nzchar(configured)) {
    if (!isTRUE(must_exist)) return(NA_character_)
    stop("No HYSPLIT installation directory is configured, available from `HYSPLIT_INSTALL_DIRECTORY`, or bundled with splitr.", call. = FALSE)
  }
  directory <- path.expand(configured)
  if (!dir.exists(directory)) {
    if (!isTRUE(must_exist)) return(paste0(normalizePath(directory, winslash = "/", mustWork = FALSE), "/"))
    stop("HYSPLIT installation directory does not exist: ", directory, call. = FALSE)
  }
  suffix <- if (.Platform$OS.type == "windows") ".exe" else ""
  required <- file.path(directory, paste0(c("hycs_std", "parhplot"), suffix))
  missing <- required[!file.exists(required) | dir.exists(required)]
  if (length(missing) && isTRUE(must_exist)) stop("HYSPLIT installation is missing required binary file(s): ", paste(basename(missing), collapse = ", "), call. = FALSE)
  if (.Platform$OS.type != "windows" && isTRUE(must_exist) && any(file.access(required, mode = 1L) != 0L)) stop("One or more HYSPLIT binary files are not executable in: ", directory, call. = FALSE)
  paste0(normalizePath(directory, winslash = "/", mustWork = TRUE), "/")
}
