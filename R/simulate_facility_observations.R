#' Simulate normalized observations and separate source truth
simulate_facility_observations <- function(facilities, cfg) {
  validate_facilities(facilities); set.seed(cfg$project$random_seed + 1L)
  n <- nrow(facilities); counts <- cfg$simulation
  statuses <- c(rep("positive", counts$n_positive_facilities), rep("negative", counts$n_negative_facilities), rep("unknown", counts$n_unknown_facilities))
  statuses <- sample(statuses, n, replace = FALSE)
  dates <- seq(as.Date(counts$observation_start), as.Date(counts$observation_end), by = "day")
  primary <- data.frame(facility_id = facilities$facility_id, observation_date = format(sample(dates, n, replace = TRUE), "%Y-%m-%d"), observation_status = statuses, stringsAsFactors = FALSE)
  repeat_idx <- seq_len(max(1L, floor(n * 0.05)))
  repeated <- primary[repeat_idx, , drop = FALSE]
  repeated$observation_date <- format(pmin(as.Date(repeated$observation_date) + 3, max(dates)), "%Y-%m-%d")
  observations <- rbind(primary, repeated)
  observations$observation_id <- sprintf("O%04d", seq_len(nrow(observations)))
  observations <- observations[c("observation_id", "facility_id", "observation_date", "observation_status")]
  validate_observations(observations, facilities)
  positives <- facilities$facility_id[statuses == "positive"]
  truth <- data.frame(facility_id = positives[seq_len(min(3L, length(positives)))], seeded_source = TRUE, seed_rank = seq_len(min(3L, length(positives))), stringsAsFactors = FALSE)
  list(observations = observations, truth = truth)
}
