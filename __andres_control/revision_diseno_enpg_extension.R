###############################################################################
# revision_diseno_enpg_extension.R
# Extension of revision_diseno_enpg.R that estimates the additional clustering
# factor for the PIF-relevant alcohol variables:
#   - hed          : heavy episodic drinking (0/1)
#   - cvolajms     : consumption category (factor, CHMS sensitivity)
#   - volajohdiams : average daily grams of alcohol (CHMS sensitivity, continuous)
#
# Logic:
#   This script merges the processed ENPG_BINGE.RDS back to a minimal embedded
#   design lookup for the 2022 and 2024 waves, which are the only waves with
#   UPM/REGION. The lookup keeps only id, REGION, UPM, and FACTOR_EXPANSION, so
#   the full raw ENPG 2024 .dta is not required for this extension.
#
# Usage:
#   source(file.path(gsub("__andres_control", "", getwd()),
#                    "__andres_control", "revision_diseno_enpg_extension.R"))
#
# Andres GSC -- 2026-06-26
###############################################################################

suppressPackageStartupMessages({
  library(survey)
  library(dplyr)
  library(haven)
})
options(survey.lonely.psu = "adjust")

# ----- paths -----------------------------------------------------------------
base_dir <- file.path(gsub("__andres_control", "", getwd()))
control_dir <- file.path(base_dir, "__andres_control")
binge_path <- file.path(base_dir,
                        "ACC1240138-Potentially-Avoidable-Injury-Mortality-in-Chile--bc6359e",
                        "ENPG_BINGE.RDS")
design_lookup_path <- file.path(control_dir, "enpg_design_lookup_2022_2024_minimal.rds")

# ----- base design helpers ---------------------------------------------------
factor_diseno <- function(data, yvar, wvar, psu, strata) {
  ok <- stats::complete.cases(data[, c(yvar, wvar, psu, strata)])
  data <- data[ok, ]
  w <- as.numeric(data[[wvar]])
  neff <- sum(w)^2 / sum(w^2)
  des <- survey::svydesign(ids = stats::reformulate(psu),
                           strata = stats::reformulate(strata),
                           weights = stats::reformulate(wvar),
                           data = data,
                           nest = TRUE)
  m <- survey::svymean(stats::reformulate(yvar), des)
  p <- as.numeric(stats::coef(m))
  se_d <- as.numeric(survey::SE(m))
  se_k <- sqrt(p * (1 - p) / neff)
  data.frame(var = yvar, p = round(p, 4), n = nrow(data),
             neff_kish = round(neff), deff_pesos = round(nrow(data) / neff, 2),
             se_diseno = round(se_d, 5), se_kish = round(se_k, 5),
             factor_adicional = round((se_d / se_k)^2, 3))
}

diag_upm <- function(data, psu) {
  sz <- as.numeric(table(data[[psu]]))
  cat(sprintf("   n=%d | PSU=%d | persons/PSU: med=%.1f mean=%.2f max=%d\n",
              nrow(data), length(unique(data[[psu]])), median(sz), mean(sz), max(sz)))
}

# ----- helper: weighted variance for Kish SE of a mean -----------------------
wtd_var <- function(x, w) {
  xbar <- sum(w * x, na.rm = TRUE) / sum(w, na.rm = TRUE)
  sum(w * (x - xbar)^2, na.rm = TRUE) / sum(w, na.rm = TRUE) *
    (sum(w, na.rm = TRUE) / (sum(w, na.rm = TRUE) - 1))
}

# ----- helper: additional design factor for the mean of a continuous var -----
factor_diseno_mean <- function(data, yvar, wvar, psu, strata) {
  ok   <- stats::complete.cases(data[, c(yvar, wvar, psu, strata)])
  data <- data[ok, ]
  w    <- as.numeric(data[[wvar]])
  y    <- as.numeric(data[[yvar]])
  neff <- sum(w)^2 / sum(w^2)
  des  <- svydesign(ids = reformulate(psu), strata = reformulate(strata),
                    weights = reformulate(wvar), data = data, nest = TRUE)
  m    <- svymean(reformulate(yvar), des)
  mu   <- as.numeric(coef(m)); se_d <- as.numeric(SE(m))
  se_k <- sqrt(wtd_var(y, w) / neff)
  data.frame(var = paste0(yvar, " (mean)"), p = round(mu, 4), n = nrow(data),
             neff_kish = round(neff), deff_pesos = round(nrow(data) / neff, 2),
             se_diseno = round(se_d, 5), se_kish = round(se_k, 5),
             factor_adicional = round((se_d / se_k)^2, 3))
}

