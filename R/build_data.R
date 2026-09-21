# Build tidy long-format data for the A Closer Look: Temperature and Drought in the Southwest indicator.
#
#   Rscript R/build_data.R
#
# Reads EPA's published figure CSVs in data-raw/ and writes data/*.csv plus
# data/meta.yml. Rerunning with unchanged inputs produces byte-identical output.
# Nothing here touches the network.
#
# Generated as a stub by the build-indicator skill. Each figure below has a
# `todo_reshape()` call standing where its reshape belongs. Replace that line,
# then delete the todo_reshape() helper once no call to it remains.
#
# TO UPDATE THE DATA: drop replacement CSVs into data-raw/ and rerun. Headers
# are asserted, not assumed, so a renamed or reordered column stops the build.

suppressPackageStartupMessages({
  library(dplyr)
})

root <- here::here()
source(file.path(root, "R/utils/epa_csv.R"))
source(file.path(root, "R/utils/write_stable.R"))

raw_dir <- file.path(root, "data-raw")
out_dir <- file.path(root, "data")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- Indicator constants -----------------------------------------------------

INDICATOR <- list(
  name                    = "A Closer Look: Temperature and Drought in the Southwest",
  slug                    = "temperature-and-drought-in-the-southwest",
  publisher               = "U.S. Environmental Protection Agency",
  source_page             = "https://19january2025snapshot.epa.gov/climate-indicators/southwest/index.html",
  technical_documentation = "https://19january2025snapshot.epa.gov/system/files/documents/2024-12/southwest_td.pdf",
  rights                  = "Public domain, work of the U.S. Government (17 U.S.C. 105)"
)

# ---- Figure 1: Average Temperatures in the Southwestern United States, 2000-2023 Versus Long-Term Average ----

f1_path <- file.path(raw_dir, "southwest_fig-1.csv")
f1_meta <- read_epa_preamble(f1_path)
f1_raw  <- read_epa_csv(f1_path)

F1_KEY   <- "Climate Division ID"
F1_VALUE <- "T Anomaly"

assert_headers(
  f1_raw,
  id_cols          = F1_KEY,
  expected_headers = F1_VALUE,
  what             = "southwest_fig-1.csv"
)

# NOAA climate division IDs encode <state code><two-digit division number>.
# EPA's own column carries no readable state name, and this site has no
# climate-division map geometry to draw a real choropleth from (see
# drought.R's Figure 3 for the same constraint), so the site chart groups
# divisions by state instead; decoding that state code here, rather than in
# the site's chart code, is what keeps it tested and reproducible. Limited to
# the six states this indicator covers: an unrecognised code stops the build
# instead of mislabelling a division.
F1_STATE_CODES <- c(
  `2`  = "Arizona",
  `4`  = "California",
  `5`  = "Colorado",
  `26` = "Nevada",
  `29` = "New Mexico",
  `42` = "Utah"
)

f1_id         <- f1_raw[[F1_KEY]]
f1_state_code <- substr(f1_id, 1, nchar(f1_id) - 2)
f1_division   <- substr(f1_id, nchar(f1_id) - 1, nchar(f1_id))

if (any(!f1_state_code %in% names(F1_STATE_CODES))) {
  stop(
    "southwest_fig-1.csv: a climate division ID's state code is not one of the\n",
    "six southwestern states this indicator covers.\n  ids: ",
    paste(unique(f1_id[!f1_state_code %in% names(F1_STATE_CODES)]), collapse = ", "),
    call. = FALSE
  )
}

# Already one row per climate division; no pivot needed. Row order is by
# numeric division code rather than EPA's own (already ascending, but sorting
# explicitly makes that an invariant instead of an accident).
f1 <- f1_raw |>
  transmute(
    climate_division_id = .data[[F1_KEY]],
    state                = unname(F1_STATE_CODES[f1_state_code]),
    division             = f1_division,
    value                = .data[[F1_VALUE]]
  )
f1 <- f1[order(as.integer(f1$climate_division_id)), ]

assert_conservation(f1_raw, F1_VALUE, nrow(f1), "southwest_fig-1.csv")

write_csv_stable(f1, file.path(out_dir, "southwest_temperature_anomaly.csv"))

# ---- Figure 2: Southwestern U.S. Lands Under Drought Conditions, 2000-2023 ----

f2_path <- file.path(raw_dir, "southwest_fig-2.csv")
f2_meta <- read_epa_preamble(f2_path)
f2_raw  <- read_epa_csv(f2_path)

# D0 through D4, keyed for code and labelled with EPA's own column header,
# given in increasing severity (EPA's file has them in the opposite order).
F2_SERIES <- c(
  D0 = "D0 Abnormally dry",
  D1 = "D1 Moderate drought",
  D2 = "D2 Severe drought",
  D3 = "D3 Extreme drought",
  D4 = "D4 Exceptional drought"
)

assert_headers(
  f2_raw,
  id_cols          = c("Month", "Day", "Year"),
  expected_headers = unname(F2_SERIES),
  what             = "southwest_fig-2.csv"
)

# The five classes partition the dry area rather than nesting, matching the
# national Drought indicator's Figure 4 of the same shape.
f2 <- f2_raw |>
  tidyr::pivot_longer(
    cols      = all_of(unname(F2_SERIES)),
    names_to  = "category_label",
    values_to = "value"
  ) |>
  transmute(
    date           = sprintf("%04d-%02d-%02d", as.integer(Year), as.integer(Month), as.integer(Day)),
    category       = names(F2_SERIES)[match(category_label, F2_SERIES)],
    category_label = category_label,
    value          = value
  )
