args <- commandArgs(trailingOnly = TRUE)
value_after <- function(flag, default = NULL) { i <- match(flag, args); if (is.na(i)) default else { if (i == length(args)) stop("Missing value after ", flag); args[i + 1L] } }
config <- value_after("--config", "config/facility_exchange_demo.yml"); Sys.setenv(EPIPLUME_CONFIG = config)
source("R/read_facility_exchange_config.R"); cfg <- read_facility_exchange_config(config); store <- cfg$pipeline$targets_store
if ("--destroy" %in% args) targets::tar_destroy(store = store, destroy = "all", ask = FALSE)
if ("--outdated" %in% args) { print(targets::tar_outdated(script = "_targets.R", store = store)); quit(save = "no", status = 0L) }
workers <- as.integer(value_after("--workers", "1")); if (is.na(workers) || workers != 1L) stop("Only one worker is currently supported.", call. = FALSE)
names_arg <- value_after("--names", NULL); names <- if (is.null(names_arg)) NULL else strsplit(names_arg, ",", fixed = TRUE)[[1]]
reporter <- value_after("--reporter", "balanced")
tryCatch({ if (is.null(names)) targets::tar_make(script = "_targets.R", store = store, reporter = reporter) else targets::tar_make(script = "_targets.R", store = store, names = tidyselect::all_of(names), reporter = reporter); meta <- targets::tar_meta(store = store); cat("targets_recorded:", nrow(meta), "\nfailed_targets:", sum(!is.na(meta$error)), "\nstore:", store, "\n") }, error = function(e) { message("PIPELINE ERROR: ", conditionMessage(e)); quit(save = "no", status = 1L) })