# ----- helper: additional design factor for each level of a factor -----------
factor_diseno_cat <- function(data, yvar, wvar, psu, strata) {
  ok   <- stats::complete.cases(data[, c(yvar, wvar, psu, strata)])
  data <- data[ok, ]
  data[[yvar]] <- as.factor(data[[yvar]])
  w    <- as.numeric(data[[wvar]])
  neff <- sum(w)^2 / sum(w^2)
  des  <- svydesign(ids = reformulate(psu), strata = reformulate(strata),
                    weights = reformulate(wvar), data = data, nest = TRUE)
  props <- svymean(reformulate(yvar), des)
  p     <- as.numeric(coef(props))
  se_d  <- as.numeric(SE(props))
  se_k  <- sqrt(p * (1 - p) / neff)
  lvl_lbl <- gsub(paste0(yvar), "", names(coef(props)))
  out   <- data.frame(var = paste0(yvar, " (modal: ", lvl_lbl, ")"),
                      p = round(p, 4), n = nrow(data),
                      neff_kish = round(neff), deff_pesos = round(nrow(data) / neff, 2),
                      se_diseno = round(se_d, 5), se_kish = round(se_k, 5),
                      factor_adicional = round((se_d / se_k)^2, 3),
                      stringsAsFactors = FALSE)
  # return only the modal category as a single summary row
  out <- out[which.max(out$p), ]
  rownames(out) <- NULL
  out
}

# ----- load processed binge data ---------------------------------------------
enpg_binge <- readRDS(binge_path)

if (!file.exists(design_lookup_path)) {
  stop("Missing minimal ENPG design lookup: ", design_lookup_path,
       "\nRebuild it from the raw 2022/2024 ENPG files before running this script.")
}
design_lookup <- readRDS(design_lookup_path)
expected_lookup <- c("enpg2022", "enpg2024")
if (!identical(names(design_lookup), expected_lookup)) {
  stop("Unexpected design lookup names. Expected: ", paste(expected_lookup, collapse = ", "))
}
required_design_cols <- c("id", "REGION", "UPM", "FACTOR_EXPANSION")
missing_design_cols <- lapply(design_lookup, function(x) setdiff(required_design_cols, names(x)))
if (any(lengths(missing_design_cols) > 0)) {
  stop("Minimal design lookup is missing columns: ",
       paste(unlist(missing_design_cols), collapse = ", "))
}

# ----- per-year CHMS totals needed for the conversion factor -----------------
total_volCHMS <- enpg_binge %>%
  dplyr::filter(edad >= 15) %>%
  dplyr::mutate(
    db = ifelse(db >= 88, NA, db),
    oh3 = as.numeric(haven::zap_labels(oh3)),
    oh3 = ifelse(oh3 %in% c(88, 99), NA_real_, oh3),
    oh3 = case_when(
      oh1 == "No" | oh2 == ">30" | oh2 == ">1 año" ~ 0,
      TRUE ~ oh3
    ),
    prom_tragos = case_when(
      oh1 == "No" | oh2 == ">30" | oh2 == ">1 año" ~ 0,
      audit2 == "0-2" ~ 1,
      audit2 == "3-4" ~ 3.5,
      audit2 == "5-6" ~ 5.5,
      audit2 == "7-8" ~ 7.5,
      audit2 == "9 o mas" ~ 9
    ),
    diasalchab = pmax(oh3 - db, 0),
    volalchab = diasalchab * prom_tragos,
    volbinge = ifelse(sexo == "Hombre", db * 5, db * 4),
    voltotMS = (volbinge + volalchab) * 15.7,
    voltotMINSAL = voltotMS / 30,
    volCHMS = voltotMINSAL * 365
  ) %>%
  dplyr::filter(!is.na(volCHMS), oh3 <= 30) %>%
  dplyr::group_by(year) %>%
  dplyr::summarise(
    pop = sum(exp),
    pc_totalvolCHMS = sum(volCHMS * exp) / pop,
    .groups = "drop"
  )

