#' Resolve a local HYSPLIT executable without installing it
resolve_hysplit_executable <- function(cfg, must_exist = TRUE) {
  configured <- cfg$hysplit$executable %||% cfg$hysplit$executable_path %||% cfg$hysplit$executable_directory
  candidate <- configured
  if (is.null(candidate) || length(candidate) != 1L || is.na(candidate) || !nzchar(trimws(candidate))) candidate <- Sys.getenv("HYSPLIT_EXECUTABLE", unset = NA_character_)
  if (is.na(candidate) || !nzchar(trimws(candidate))) {
    if (!isTRUE(must_exist)) return(NA_character_)
    stop("No HYSPLIT executable path is configured and `HYSPLIT_EXECUTABLE` is unset.", call. = FALSE)
  }
  candidate <- path.expand(candidate)
  if (!file.exists(candidate)) {
    if (!isTRUE(must_exist)) return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
    stop("HYSPLIT executable does not exist: ", candidate, call. = FALSE)
  }
  if (dir.exists(candidate)) stop("HYSPLIT executable path points to a directory: ", candidate, call. = FALSE)
  resolved <- normalizePath(candidate, winslash = "/", mustWork = TRUE)
  if (.Platform$OS.type != "windows" && file.access(resolved, mode = 1L) != 0L) stop("HYSPLIT file exists but is not executable: ", resolved, call. = FALSE)
  resolved
}

`%||%` <- function(x, y) if (is.null(x)) y else x
