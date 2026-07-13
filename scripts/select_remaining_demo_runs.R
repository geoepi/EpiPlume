args <- commandArgs(trailingOnly = TRUE)

value <- function(flag, default = NULL) {
  i <- match(flag, args)
  
  if (is.na(i)) {
    return(default)
  }
  
  if (i == length(args)) {
    stop("Missing value after ", flag, call. = FALSE)
  }
  
  args[i + 1L]
}

config_path <- value(
  "--config",
  "config/facility_exchange_demo.yml"
)

manifest_path <- value(
  "--manifest",
  "local/facility_exchange_demo/manifests/hysplit_run_manifest.csv"
)

output_path <- value("--output", NULL)

expected_remaining <- as.integer(
  value("--expected-remaining", "7")
)

if (!file.exists(config_path)) {
  stop("Config not found: ", config_path, call. = FALSE)
}

if (!file.exists(manifest_path)) {
  stop("Manifest not found: ", manifest_path, call. = FALSE)
}

if (is.na(expected_remaining) || expected_remaining < 1L) {
  stop(
    "--expected-remaining must be a positive integer.",
    call. = FALSE
  )
}

invisible(
  lapply(
    sort(list.files("R", pattern = "\\.R$", full.names = TRUE)),
    source
  )
)

cfg <- read_facility_exchange_config(config_path)

manifest <- utils::read.csv(
  manifest_path,
  stringsAsFactors = FALSE
)

states <- classify_manifest_execution_state(
  manifest,
  cfg
)

eligible_states <- c(
  "planned",
  "ready"
)

completed_states <- c(
  "completed",
  "skipped_completed"
)

unsafe_states <- c(
  "meteorology_blocked",
  "running",
  "invalid",
  "execution_failed",
  "parse_failed",
  "receptor_failed"
)

remaining <- states[
  states$execution_state %in% eligible_states,
  ,
  drop = FALSE
]

completed <- states[
  states$execution_state %in% completed_states,
  ,
  drop = FALSE
]

unsafe <- states[
  states$execution_state %in% unsafe_states,
  ,
  drop = FALSE
]

state_counts <- as.data.frame(
  table(states$execution_state),
  stringsAsFactors = FALSE
)

cat(
  "Execution-state counts:\n",
  file = stderr()
)

utils::write.table(
  state_counts,
  file = stderr(),
  row.names = FALSE,
  quote = FALSE
)

if (nrow(unsafe)) {
  stop(
    "Unsafe run states require inspection before submission: ",
    paste(
      paste(
        unsafe$run_id,
        unsafe$execution_state,
        sep = "="
      ),
      collapse = ", "
    ),
    call. = FALSE
  )
}

if (nrow(remaining) != expected_remaining) {
  stop(
    "Expected ",
    expected_remaining,
    " remaining runs but found ",
    nrow(remaining),
    ". Completed=",
    nrow(completed),
    "; remaining IDs=",
    paste(remaining$run_id, collapse = ", "),
    call. = FALSE
  )
}

if (nrow(completed) + nrow(remaining) != nrow(states)) {
  other <- states[
    !states$execution_state %in% c(
      eligible_states,
      completed_states,
      unsafe_states
    ),
    ,
    drop = FALSE
  ]
  
  stop(
    "Manifest contains unrecognized execution states: ",
    paste(
      paste(
        other$run_id,
        other$execution_state,
        sep = "="
      ),
      collapse = ", "
    ),
    call. = FALSE
  )
}

run_ids <- paste(
  remaining$run_id,
  collapse = ","
)

if (!is.null(output_path)) {
  dir.create(
    dirname(output_path),
    recursive = TRUE,
    showWarnings = FALSE
  )
  
  writeLines(
    run_ids,
    output_path
  )
}

cat(run_ids)