f2 <- f2[order(match(f2$category, names(F2_SERIES)), as.Date(f2$date)), ]

stopifnot(
  "southwest_fig-2.csv: a Month/Day/Year triple appears twice" =
    !anyDuplicated(paste(f2$date, f2$category)),
  "southwest_fig-2.csv: a date did not format as ISO 8601" =
    all(grepl("^\\d{4}-\\d{2}-\\d{2}$", f2$date))
)

assert_conservation(f2_raw, unname(F2_SERIES), nrow(f2), "southwest_fig-2.csv")

write_csv_stable(f2, file.path(out_dir, "southwest_drought_monitor_area.csv"))

# ---- Figure 3: Drought Severity in the Southwestern United States, 1895-2023 ----

f3_path <- file.path(raw_dir, "southwest_fig-3.csv")
f3_meta <- read_epa_preamble(f3_path)
f3_raw  <- read_epa_csv(f3_path)

# The two series, keyed for code and labelled with EPA's own column header, so
# a chart legend cannot drift from the published file. Vector order is also
# the output row order.
F3_SERIES <- c(annual = "Annual avg", nine_year = "9-yr avg")

assert_headers(
  f3_raw,
  id_cols          = "Year",
  expected_headers = unname(F3_SERIES),
  what             = "southwest_fig-3.csv"
)

f3 <- f3_raw |>
  tidyr::pivot_longer(
    cols      = all_of(unname(F3_SERIES)),
    names_to  = "series_label",
    values_to = "value"
  ) |>
  transmute(
    year         = Year,
    series       = names(F3_SERIES)[match(series_label, F3_SERIES)],
    series_label = series_label,
    value        = value
  )
f3 <- f3[order(match(f3$series, names(F3_SERIES)), as.integer(f3$year)), ]

assert_conservation(f3_raw, unname(F3_SERIES), nrow(f3), "southwest_fig-3.csv")

write_csv_stable(f3, file.path(out_dir, "southwest_palmer_index.csv"))

# ---- Data dictionary ---------------------------------------------------------

col <- function(name, type, description) {
  list(name = name, type = type, description = description)
}

meta <- list(
  indicator = INDICATOR,
  datasets = list(
    list(
      file            = "southwest_temperature_anomaly.csv",
      figure          = "Figure 1",
      figure_title    = f1_meta$title,
      source_file     = "southwest_fig-1.csv",
      source_sha256   = file_sha256(f1_path),
      source_encoding = "windows-1252",
      data_source     = f1_meta$data_source,
      web_update      = f1_meta$web_update,
      unit            = f1_meta$units,
      rows            = nrow(f1),
      columns         = list(
        col("climate_division_id", "string", "NOAA climate division code, as EPA publishes it."),
        col("state", "string", "State name, decoded from the leading digits of climate_division_id via NOAA's state numbering."),
        col("division", "string", "Two-digit division number within the state, decoded from the trailing digits of climate_division_id."),
        col("value", "number", "Average air temperature, 2000-2023, minus the long-term average (1895-2023), in degrees Fahrenheit.")
      )
    ),
    list(
      file            = "southwest_drought_monitor_area.csv",
      figure          = "Figure 2",
      figure_title    = f2_meta$title,
      source_file     = "southwest_fig-2.csv",
      source_sha256   = file_sha256(f2_path),
      source_encoding = "UTF-8",
      data_source     = f2_meta$data_source,
      web_update      = f2_meta$web_update,
      unit            = f2_meta$units,
      rows            = nrow(f2),
      columns         = list(
        col("date", "date", "The weekly U.S. Drought Monitor issue date, ISO 8601, 2000 through 2023."),
        col("category", "string", "U.S. Drought Monitor severity class, D0 through D4."),
        col("category_label", "string", "EPA's own column header for the class, reproduced verbatim."),
        col("value", "number", "Percent of land area across the six southwestern states in that class. The five classes partition the dry area, so their sum is the share that was at least abnormally dry.")
      )
    ),
    list(
      file            = "southwest_palmer_index.csv",
      figure          = "Figure 3",
      figure_title    = f3_meta$title,
      source_file     = "southwest_fig-3.csv",
      source_sha256   = file_sha256(f3_path),
      source_encoding = "UTF-8",
      data_source     = f3_meta$data_source,
      web_update      = f3_meta$web_update,
      unit            = f3_meta$units,
      rows            = nrow(f3),
      columns         = list(
        col("year", "integer", "Calendar year, 1895 through 2023."),
        col("series", "string", "Series key: `annual` for the single-year average, `nine_year` for the nine-year weighted average EPA draws as the thicker line."),
        col("series_label", "string", "EPA's own column header for the series, reproduced verbatim."),
        col("value", "number", "Palmer Drought Severity Index averaged over six southwestern states. Negative is drier than average, positive is wetter.")
      )
    )
  )
)

write_yaml_stable(meta, file.path(out_dir, "meta.yml"))

# ---- Verify what was written -------------------------------------------------

written <- list.files(out_dir, pattern = "[.](csv|yml)$", full.names = TRUE)
invisible(lapply(written, assert_clean_output))

cat("\nWrote:\n")
for (p in written) {
  cat(sprintf("  %-34s %8d bytes  %s\n", basename(p), file.size(p), substr(file_sha256(p), 1, 12)))
}
