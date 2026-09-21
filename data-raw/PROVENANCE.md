# Provenance

Every file in this directory is reproduced unmodified from EPA's published
indicator page and its per-figure data downloads. To update the data, replace the
file and rerun `Rscript R/build_data.R`.

## Indicator page

- `source-page.html`  \
  <https://19january2025snapshot.epa.gov/climate-indicators/southwest/index.html>  \
  sha256 `3fd6e6a2eeb355e7494c78fa4bd3caf4188318176042147d96abd74a9ee6cd7d`

Technical documentation: <https://19january2025snapshot.epa.gov/system/files/documents/2024-12/southwest_td.pdf>

## Figure data

- `southwest_fig-1.csv`  \
  <https://19january2025snapshot.epa.gov/system/files/other-files/2024-12/southwest_fig-1.csv>  \
  sha256 `099dd589f6acc67713b3d3b8a22d8923707173caa9e00759a4bbc0b36e4bbcef`  \
  encoding windows-1252, 38 data rows, columns: `Climate Division ID`, `T Anomaly`  \
  title: Figure 1. Average Temperatures in the Southwestern United States, 2000-2023 Versus Long-Term Average  \
  data source: NOAA, 2024; web update: December 2024; units: °F

- `southwest_fig-2.csv`  \
  <https://19january2025snapshot.epa.gov/sites/default/files/2021-03/southwest_fig-2.csv>  \
  sha256 `0f20c6f1341a187e1ec50e0b26ed26ccef060bf99808f9a16226cb0aee0ea75e`  \
  encoding UTF-8, 1252 data rows, columns: `Month`, `Day`, `Year`, `D0 Abnormally dry`, `D1 Moderate drought`, `D2 Severe drought`, `D3 Extreme drought`, `D4 Exceptional drought`  \
  title: Figure 2. Southwestern U.S. Lands Under Drought Conditions, 2000-2023  \
  data source: National Drought Mitigation Center, 2024; web update: December 2024; units: percent of land area

- `southwest_fig-3.csv`  \
  <https://19january2025snapshot.epa.gov/sites/default/files/2021-03/southwest_fig-3.csv>  \
  sha256 `4fe8671dfac1a13d35af5989df14af75e31e4a697f608a64ae7234303d5cd099`  \
  encoding UTF-8, 129 data rows, columns: `Year`, `Annual avg`, `9-yr avg`  \
  title: Figure 3. Drought Severity in the Southwestern United States, 1895-2023  \
  data source: NOAA, 2024; web update: December 2024; units: Palmer Drought Severity Index
