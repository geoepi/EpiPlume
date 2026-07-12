#' Build a square directed facility connectivity matrix
build_facility_connectivity_matrices <- function(dyad_summary, facilities, value = c("intercept_frequency", "n_intercept_runs", "total_particle_count_cumulative", "total_decayed_mass_cumulative")) {
  value <- match.arg(value); validate_facilities(facilities); ids <- sort(facilities$facility_id); matrix <- base::matrix(NA_real_, nrow = length(ids), ncol = length(ids), dimnames = list(ids, ids))
  if (nrow(dyad_summary)) for (i in seq_len(nrow(dyad_summary))) matrix[dyad_summary$source_id[i], dyad_summary$receptor_id[i]] <- dyad_summary[[value]][i]
  diag(matrix) <- NA_real_; attr(matrix, "connectivity_metadata") <- list(value = value, interpretation = switch(value, intercept_frequency = "Fraction of evaluated source runs intercepting the receptor", n_intercept_runs = "Count of intercepting runs", total_particle_count_cumulative = "Sum of hourly particle-count summaries", total_decayed_mass_cumulative = "Sum of decayed mass summaries"), number_of_dyads = nrow(dyad_summary)); matrix
}
