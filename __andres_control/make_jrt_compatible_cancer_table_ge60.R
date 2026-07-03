.t0 <- Sys.time()

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(file_arg) == 1) {
  dirname(normalizePath(sub("^--file=", "", file_arg), winslash = "/", mustWork = TRUE))
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

project_root <- if (basename(script_dir) == "__andres_control") {
  normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(script_dir, winslash = "/", mustWork = TRUE)
}

path_jrt <- file.path(
  project_root,
  "JRT_20260702_cancer",
  "Alcohol Attributable mortality (CANCER).txt"
)
path_aaf <- file.path(
  project_root,
  "__andres_control",
  "tabla_aaf_who2024_sexo_causa_ano.csv"
)
path_deis_2012_2023 <- file.path(
  project_root,
  "ACC1240138-Potentially-Avoidable-Injury-Mortality-in-Chile--bc6359e",
  "udpate jun 26",
  "DEFUNCIONES_DEIS_12_23_15plus.parquet"
)
path_deis_2024 <- file.path(
  project_root,
  "ACC1240138-Potentially-Avoidable-Injury-Mortality-in-Chile--bc6359e",
  "udpate jun 26",
  "DEFUNCIONES_FUENTE_DEIS_2024_2026_09062026.csv"
)
out_dir <- file.path(project_root, "JRT_20260702_cancer")

required_files <- c(path_jrt, path_aaf, path_deis_2012_2023, path_deis_2024)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  stop("Missing required file(s): ", paste(missing_files, collapse = "; "))
}

icd_codes_s6 <- function(letter, numbers, suffix = c(0:9, "X")) {
  as.vector(outer(sprintf("%s%02d", letter, numbers), suffix, paste0))
}

clean_icd10 <- function(x) {
  out <- toupper(gsub("[^A-Za-z0-9]", "", as.character(x)))
  out[is.na(x)] <- NA_character_
  out
}

parse_aaf_ci <- function(x, group_index) {
  match <- stringr::str_match(
    x,
    "^\\s*(-?[0-9.]+)\\s*\\((-?[0-9.]+),\\s*(-?[0-9.]+)\\)\\s*$"
  )
  as.numeric(match[, group_index])
}

ref_cancer <- readr::read_tsv(
  path_jrt,
  locale = readr::locale(decimal_mark = ","),
  show_col_types = FALSE
)

ref_keys <- ref_cancer |>
  dplyr::distinct(Year, disease, sex, age_group)

target_years <- sort(unique(ref_cancer$Year))

aaf_name_map <- c(
  "Breast Cancer" = "Breast Cancer",
  "Colon and rectum Cancer" = "Colorectal Cancer",
  "Larynx Cancer" = "Larynx Cancer",
  "Liver Cancer" = "Liver Cancer",
  "Oesophagus Cancer" = "Oesophagus Cancer",
  "Oral Cavity and Pharynx Cancer" = "Oral Cavity and Pharynx Cancer",
  "Pancreatic Cancer" = "Pancreatic Cancer",
  "Stomach Cancer" = "Stomach Cancer"
)

aaf_long <- readr::read_csv(path_aaf, show_col_types = FALSE) |>
  dplyr::filter(Cause %in% names(aaf_name_map)) |>
  tidyr::pivot_longer(
    cols = -c(Cause, Year),
    names_to = "sex_age",
    values_to = "aaf_ci"
  ) |>
  dplyr::mutate(
    disease = unname(aaf_name_map[Cause]),
    sex = dplyr::if_else(grepl("^Women", sex_age), "Female", "Male"),
    age_group = sub("^(Women|Men)\\s+", "", sex_age),
    AAF = parse_aaf_ci(aaf_ci, 2),
    LL = parse_aaf_ci(aaf_ci, 3),
    UL = parse_aaf_ci(aaf_ci, 4)
  ) |>
  dplyr::select(Year, disease, sex, age_group, AAF, LL, UL)

deis_2012_2023 <- arrow::read_parquet(path_deis_2012_2023) |>
  dplyr::transmute(
    year = as.integer(year),
    gender = as.character(gender),
    age = as.integer(age),
    diag1 = as.character(diag1),
    diag2 = as.character(diag2)
  )

deis_2024_raw <- readr::read_delim(
  path_deis_2024,
  delim = ";",
  locale = readr::locale(encoding = "Latin1"),
  show_col_types = FALSE
)
year_col_2024 <- names(deis_2024_raw)[1]

deis_2024 <- deis_2024_raw |>
  dplyr::transmute(
    year = as.integer(.data[[year_col_2024]]),
    gender = as.character(.data[["SEXO_NOMBRE"]]),
    age_type = as.integer(.data[["EDAD_TIPO"]]),
    age = as.integer(.data[["EDAD_CANT"]]),
    diag1 = as.character(.data[["DIAG1"]]),
    diag2 = as.character(.data[["DIAG2"]])
  ) |>
  dplyr::filter(year == 2024, age_type == 1) |>
  dplyr::select(-age_type)

