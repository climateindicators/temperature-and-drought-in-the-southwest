# Regression checks on the generated data for the A Closer Look: Temperature and Drought in the Southwest indicator.
#
#   Rscript tests/test-data.R
#
# The checks below are shape-independent: they hold whatever the reshape in
# R/build_data.R turns each figure into. Value snapshots, which pin the actual
# numbers so a data update fails loudly instead of passing silently, are the
# TODO at the bottom.

setwd(here::here())
source("R/utils/write_stable.R")

# Keeps the dictionary check readable when a meta.yml field is absent altogether.
`%||%` <- function(a, b) if (is.null(a)) b else a

failures <- character()
check <- function(label, ok) {
  ok <- isTRUE(ok)
  cat(sprintf("  [%s] %s\n", if (ok) "PASS" else "FAIL", label))
  if (!ok) failures <<- c(failures, label)
  invisible(ok)
}

rd <- function(f) {
  readr::read_csv(file.path("data", f),
                  col_types = readr::cols(.default = readr::col_character()),
                  na = character(), progress = FALSE)
}

meta <- yaml::read_yaml("data/meta.yml")

cat("\nData dictionary\n")
check("meta.yml documents 3 dataset(s)", length(meta$datasets) == 3L)
check("meta.yml has no timestamp",
      !any(grepl("\\d{4}-\\d{2}-\\d{2}T|Sys\\.time|generated_at",
                 readLines("data/meta.yml", warn = FALSE))))

for (ds in meta$datasets) {
  df   <- rd(ds$file)
  cols <- vapply(ds$columns, function(x) x$name, character(1))
  check(sprintf("%s: meta.yml lists the columns the file actually has", ds$file),
        identical(cols, names(df)))
  check(sprintf("%s: meta.yml row count matches the file", ds$file),
        identical(as.integer(ds$rows), nrow(df)))
  check(sprintf("%s: every column has a type and a description", ds$file),
        all(vapply(ds$columns, function(x) nzchar(x$type %||% "") && nzchar(x$description %||% ""), logical(1))))
  check(sprintf("%s: source file is still present and unchanged", ds$file),
        identical(file_sha256(file.path("data-raw", ds$source_file)), ds$source_sha256))
  check(sprintf("%s: no blank rows", ds$file), nrow(df) > 0L)
}

cat("\nFile hygiene\n")
for (f in list.files("data", pattern = "[.](csv|yml)$", full.names = TRUE)) {
  check(sprintf("%s is UTF-8, LF, no BOM, no mojibake", basename(f)),
        tryCatch({ assert_clean_output(f); TRUE },
                 error = function(e) { cat("      ", conditionMessage(e), "\n"); FALSE }))
}

cat("\nValue snapshots\n")

# Values are compared as the strings the build wrote, not as numbers, because
# the source carries up to 10 significant digits and a numeric comparison would
# pass on a build that quietly rounded them.
row_str <- function(d, i) paste(unlist(d[i, ]), collapse = "|")

snapshot <- function(file, rows, first, last, lowest, highest) {
  d <- rd(file)
  v <- suppressWarnings(as.numeric(d$value))
  check(sprintf("%s: %d rows", file, rows), nrow(d) == rows)
  check(sprintf("%s: first row is %s", file, first), identical(row_str(d, 1L), first))
  check(sprintf("%s: last row is %s", file, last), identical(row_str(d, nrow(d)), last))
  check(sprintf("%s: lowest value is %s", file, lowest), identical(d$value[which.min(v)], lowest))
  check(sprintf("%s: highest value is %s", file, highest), identical(d$value[which.max(v)], highest))
}

# One row per group: key, expected row count, expected lowest and highest value.
group_span <- function(file, group, expected) {
  d <- rd(file)
  for (i in seq_len(nrow(expected))) {
    s <- d[d[[group]] == expected$key[i], ]
    v <- suppressWarnings(as.numeric(s$value))
    check(
      sprintf("%s: %s has %d rows spanning %s to %s",
              file, expected$key[i], expected$n[i], expected$lowest[i], expected$highest[i]),
      nrow(s) == expected$n[i] &&
        identical(s$value[which.min(v)], expected$lowest[i]) &&
        identical(s$value[which.max(v)], expected$highest[i])
    )
  }
}

