#!/usr/bin/env Rscript

cat("splitr compatibility diagnostic\n")
if (!requireNamespace("splitr", quietly = TRUE)) stop("Package `splitr` is not installed.", call. = FALSE)

description <- packageDescription("splitr")
cat("packageVersion: ", as.character(utils::packageVersion("splitr")), "\n", sep = "")
cat("packageLibrary: ", find.package("splitr"), "\n", sep = "")
cat("DESCRIPTION remote metadata:\n")
remote <- description[grepl("^(Remote|Github|GitLab|Bitbucket|Revision|Config/Needs)", names(description), ignore.case = TRUE)]
if (length(remote)) print(remote) else cat("  <none recorded>\n")

ns <- asNamespace("splitr")
for (name in c("get_monthly_filenames", "download_met_files")) {
  present <- exists(name, ns, inherits = FALSE)
  cat(name, ": ", if (present) "present" else "absent", "\n", sep = "")
  if (present) print(formals(get(name, ns, inherits = FALSE)))
}

all_names <- ls(ns, all.names = TRUE)
matching <- all_names[grepl("monthly|filename|download|meteorology|met", all_names, ignore.case = TRUE)]
matching <- matching[vapply(matching, function(name) is.function(get(name, ns, inherits = FALSE)), logical(1))]
cat("Matching namespace functions:\n")
if (length(matching)) {
  for (name in matching) {
    cat("- ", name, "\n", sep = "")
    print(formals(get(name, ns, inherits = FALSE)))
  }
} else cat("  <none>\n")

platform <- Sys.info()[["sysname"]]
suffix <- if (.Platform$OS.type == "windows") ".exe" else ""
binary_directory <- system.file(if (.Platform$OS.type == "windows") "win" else if (identical(platform, "Darwin")) "osx" else "linux-amd64", package = "splitr")
binary_paths <- file.path(binary_directory, paste0(c("hycs_std", "parhplot"), suffix))
cat("HYSPLIT binaries:\n")
for (path in binary_paths) {
  info <- file.info(path)
  cat("- ", path, " exists=", file.exists(path), " executable=", if (file.exists(path)) file.access(path, 1L) == 0L else NA, " mode=", if (file.exists(path)) as.character(info$mode) else NA, "\n", sep = "")
}
cat("operatingSystem: ", paste(Sys.info()[c("sysname", "release", "machine")], collapse = " "), "\n", sep = "")
cat("R.version: ", R.version.string, "\n", sep = "")