# conversion factor sent by ACC (same as expand_pif.ipynb)
conversion <- function(x, vol) {
  vol_oms <- x * 0.8
  oms <- round((vol_oms * 0.789) * 1000, 2)
  oms / vol
}

# ----- common derivation of hed/cvolajms/volajohdiams ------------------------
deriv_vars <- function(df, yr) {
  pc_ms <- total_volCHMS$pc_totalvolCHMS[total_volCHMS$year == yr]
  df %>%
    dplyr::mutate(
      db = ifelse(db >= 88, NA, db),
      oh3 = as.numeric(haven::zap_labels(oh3)),
      oh3 = ifelse(oh3 %in% c(88, 99), NA_real_, oh3),
      oh3 = case_when(
        oh1 == "No" | oh2 == ">30" | oh2 == ">1 año" ~ 0,
        TRUE ~ oh3
      ),
      prom_tragos = case_when(
        oh1 == "No" | oh2 == ">30" | oh2 == ">1 año" ~ 0,
        audit2 == "0-2" ~ 1,
        audit2 == "3-4" ~ 3.5,
        audit2 == "5-6" ~ 5.5,
        audit2 == "7-8" ~ 7.5,
        audit2 == "9 o mas" ~ 9
      ),
      diasalchab = pmax(oh3 - db, 0),
      volalchab = diasalchab * prom_tragos,
      volbinge = ifelse(sexo == "Hombre", db * 5, db * 4),
      voltotMS = (volbinge + volalchab) * 15.7,
      voltotMINSAL = voltotMS / 30,
      volCHMS = voltotMINSAL * 365,
      volajms = volCHMS * conversion(7.9, pc_ms),
      volajohdiams = volajms / 365,
      cvolajms = case_when(
        oh1 == "No" ~ "ltabs",
        oh2 == ">30" | oh2 == ">1 año" ~ "fd",
        sexo == "Mujer" & volajohdiams > 0 & volajohdiams <= 19.99 ~ "cat1",
        sexo == "Mujer" & volajohdiams >= 20 & volajohdiams <= 39.99 ~ "cat2",
        sexo == "Mujer" & volajohdiams >= 40 & volajohdiams <= 100 ~ "cat3",
        sexo == "Mujer" & volajohdiams > 100 ~ "cat4",
        sexo == "Hombre" & volajohdiams > 0 & volajohdiams <= 39.99 ~ "cat1",
        sexo == "Hombre" & volajohdiams >= 40 & volajohdiams <= 59.99 ~ "cat2",
        sexo == "Hombre" & volajohdiams >= 60 & volajohdiams <= 100 ~ "cat3",
        sexo == "Hombre" & volajohdiams > 100 ~ "cat4",
        TRUE ~ NA_character_
      ),
      hed = as.integer(db > 0)
    ) %>%
    dplyr::filter(oh3 <= 30)
}

# ----- 2022 ------------------------------------------------------------------
d22_ext <- enpg_binge %>%
  dplyr::filter(year == 2022, edad >= 15) %>%
  dplyr::select(id, year, sexo, edad, exp, oh1, oh2, oh3, db, audit2) %>%
  dplyr::mutate(id = as.character(id)) %>%
  dplyr::inner_join(
    design_lookup$enpg2022 %>% dplyr::mutate(id = as.character(id)),
    by = "id"
  ) %>%
  deriv_vars(yr = 2022)

cat("\n== ENPG 2022: hed / cvolajms / volajohdiams ==\n")
diag_upm(d22_ext, "UPM")
res22 <- rbind(
  factor_diseno(d22_ext, "hed", "FACTOR_EXPANSION", "UPM", "REGION"),
  factor_diseno_cat(d22_ext, "cvolajms", "FACTOR_EXPANSION", "UPM", "REGION"),
  factor_diseno_mean(d22_ext, "volajohdiams", "FACTOR_EXPANSION", "UPM", "REGION")
)
rownames(res22) <- NULL
print(res22)