snapshot(
  "southwest_temperature_anomaly.csv", 38L,
  "201|Arizona|01|1.643725775",
  "4207|Utah|07|1.885529716",
  "1.279812661", "2.058228359"
)
group_span("southwest_temperature_anomaly.csv", "state", data.frame(
  key     = c("Arizona", "California", "Colorado", "Nevada", "New Mexico", "Utah"),
  n       = c(7L, 7L, 5L, 4L, 8L, 7L),
  lowest  = c("1.555434432", "1.279812661", "1.302091408", "1.301776486", "1.455208333", "1.402834302"),
  highest = c("1.938921189", "2.058228359", "1.849604328", "1.882574289", "1.904699612", "2.025072674")
))

snapshot(
  "southwest_drought_monitor_area.csv", 6260L,
  "2000-01-04|D0|D0 Abnormally dry|33.08880529",
  "2023-12-26|D4|D4 Exceptional drought|1.127447563",
  "0", "80.91350314"
)
group_span("southwest_drought_monitor_area.csv", "category", data.frame(
  key     = c("D0", "D1", "D2", "D3", "D4"),
  n       = rep(1252L, 5),
  lowest  = c("0.970570848", "0", "0", "0", "0"),
  highest = c("80.91350314", "56.66080901", "55.48423012", "49.37408261", "40.07050644")
))

snapshot(
  "southwest_palmer_index.csv", 258L,
  "1895|annual|Annual avg|1.848723124",
  "2023|nine_year|9-yr avg|-0.99941829",
  "-4.672334803", "4.928696701"
)
group_span("southwest_palmer_index.csv", "series", data.frame(
  key     = c("annual", "nine_year"),
  n       = c(129L, 129L),
  lowest  = c("-4.672334803", "-2.574773928"),
  highest = c("4.928696701", "2.719898742")
))

cat("\nAgreement with EPA's published Key Points\n")
# These catch a reshape that reads the data differently than EPA's own prose
# does, which no row count or column name can.

d1 <- rd("southwest_temperature_anomaly.csv")
d2 <- rd("southwest_drought_monitor_area.csv")
d3 <- rd("southwest_palmer_index.csv")

v1 <- suppressWarnings(as.numeric(d1$value))
check("Figure 1: every climate division was warmer than the long-term average, some by more than 2°F",
      all(v1 > 0) && max(v1) > 2)

# The five Drought Monitor classes partition the dry area rather than nesting,
# so their sum is the share of the region that was at least abnormally dry.
# EPA's Key Points call out two extended periods, 2002-2005 and 2012-2023, when
# "nearly the entire region" reached that state; both should approach 100%.
total <- tapply(as.numeric(d2$value), d2$date, sum)
dates <- as.Date(names(total))
window_max <- function(a, b) max(total[dates >= as.Date(a) & dates <= as.Date(b)])
check("Figure 2: both 2002-2005 and 2012-2023 reach ~100 percent of land area abnormally dry or worse",
      window_max("2002-01-01", "2005-12-31") > 99 &&
        window_max("2012-01-01", "2023-12-31") > 99)

# EPA's Key Points name three wetter periods (1900s, 1940s, 1980s) and say
# conditions since 1990 include some of the most persistent droughts on record.
ann <- d3[d3$series == "annual", ]
av  <- suppressWarnings(as.numeric(ann$value))
ayr <- as.integer(ann$year)
decade_peak <- function(dec) max(av[ayr >= dec & ayr < dec + 10])
check("Figure 3: the 1900s, 1940s, and 1980s each have a wet (annual PDSI > 4) year",
      decade_peak(1900) > 4 && decade_peak(1940) > 4 && decade_peak(1980) > 4)
check("Figure 3: the driest annual value on record falls since 1990",
      ayr[which.min(av)] >= 1990)

cat("\n")
if (length(failures)) {
  cat(sprintf("%d FAILED:\n", length(failures)))
  for (f in failures) cat("  -", f, "\n")
  quit(status = 1L)
}
cat("All data checks passed.\n")
