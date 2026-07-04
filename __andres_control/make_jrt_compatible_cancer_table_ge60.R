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
  "aaf_nested_by_disease_20260703.rds"
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

extract_aaf_unified_table <- function(cancer_tables, table_name, disease_i, sex_i) {
  tbl <- cancer_tables[[table_name]]
  if (is.null(tbl)) {
    stop("Missing aaf_unified cancer table: ", table_name)
  }
  prefix <- if (sex_i == "Female") "Fem" else "Male"
  age_group_map <- c("1" = "15-29", "2" = "30-44", "3" = "45-59", "4" = "60+")
  dplyr::bind_rows(lapply(names(age_group_map), function(group_i) {
    tbl |>
      dplyr::transmute(
        Year = as.integer(Year),
        disease = disease_i,
        sex = sex_i,
        age_group = unname(age_group_map[[group_i]]),
        AAF = .data[[paste0(prefix, group_i, "_point")]],
        LL = .data[[paste0(prefix, group_i, "_lower")]],
        UL = .data[[paste0(prefix, group_i, "_upper")]]
      )
  }))
}

ref_cancer <- readr::read_tsv(
  path_jrt,
  locale = readr::locale(decimal_mark = ","),
  show_col_types = FALSE
)

ref_keys <- ref_cancer |>
  dplyr::distinct(Year, disease, sex, age_group)

target_years <- sort(unique(ref_cancer$Year))

aaf_unified <- readRDS(path_aaf)
cancer_tables <- aaf_unified[["family_bundles"]][["cancer"]][["raw_result"]][["tables"]]
if (is.null(cancer_tables)) {
  stop("Could not find cancer aaf_unified tables in: ", path_aaf)
}

aaf_table_map <- data.frame(
  table_name = c(
    "bcan_female",
    "crcan_female", "crcan_male",
    "lxcan_female", "lxcan_male",
    "lican_female", "lican_male",
    "oescan_female", "oescan_male",
    "locan_female", "locan_male",
    "panccan_female", "panccan_male",
    "stomcan_female", "stomcan_male"
  ),
  disease = c(
    "Breast Cancer",
    "Colorectal Cancer", "Colorectal Cancer",
    "Larynx Cancer", "Larynx Cancer",
    "Liver Cancer", "Liver Cancer",
    "Oesophagus Cancer", "Oesophagus Cancer",
    "Oral Cavity and Pharynx Cancer", "Oral Cavity and Pharynx Cancer",
    "Pancreatic Cancer", "Pancreatic Cancer",
    "Stomach Cancer", "Stomach Cancer"
  ),
  sex = c(
    "Female",
    "Female", "Male",
    "Female", "Male",
    "Female", "Male",
    "Female", "Male",
    "Female", "Male",
    "Female", "Male",
    "Female", "Male"
  ),
  stringsAsFactors = FALSE
)

aaf_long <- dplyr::bind_rows(lapply(seq_len(nrow(aaf_table_map)), function(i) {
  extract_aaf_unified_table(
    cancer_tables = cancer_tables,
    table_name = aaf_table_map$table_name[[i]],
    disease_i = aaf_table_map$disease[[i]],
    sex_i = aaf_table_map$sex[[i]]
  )
})) |>
  dplyr::filter(Year %in% target_years)

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
  # 2026-07-04= This JRT comparison intentionally includes C11 through C00-C14.
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
if (anyNA(pipeline_cancer[c("AAF", "LL", "UL")])) {
  missing_aaf <- pipeline_cancer |>
    dplyr::filter(is.na(AAF) | is.na(LL) | is.na(UL)) |>
    dplyr::select(Year, disease, sex, age_group)
  stop("Missing aaf_unified values after join: ", utils::capture.output(print(missing_aaf)))
}
# 2026-07-02= I did not include the 60+ age group in the original JRT table, 
# but I will include it here for comparison.
pipeline_cancer_60plus <- pipeline_cancer |>
  dplyr::filter(age_group == "60+")

cancer_compare_comparable <- pipeline_cancer |>
  dplyr::full_join(
    ref_cancer,
    by = c("Year", "disease", "sex", "age_group"),
    suffix = c("_pipeline", "_jrt")
  ) |>
  dplyr::mutate(
    diff_AAF = AAF_pipeline - AAF_jrt,
    diff_muertes = muertes_pipeline - muertes_jrt,
    diff_att_mort = att_mort_pipeline - att_mort_jrt
  ) |>
  dplyr::arrange(disease, Year, sex, age_group)

cancer_compare_60plus <- cancer_compare_comparable |>
  dplyr::filter(age_group == "60+")

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
  file.path(out_dir, "pipeline_vs_jrt_cancer_all_ages.csv")
)
readr::write_csv(
  cancer_compare_60plus,
  file.path(out_dir, "pipeline_vs_jrt_cancer_60plus.csv")
)

if (nrow(pipeline_cancer) != 420L) {
  stop("Unexpected all-age row count: ", nrow(pipeline_cancer))
}
if (nrow(pipeline_cancer_60plus) != 105L) {
  stop("Unexpected 60+ row count: ", nrow(pipeline_cancer_60plus))
}
if (nrow(cancer_compare_comparable) != 420L) {
  stop("Unexpected comparison row count: ", nrow(cancer_compare_comparable))
}
if (nrow(cancer_compare_60plus) != 105L) {
  stop("Unexpected 60+ comparison row count: ", nrow(cancer_compare_60plus))
}

max_abs_diff_muertes <- max(abs(cancer_compare_comparable$diff_muertes), na.rm = TRUE)
message("Wrote: ", file.path(out_dir, "pipeline_vs_jrt_cancer_all_ages.csv"))
message("Wrote: ", file.path(out_dir, "pipeline_vs_jrt_cancer_60plus.csv"))
message("Rows: ", nrow(cancer_compare_comparable))
message("Max abs mortality-count difference: ", max_abs_diff_muertes)
message(sprintf(
  "[%.2f min] Rebuilt JRT-compatible cancer comparison.",
  as.numeric(difftime(Sys.time(), .t0, units = "mins"))
))