mortality <- dplyr::bind_rows(deis_2012_2023, deis_2024) |>
  dplyr::filter(year %in% target_years, age >= 15) |>
  dplyr::mutate(
    sex = dplyr::case_when(
      gender == "Mujer" ~ "Female",
      gender == "Hombre" ~ "Male",
      TRUE ~ NA_character_
    ),
    age_group = dplyr::case_when(
      dplyr::between(age, 15, 29) ~ "15-29",
      dplyr::between(age, 30, 44) ~ "30-44",
      dplyr::between(age, 45, 59) ~ "45-59",
      age >= 60 ~ "60+",
      TRUE ~ NA_character_
    ),
    DIAG1_s6 = clean_icd10(diag1)
  ) |>
  dplyr::filter(!is.na(sex), !is.na(age_group))

cancer_code_map <- list(
  "Breast Cancer" = icd_codes_s6("C", 50),
  "Colorectal Cancer" = icd_codes_s6("C", 18:21),
  "Larynx Cancer" = icd_codes_s6("C", 32),
  "Liver Cancer" = icd_codes_s6("C", 22),
  "Oesophagus Cancer" = icd_codes_s6("C", 15),
  # 2026-07-02= I did exclude C11: C00-C10 + C12-C14 
  # Shield / OMS-aligned = C00-C08 + C09-C10 + C12-C14
  "Oral Cavity and Pharynx Cancer" = icd_codes_s6("C", 0:14),
  "Pancreatic Cancer" = icd_codes_s6("C", 25),
  "Stomach Cancer" = icd_codes_s6("C", 16)
)

mortality_counts <- dplyr::bind_rows(lapply(names(cancer_code_map), function(disease_i) {
  mortality |>
    dplyr::filter(DIAG1_s6 %in% cancer_code_map[[disease_i]]) |>
    dplyr::count(
      Year = year,
      disease = disease_i,
      sex,
      age_group,
      name = "muertes"
    )
}))

pipeline_cancer <- ref_keys |>
  dplyr::left_join(
    aaf_long,
    by = c("Year", "disease", "sex", "age_group")
  ) |>
  dplyr::left_join(
    mortality_counts,
    by = c("Year", "disease", "sex", "age_group")
  ) |>
  dplyr::mutate(
    muertes = dplyr::coalesce(muertes, 0L),
    att_mort = round(AAF * muertes),
    att_mort_low = round(LL * muertes),
    att_mort_up = round(UL * muertes)
  ) |>
  dplyr::arrange(disease, Year, sex, age_group) |>
  dplyr::select(
    Year, disease, sex, age_group, AAF, LL, UL, muertes,
    att_mort, att_mort_low, att_mort_up
  )
# 2026-07-02= I did not include the 60+ age group in the original JRT table, 
# but I will include it here for comparison.
pipeline_cancer_60plus <- pipeline_cancer |>
  dplyr::filter(age_group == "60+")

cancer_compare_comparable <- pipeline_cancer_60plus |>
  dplyr::full_join(
    ref_cancer |>
      dplyr::filter(age_group == "60+"),
    by = c("Year", "disease", "sex", "age_group"),
    suffix = c("_pipeline", "_jrt")
  ) |>
  dplyr::mutate(
    diff_AAF = AAF_pipeline - AAF_jrt,
    diff_muertes = muertes_pipeline - muertes_jrt,
    diff_att_mort = att_mort_pipeline - att_mort_jrt
  ) |>
  dplyr::arrange(disease, Year, sex, age_group)

readr::write_tsv(
  pipeline_cancer,
  file.path(out_dir, "pipeline_cancer_aam_jrt_compatible_all_ages.txt")
)
readr::write_tsv(
  pipeline_cancer_60plus,
  file.path(out_dir, "pipeline_cancer_aam_jrt_compatible_60plus.txt")
)
readr::write_csv(
  cancer_compare_comparable,
  file.path(out_dir, "pipeline_vs_jrt_cancer_60plus.csv")
)

if (nrow(pipeline_cancer) != 420L) {
  stop("Unexpected all-age row count: ", nrow(pipeline_cancer))
}
if (nrow(pipeline_cancer_60plus) != 105L) {
  stop("Unexpected 60+ row count: ", nrow(pipeline_cancer_60plus))
}
if (nrow(cancer_compare_comparable) != 105L) {
  stop("Unexpected comparison row count: ", nrow(cancer_compare_comparable))
}

max_abs_diff_muertes <- max(abs(cancer_compare_comparable$diff_muertes), na.rm = TRUE)
message("Wrote: ", file.path(out_dir, "pipeline_vs_jrt_cancer_60plus.csv"))
message("Rows: ", nrow(cancer_compare_comparable))
message("Max abs mortality-count difference: ", max_abs_diff_muertes)
message(sprintf(
  "[%.2f min] Rebuilt JRT-compatible cancer comparison.",
  as.numeric(difftime(Sys.time(), .t0, units = "mins"))
))