# ----- 2024 ------------------------------------------------------------------
d24_ext <- enpg_binge %>%
  dplyr::filter(year == 2024, edad >= 15) %>%
  dplyr::select(id, year, sexo, edad, exp, oh1, oh2, oh3, db, audit2) %>%
  dplyr::mutate(id = as.numeric(as.character(id))) %>%
  dplyr::inner_join(
    design_lookup$enpg2024 %>% dplyr::mutate(id = as.numeric(id)),
    by = "id"
  ) %>%
  deriv_vars(yr = 2024)

cat("\n== ENPG 2024: hed / cvolajms / volajohdiams ==\n")
diag_upm(d24_ext, "UPM")
res24 <- rbind(
  factor_diseno(d24_ext, "hed", "FACTOR_EXPANSION", "UPM", "REGION"),
  factor_diseno_cat(d24_ext, "cvolajms", "FACTOR_EXPANSION", "UPM", "REGION"),
  factor_diseno_mean(d24_ext, "volajohdiams", "FACTOR_EXPANSION", "UPM", "REGION")
)
rownames(res24) <- NULL
print(res24)

# ----- summary ---------------------------------------------------------------
all_factors <- rbind(res22, res24)
rownames(all_factors) <- NULL
cat("\n>>> Additional clustering factors by variable/year:\n")
print(all_factors)

factor_hardcode_ext <- mean(all_factors$factor_adicional)
cat(sprintf("\n>>> ADDITIONAL FACTOR averaged across hed/cvolajms/volajohdiams: %.2f\n",
            factor_hardcode_ext))
cat("    Previous cur_mes factor is not recomputed here because the minimal\n")
cat("    design lookup intentionally omits raw OH_1/OH_4 survey variables.\n")
cat("    Suggested usage: neff_corr <- neff_kish / factor_hardcode_ext\n")

# =============================================================================
# PER-CELL DESIGN TABLE (request 2026-06-30)
# -----------------------------------------------------------------------------
# Decomposition (chosen granularity: PSU factor PER VARIABLE only):
#   neff_kish          : per (year x age_group x sex) -- the cell precision from
#                        the survey weights, computed for EVERY wave.
#   additional_factor  : per VARIABLE (abs/form/hed/consumption), the PSU
#                        clustering inflation, estimated from 2022+2024 (only
#                        waves with UPM/REGION) and averaged -> a single stable
#                        number per question, applied to all years.
#   neff_corr          : neff_kish / additional_factor  -- exactly what the
#                        aaf_unified engine consumes (neff_eff).
# Pass it to compute_*_aaf_from_registry() via design_table_to_engine_lists().
# =============================================================================

# --- (A) per-variable PSU factor (pooled 2022 + 2024) ------------------------
# abs / former drinker come from the cvolajms levels; hed dummy and the
# consumption mean (volajohdiams) are already derived in deriv_vars().
add_status_dummies <- function(df) {
  df$abs  <- as.integer(df$cvolajms == "ltabs")
  df$form <- as.integer(df$cvolajms == "fd")
  df
}
d22f <- add_status_dummies(d22_ext)
d24f <- add_status_dummies(d24_ext)

factor_one <- function(df, var, kind) {
  if (identical(kind, "mean")) factor_diseno_mean(df, var, "FACTOR_EXPANSION", "UPM", "REGION")
  else                         factor_diseno(df, var, "FACTOR_EXPANSION", "UPM", "REGION")
}
var_spec <- list(abs = c("abs", "bin"), form = c("form", "bin"),
                 hed = c("hed", "bin"), consumption = c("volajohdiams", "mean"))
additional_factor <- vapply(names(var_spec), function(v) {
  f22 <- factor_one(d22f, var_spec[[v]][1], var_spec[[v]][2])$factor_adicional
  f24 <- factor_one(d24f, var_spec[[v]][1], var_spec[[v]][2])$factor_adicional
  round(mean(c(f22, f24)), 3)
}, numeric(1))
cat("\n>>> additional_factor (PSU clustering) per variable, pooled 2022+2024:\n")
print(additional_factor)

# --- (B) neff_kish per (year x age_group x sex), all waves -------------------
# Pipeline 15-64 age groups: 1=15-29, 2=30-44, 3=45-59, 4=60-64.
neff_cells <- enpg_binge %>%
  dplyr::mutate(edad = as.numeric(edad), w = as.numeric(exp)) %>%
  dplyr::filter(edad >= 15, edad < 65, is.finite(w), w > 0) %>%
  dplyr::mutate(
    age_group = as.integer(as.character(cut(edad, breaks = c(15, 30, 45, 60, 65),
                                            right = FALSE, labels = 1:4))),
    sex = dplyr::case_when(sexo == "Hombre" ~ "male", sexo == "Mujer" ~ "female", TRUE ~ NA_character_)
  ) %>%
  dplyr::filter(!is.na(age_group), !is.na(sex)) %>%
  dplyr::group_by(year, age_group, sex) %>%
  dplyr::summarise(n = dplyr::n(), neff_kish = round(sum(w)^2 / sum(w^2)), .groups = "drop") %>%
  as.data.frame()

# --- (C) tidy table: one row per (year x age_group x sex x variable) ---------
design_table_cells <- do.call(rbind, lapply(names(additional_factor), function(v) {
  d <- neff_cells
  d$variable <- v
  d$additional_factor <- additional_factor[[v]]
  d$neff_corr <- round(d$neff_kish / d$additional_factor)
  d
}))
design_table_cells <- design_table_cells[
  order(design_table_cells$variable, design_table_cells$year,
        design_table_cells$sex, design_table_cells$age_group),
  c("year", "age_group", "sex", "variable", "n", "neff_kish", "additional_factor", "neff_corr")]
rownames(design_table_cells) <- NULL
cat("\n>>> design_table_cells (head) -- kable this in the notebook:\n")
print(utils::head(design_table_cells, 12))
cat(sprintf("    %d rows = %d years x 4 age-groups x 2 sexes x %d variables\n",
            nrow(design_table_cells), length(unique(neff_cells$year)), length(additional_factor)))

# --- (D) converter to aaf_unified engine inputs ------------------------------
# neff(year,group,sex)  -> neff_kish for that cell (variable-independent precision)
# design_factor         -> list(abs, form, hed)  PSU factors per prevalence question
# neff_consumption(...) -> neff_kish for that cell ; design_factor_consumption scalar
# Pass these straight into compute_*_aaf_from_registry().
design_table_to_engine_lists <- function(tbl = design_table_cells, neff_default = 1000) {
  cells <- unique(tbl[, c("year", "age_group", "sex", "neff_kish")])
  kish  <- stats::setNames(cells$neff_kish, paste(cells$year, cells$age_group, cells$sex, sep = "|"))
  af    <- tapply(tbl$additional_factor, tbl$variable, function(z) z[1])
  neff_fun <- function(year, group, sex) {
    v <- kish[[paste(year, group, sex, sep = "|")]]
    if (is.null(v) || !is.finite(v)) neff_default else as.numeric(v)
  }
  list(
    neff = neff_fun,
    design_factor = list(abs = as.numeric(af[["abs"]]), form = as.numeric(af[["form"]]),
                         hed = as.numeric(af[["hed"]])),
    neff_consumption = neff_fun,
    design_factor_consumption = as.numeric(af[["consumption"]])
  )
}

cat("\n>>> Ready. In expand_pif.ipynb:\n")
cat("    knitr::kable(design_table_cells, 'markdown',\n")
cat("      caption = 'Kish plus PSU correction per variable for each year, age group and sex')\n")
cat("    kish <- design_table_to_engine_lists()\n")
cat("    compute_cv_aaf_from_registry(load_adam_rr_registry('ihd'), ...,\n")
cat("        neff = kish$neff, design_factor = kish$design_factor,\n")
cat("        neff_consumption = kish$neff_consumption,\n")
cat("        design_factor_consumption = kish$design_factor_consumption)\n")
