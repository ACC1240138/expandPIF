# Chunks para `expand_pif2.ipynb` — regla de salida del ex‑HED (λ = 0 vs λ = 1)

**No he tocado el notebook.** Esto es material para que lo pegues tú, en **cuatro celdas
independientes** que puedes añadir de a una y verificar entre medio.

| Celda | Qué hace | ¿Re‑corre el motor? |
|---|---|---|
| **A** (markdown) | Explica la regla de salida | no |
| **B** (código) | Extiende la grilla con 6 gemelos λ=1 + cablea el motor + **arregla la lista de descarte** | no |
| **C** (código) | Mata el `volume_reduction_pct = 0` mentiroso: calcula la **caída implícita de consumo por celda** | no |
| **D** (código) | Smoke test sobre **una celda real**: λ=0 vs λ=1 | sí, 1 celda (~seg) |

Ubicación: **B** después de `pif2-pif-engine-wrapper` (`pif2cell12`). **C** y **D** después de B.

> **Coste de cómputo.** Un gemelo λ=1 cuesta **exactamente lo que costó su original λ=0**. Los 6
> gemelos (3 `hed_*` + 3 `combined_*`) añaden el coste de esas 6 filas actuales. Las filas
> `volume` y `baseline` **no se duplican**: sin masa saliendo del binge, λ es un no‑op
> matemático. No hay barrido ni explosión combinatoria — el motor corre las filas que la
> grilla declara, ni una más.

---

## CELDA A — markdown

### Dos reglas de salida para quien abandona el atracón

Hasta ahora, en los escenarios `hed` y `both`, quien dejaba el binge **conservaba su propia
densidad de consumo** `d_hed` y solo cambiaba de curva de riesgo (adoptaba `RR_NHED`). Es
decir: dejar de emborracharse eliminaba el exceso de riesgo específico del atracón **pero no
un solo gramo de alcohol**. Los escenarios HED eran, por construcción, neutrales en volumen.

El motor (`aaf_unified.R`, 2026‑07‑14) parametriza ahora ese supuesto. El riesgo
contrafactual de la masa que sale es

$$R_{\text{exit}} = (1-\lambda)\, R\!\left(d_{hed},\, RR_{NHED}(x\rho)\right) + \lambda\, R_{nhed}$$

y aquí se reportan **dos reglas**, no un espacio de parámetros:

| Regla | λ | Qué supone | Filas |
|---|---|---|---|
| **Conservadora** (la nuestra) | **0** | el ex‑HED deja el atracón pero **sigue bebiendo su mismo volumen**; solo pierde el exceso de RR del binge | `hed_reduction_*`, `combined_*` |
| **Ruiz‑Tagle** (JRT) | **1** | el ex‑HED **pasa a ser un bebedor NHED promedio**: sigue bebiendo, con el riesgo residual de ese volumen | `*_rt` |

`λ = 0, ρ = 1` reproduce **bit a bit** todo lo ya calculado. La perilla `ρ` (volumen retenido
por el ex‑HED) queda en 1 y no se usa: es la puerta abierta para calibrarla más adelante.

Los knobs son escalares **a nivel de celda** (año × sexo × tramo × causa). Hoy se les pasa un
número que se difunde a todas las celdas. El día que la **microsimulación** entregue
transiciones por año/edad/sexo, se reemplaza ese número por una `function(year, group, sex)`
o una lista por año/tramo, y **no cambia nada más**: `resolve_hed_exit()` ya resuelve ambas
formas. No es trabajo pendiente, es un enchufe libre.

> **Advertencia para IHD e ictus isquémico (`hed_mode = "cap"`).** La curva J real del proyecto
> es **protectora en todo el tramo bajo 60 g/día** (nadir RR = 0.78 a ~31 g/día). Ahí λ=1 puede
> **bajar** el PIF en vez de subirlo, y una barrida de ρ no es monótona. Para el resto de las
> causas (RR creciente), λ=0 es la cota conservadora y λ=1 la optimista. Ver
> `test_hed_exit_knobs.R`, sección (H).

---

## CELDA B — código: grilla + cableado + lista de descarte segura

````r
#| label: pif2-hed-exit-wiring
#| results: "hold"

.t0 <- Sys.time()

# ---------------------------------------------------------------------------
# HED-EXIT REASSIGNMENT: two exit rules, wired end to end.
#
#   hed_exit_mix   = lambda in [0,1]  share of the mass leaving binge that migrates to
#                                     the NHED consumption DISTRIBUTION.
#                                     0 = conservative (ours) | 1 = Ruiz-Tagle
#   hed_exit_shift = rho in (0,1]     volume that same mass RETAINS. Held at 1 (unused);
#                                     it is the calibration hook, not a lever we report.
#
# Legacy rows keep lambda = 0, rho = 1, so every number already computed is unchanged.
# ---------------------------------------------------------------------------

stopifnot(exists("pif2_scenario_grid"), exists("pif2_build_pif_args"),
          exists("resolve_hed_exit"))   # resolve_hed_exit() lives in aaf_unified.R

# ---- 1. Existing rows -> the conservative rule, declared EXPLICITLY -----------
# Until today lambda = 0 was hard-coded inside the engine and invisible in the grid.
# It is a MODELLING ASSUMPTION and it belongs in the registry, next to the shifts.
if (!"hed_exit_mix" %in% names(pif2_scenario_grid)) {
  pif2_scenario_grid$hed_exit_mix   <- 0    # ex-HED keeps his own consumption density
  pif2_scenario_grid$hed_exit_shift <- 1    # ...and his full volume
  pif2_scenario_grid$exit_rule      <- "conservative"
}

# ---- 2. The six Ruiz-Tagle twins (lambda = 1) --------------------------------
# One twin per row that actually has mass leaving binge: the 3 pure-HED rows and the 3
# combined rows. `volume` and `baseline` are NOT duplicated: with nobody exiting binge
# lambda is a mathematical no-op, so a twin would be a bit-identical duplicate that
# costs a full run for nothing.
#
# Same policy levers as the row each one mirrors (identical shift_vol / shift_hed) --
# the ONLY thing that changes is where the ex-binge drinker lands.
pif2_hed_exit_twins <- tibble::tribble(
  ~scenario_id,          ~scenario_label,                                   ~scenario_family,     ~engine_scenario, ~volume_reduction_pct, ~hed_reduction_pct, ~shift_vol, ~shift_hed, ~requires_hed, ~hed_exit_mix, ~hed_exit_shift, ~exit_rule,
  "hed_reduction_10_rt", "HED -10% (ex-HED -> NHED, JRT)",                  "HED prevalence",     "hed",            0,                     10,                 1.00,       0.90,       TRUE,          1,             1,               "ruiz_tagle",
  "hed_reduction_25_rt", "HED -25% (ex-HED -> NHED, JRT)",                  "HED prevalence",     "hed",            0,                     25,                 1.00,       0.75,       TRUE,          1,             1,               "ruiz_tagle",
  "hed_reduction_50_rt", "HED -50% (ex-HED -> NHED, JRT)",                  "HED prevalence",     "hed",            0,                     50,                 1.00,       0.50,       TRUE,          1,             1,               "ruiz_tagle",
  "combined_v10_h25_rt", "Combined v-10% / HED -25% (ex-HED -> NHED, JRT)", "Combined",           "both",           10,                    25,                 0.90,       0.75,       TRUE,          1,             1,               "ruiz_tagle",
  "combined_v20_h50_rt", "Combined v-20% / HED -50% (ex-HED -> NHED, JRT)", "Combined",           "both",           20,                    50,                 0.80,       0.50,       TRUE,          1,             1,               "ruiz_tagle",
  "combined_v30_h50_rt", "Combined v-30% / HED -50% (ex-HED -> NHED, JRT)", "Combined",           "both",           30,                    50,                 0.70,       0.50,       TRUE,          1,             1,               "ruiz_tagle"
)
pif2_hed_exit_twins$scale <- "relative"

pif2_scenario_grid <- dplyr::bind_rows(
  pif2_scenario_grid,
  pif2_hed_exit_twins[!pif2_hed_exit_twins$scenario_id %in% pif2_scenario_grid$scenario_id, ]
)

# Every twin must mirror its original EXACTLY except for the exit rule. If a shift ever
# drifts apart, the "lambda moved the PIF by X%" reading becomes a lie. Assert it.
for (.tw in pif2_hed_exit_twins$scenario_id) {
  .orig <- sub("_rt$", "", .tw)
  .a <- pif2_scenario_grid[pif2_scenario_grid$scenario_id == .orig, ]
  .b <- pif2_scenario_grid[pif2_scenario_grid$scenario_id == .tw, ]
  stopifnot(nrow(.a) == 1L, nrow(.b) == 1L,
            identical(.a$engine_scenario, .b$engine_scenario),
            isTRUE(all.equal(.a$shift_vol, .b$shift_vol)),
            isTRUE(all.equal(.a$shift_hed, .b$shift_hed)),
            .a$hed_exit_mix == 0, .b$hed_exit_mix == 1)
}

# ---- 3. THE SAFE DISCARD LIST (whitelist, not blacklist) ---------------------
# Four places in this notebook turn a pif_confint() arg list into an aaf_confint() one by
# BLACKLISTING the PIF-only names:
#     args[setdiff(names(args), c("scenario", "shift", "shift_hed"))]
# That is fragile by construction: aaf_confint() has no `...`, so the day the engine
# grows ANY new PIF-only argument (today: hed_exit_mix / hed_exit_shift), every one of
# those four sites breaks with "unused argument" -- and the blacklist has to be hunted
# down and edited in four places, forever.
#
# Invert it. WHITELIST against what aaf_confint() actually accepts, read from the
# function itself. Then a new PIF-only argument is dropped automatically and no site
# ever needs editing again.
pif2_as_aaf_args <- function(args) {
  keep <- intersect(names(args), names(formals(aaf_confint)))
  dropped <- setdiff(names(args), keep)
  if (length(dropped)) {
    pif2_message("[aaf-args] Dropped %d PIF-only argument(s) before calling aaf_confint(): %s.",
                 length(dropped), paste(dropped, collapse = ", "))
  }
  args[keep]
}

# Self-check: it must drop exactly the PIF-only names and keep everything else.
local({
  .probe <- list(gamma = 1, rr_fun = 1, beta = 1, p_abs = 1, p_form = 1, x = 1,
                 scenario = "hed", shift = 0.9, shift_hed = 0.9,
                 hed_exit_mix = 1, hed_exit_shift = 1)
  .kept <- suppressMessages(names(pif2_as_aaf_args(.probe)))
  stopifnot(!any(c("scenario", "shift", "shift_hed", "hed_exit_mix", "hed_exit_shift") %in% .kept),
            all(c("gamma", "rr_fun", "beta", "p_abs", "p_form", "x") %in% .kept))
})

# ---- 4. Wire the knobs into the engine call ----------------------------------
# Wrap (do NOT edit) pif2_build_pif_args: call the original, then append the knobs.
# Guarded against double-wrapping if this cell is re-run.
if (!exists(".pif2_build_pif_args_base")) {
  .pif2_build_pif_args_base <- pif2_build_pif_args
}
pif2_build_pif_args <- function(spec_row, record, inputs, scenario_row,
                                exposure, unc, mc, year, group, run_cfg) {
  args <- .pif2_build_pif_args_base(spec_row, record, inputs, scenario_row,
                                    exposure, unc, mc, year, group, run_cfg)

  # Only "hed"/"both" have a mass leaving binge. Under "volume" the knobs are a
  # mathematical no-op, so we do not even attach them.
  if (!scenario_row$engine_scenario %in% c("hed", "both")) return(args)

  # A hand-built scenario row (as in the Phase 7 isolation tests) may not carry the new
  # columns -> fall back to the legacy constants rather than erroring.
  lam_spec <- if (is.null(scenario_row$hed_exit_mix))   0 else scenario_row$hed_exit_mix
  rho_spec <- if (is.null(scenario_row$hed_exit_shift)) 1 else scenario_row$hed_exit_shift

  # resolve_hed_exit() turns a SPEC into this cell's scalar. Today the spec is a bare
  # number and this is just a broadcast. The day the microsimulation delivers lambda by
  # year/age/sex, put a function(year, group, sex) -- or a list keyed by year -> age band
  # -- in the grid cell instead, and nothing else in the pipeline changes.
  # It ERRORS on any cell a spec fails to cover: it never silently falls back.
  lam <- resolve_hed_exit(lam_spec, year, group, spec_row$sex)
  rho <- resolve_hed_exit(rho_spec, year, group, spec_row$sex)

  # Legacy values -> attach nothing: the engine reuses the pre-2026-07-14 code path and
  # the result is bit-for-bit identical to what is already published.
  if (isTRUE(lam == 0) && isTRUE(rho == 1)) return(args)

  args$hed_exit_mix   <- lam
  args$hed_exit_shift <- rho
  args
}

pif2_message("[hed-exit] Grid: %d scenarios (%d conservative, %d Ruiz-Tagle). Safe AAF arg whitelist installed.",
             nrow(pif2_scenario_grid),
             sum(pif2_scenario_grid$exit_rule == "conservative"),
             sum(pif2_scenario_grid$exit_rule == "ruiz_tagle"))

message(sprintf("pif2-hed-exit-wiring elapsed minutes: %.2f", pif2_elapsed_min(.t0)))
````

### Y ahora el reemplazo manual en los 4 sitios

La celda B **define** `pif2_as_aaf_args()` pero no puede reemplazar las llamadas: viven en otras
celdas. Busca y reemplaza estas cuatro (líneas ~16470, ~16860, ~17151, ~17409 del JSON):

```r
# ANTES (frágil: hay que editarlo cada vez que el motor gana un argumento)
aaf_args  <- args[setdiff(names(args), c("scenario", "shift", "shift_hed"))]
.aaf_args <- .args_liv[setdiff(names(.args_liv), c("scenario", "shift", "shift_hed"))]
.t5_my_aaf <- do.call(aaf_confint, .t5_args[setdiff(names(.t5_args), c("scenario", "shift", "shift_hed"))])$point_estimate
args <- args[setdiff(names(args), c("scenario", "shift", "shift_hed"))]

# DESPUÉS (a prueba de argumentos futuros)
aaf_args  <- pif2_as_aaf_args(args)
.aaf_args <- pif2_as_aaf_args(.args_liv)
.t5_my_aaf <- do.call(aaf_confint, pif2_as_aaf_args(.t5_args))$point_estimate
args <- pif2_as_aaf_args(args)
```

> **Si no haces este reemplazo, hoy igual funciona** — los 4 sitios construyen sus `args` desde
> una fila `volume`, y la celda B solo adjunta los knobs a filas `hed`/`both`. Pero esa
> seguridad es **incidental**: el día que uno de esos checks apunte a una fila HED, revienta
> con `unused argument`. El reemplazo lo hace imposible **para siempre**, no solo para estos
> dos argumentos.

---

## CELDA C — código: matar el `volume_reduction_pct = 0`

````r
#| label: pif2-hed-exit-implied-volume
#| results: "hold"

.t0 <- Sys.time()

# ---------------------------------------------------------------------------
# WHY volume_reduction_pct = 0 IS A LIE ON THE JRT ROWS, AND WHY THE FIX IS NOT A
# CONSTANT IN THE GRID.
#
# With lambda = 1 the ex-binge drinker moves onto the NHED consumption distribution, so
# he really does drink LESS. The HED scenarios stop being volume-neutral. But the size
# of that drop is NOT a property of the scenario: it depends on p_hed, E[d_hed] and
# E[d_nhed], which change with year, sex and age band. It is a PER-CELL derived
# quantity, not a grid constant -- so it cannot be written into the tribble.
#
# The fix therefore has two parts:
#   (a) volume_reduction_pct KEEPS its meaning and is RELABELLED honestly: it is the
#       POLICY volume lever (what the intervention does to everyone's consumption by
#       decree), not the total change in grams. On a pure HED row that lever is 0, and
#       that is TRUE -- the policy does not cut anyone's volume by decree.
#   (b) a NEW per-cell column reports the change in mean consumption the counterfactual
#       actually IMPLIES, lever plus behavioural reallocation. THAT is the number that
#       must never be quoted as 0.
#
# Mean consumption among CURRENT DRINKERS:
#   baseline   E0   = (1-p_hed)*E_nhed + p_hed*E_hed
#   counterfac E_cf = s_v * [ (1-p_hed)*E_nhed
#                             + s_h*p_hed*E_hed
#                             + (1-s_h)*p_hed*( (1-lambda)*rho*E_hed + lambda*E_nhed ) ]
# with s_v = shift_vol (1 on pure-HED rows) and s_h = shift_hed (1 on volume rows).
# Reported as the percent change (E_cf - E0)/E0, i.e. NEGATIVE = a real drop in grams.
# ---------------------------------------------------------------------------

# NOTE ON THE LOOP BOUNDS. We iterate pif2_run_cfg$years / pif2_run_cfg$groups -- the SAME
# vectors pif2_run_pif_grid() is handed -- so this table covers exactly the cells the engine
# runs, no more and no fewer. (Do not use pif2_years here: it exists, but it is not what the
# grid runner loops over, and a silent mismatch would make the summary describe a different
# population than the PIFs it is meant to annotate.)
stopifnot(exists("pif2_scenario_grid"), exists("pif2_resolve_cell_inputs"),
          exists("pif2_run_cfg"), !is.null(pif2_run_cfg$years), !is.null(pif2_run_cfg$groups))

# Mean of a fitted gamma = shape/rate. .aaf_gamma_pars() normalises the two conventions.
pif2_gamma_mean <- function(g) {
  p <- .aaf_gamma_pars(g)
  if (is.finite(p$rate)) p$shape / p$rate else p$shape * p$scale
}

# Implied change in MEAN CONSUMPTION AMONG CURRENT DRINKERS, for one cell x scenario.
# Returns percent change (negative = drop). NA when the cause has no HED component and
# the scenario needs one (nothing to reallocate, and the row is NA anyway).
pif2_implied_vol_change_pct <- function(inputs, scenario_row) {
  s_v <- if (is.null(scenario_row$shift_vol))     1 else scenario_row$shift_vol
  s_h <- if (is.null(scenario_row$shift_hed))     1 else scenario_row$shift_hed
  lam <- if (is.null(scenario_row$hed_exit_mix))  0 else scenario_row$hed_exit_mix
  rho <- if (is.null(scenario_row$hed_exit_shift)) 1 else scenario_row$hed_exit_shift

  E_nhed <- pif2_gamma_mean(inputs$gamma)
  has_hed <- !is.null(inputs$gamma_hed) && !is.null(inputs$p_hed) &&
             is.finite(inputs$p_hed) && inputs$p_hed > 0

  if (!has_hed) {
    # Volume-only cause: only the policy lever moves grams; nobody exits binge.
    return(100 * (s_v - 1))
  }

  E_hed <- pif2_gamma_mean(inputs$gamma_hed)
  p     <- inputs$p_hed

  E0   <- (1 - p) * E_nhed + p * E_hed
  E_cf <- s_v * ((1 - p) * E_nhed +
                 s_h * p * E_hed +
                 (1 - s_h) * p * ((1 - lam) * rho * E_hed + lam * E_nhed))
  if (!is.finite(E0) || E0 <= 0) return(NA_real_)
  100 * (E_cf / E0 - 1)
}

# ---- Compute it for EVERY (cause x scenario x year x band) --------------------
# Cheap: no Monte Carlo, no integrals -- just gamma means and the prevalences already
# resolved by pif2_resolve_cell_inputs().
pif2_implied_vol <- do.call(rbind, lapply(seq_len(nrow(pif2_output_spec)), function(i) {
  spec_row <- pif2_output_spec[i, ]
  do.call(rbind, lapply(pif2_run_cfg$years, function(year) {
    do.call(rbind, lapply(pif2_run_cfg$groups, function(group) {
      rec <- tryCatch(pif2_lookup_record(spec_row, group), error = function(e) NULL)
      if (is.null(rec)) return(NULL)
      inp <- pif2_resolve_cell_inputs(spec_row, rec, year, group, pif2_exposure_inputs)
      if (!isTRUE(inp$ok)) return(NULL)
      do.call(rbind, lapply(seq_len(nrow(pif2_scenario_grid)), function(j) {
        scn <- pif2_scenario_grid[j, ]
        if (!isTRUE(pif2_scenario_applicability(spec_row, scn)$applicable)) return(NULL)
        data.frame(output_name = spec_row$output_name, sex = spec_row$sex,
                   year = year, age_group = group,
                   scenario_id = scn$scenario_id,
                   exit_rule = if (is.null(scn$exit_rule)) "conservative" else scn$exit_rule,
                   policy_vol_lever_pct = -scn$volume_reduction_pct,   # what the grid DECLARES
                   implied_vol_change_pct = pif2_implied_vol_change_pct(inp, scn),
                   stringsAsFactors = FALSE)
      }))
    }))
  }))
}))

# ---- The headline: what the grid CLAIMS vs what the counterfactual IMPLIES -----
pif2_implied_vol_summary <- pif2_implied_vol |>
  dplyr::group_by(scenario_id, exit_rule) |>
  dplyr::summarise(
    policy_lever_pct   = unique(policy_vol_lever_pct),
    implied_mean_pct   = mean(implied_vol_change_pct, na.rm = TRUE),
    implied_min_pct    = min(implied_vol_change_pct,  na.rm = TRUE),
    implied_max_pct    = max(implied_vol_change_pct,  na.rm = TRUE),
    .groups = "drop") |>
  dplyr::arrange(scenario_id)

print(as.data.frame(pif2_implied_vol_summary))

# The whole point of this cell, stated out loud:
.liars <- pif2_implied_vol_summary[
  pif2_implied_vol_summary$policy_lever_pct == 0 &
  abs(pif2_implied_vol_summary$implied_mean_pct) > 0.01, ]
if (nrow(.liars)) {
  pif2_message(paste0("[implied-vol] %d scenario(s) declare a POLICY volume lever of 0%% but IMPLY a real ",
                      "change in mean consumption: %s. Report `implied_vol_change_pct`, NOT ",
                      "`volume_reduction_pct`, whenever you describe what the policy does to grams."),
               nrow(.liars),
               paste(sprintf("%s (%.2f%%)", .liars$scenario_id, .liars$implied_mean_pct), collapse = "; "))
}

# Sanity: the conservative rows (lambda = 0, rho = 1) must imply EXACTLY the policy lever
# -- no reallocation, no hidden grams. If this ever fails, the wiring is wrong.
.cons <- pif2_implied_vol_summary[pif2_implied_vol_summary$exit_rule == "conservative", ]
stopifnot(all(abs(.cons$implied_mean_pct - .cons$policy_lever_pct) < 1e-8))
pif2_message("[implied-vol] Check passed: every conservative row implies exactly its policy lever (lambda=0 moves no grams).")

message(sprintf("pif2-hed-exit-implied-volume elapsed minutes: %.2f", pif2_elapsed_min(.t0)))
````

**Cómo usar la salida.** En cualquier tabla que publiques, la columna de "reducción de
consumo" debe ser `implied_vol_change_pct` (o ambas, lado a lado, que es más honesto: *"la
política decreta −0%, el contrafactual implica −X%"*). El `volume_reduction_pct` de la grilla
se queda, pero como lo que siempre fue: **la palanca de política**, no el resultado.

---

## CELDA D — código: smoke test sobre una celda real

````r
#| label: pif2-hed-exit-smoke
#| results: "hold"

.t0 <- Sys.time()

# One real cell, run twice through the SAME arg builder, changing ONLY the exit rule.
# Liver cancer, male, 2022, band 2 (30-44): a HED-capable, monotonically-increasing-RR
# cause, where the direction of the effect is well defined (unlike IHD/IS).
.he_spec <- pif2_output_spec[pif2_output_spec$output_name == "lican_male", ]
.he_rec  <- pif2_lookup_record(.he_spec, 2L)
.he_in   <- pif2_resolve_cell_inputs(.he_spec, .he_rec, 2022L, 2L, pif2_exposure_inputs)
stopifnot(isTRUE(.he_in$ok))
.he_cfg  <- list(n_sim = 400L, n_pca = 400L, n_cores = 1L,
                 inner_parallel = FALSE, outer_parallel = FALSE)

.he_run <- function(scenario_id) {
  row  <- pif2_scenario_grid[pif2_scenario_grid$scenario_id == scenario_id, ]
  args <- pif2_build_pif_args(.he_spec, .he_rec, .he_in, row, pif2_exposure_inputs,
                              pif2_aaf_uncertainty, pif2_aaf_mc, 2022L, 2L, .he_cfg)
  res  <- do.call(pif_confint, args)
  data.frame(
    scenario = scenario_id,
    exit_rule = if (is.null(row$exit_rule)) "conservative" else row$exit_rule,
    lambda = if (is.null(args$hed_exit_mix)) 0 else args$hed_exit_mix,
    pif = res$point_estimate, lower = res$lower_ci, upper = res$upper_ci,
    implied_vol_pct = pif2_implied_vol_change_pct(.he_in, row),
    stringsAsFactors = FALSE)
}

.he_cmp <- do.call(rbind, lapply(
  c("hed_reduction_50", "hed_reduction_50_rt",
    "combined_v20_h50", "combined_v20_h50_rt"), .he_run))
print(.he_cmp)

pif2_message("[hed-exit] lican_male 2022 / 30-44, HED -50%%: conservative PIF = %.4f -> Ruiz-Tagle PIF = %.4f (%+.1f%%). Implied mean-consumption change: %.2f%% vs %.2f%%.",
             .he_cmp$pif[1], .he_cmp$pif[2],
             100 * (.he_cmp$pif[2] / .he_cmp$pif[1] - 1),
             .he_cmp$implied_vol_pct[1], .he_cmp$implied_vol_pct[2])

# Guard: on a monotone-RR cause, JRT must not come out BELOW the conservative rule. If it
# does, the wiring is inverted. (This guard is deliberately NOT applied to IHD/IS, where a
# lower PIF under lambda=1 is a real property of the cardioprotective J-curve.)
stopifnot(.he_cmp$pif[2] >= .he_cmp$pif[1])
pif2_message("[hed-exit] Direction check passed on a monotone-RR cause (JRT >= conservative).")

message(sprintf("pif2-hed-exit-smoke elapsed minutes: %.2f", pif2_elapsed_min(.t0)))
````

---

## Lo que estas celdas NO hacen

- **No re‑corren la grilla completa.** Solo prueban una celda. La corrida grande (~314 min + los
  6 gemelos) la lanzas tú cuando quieras.
- **No tocan el YPLL.** Es su propio paso: el `YPLL.rds` existente cubre **3 causas de lesiones**,
  años pares 2008–2022 y tramo 4 = **60+** — no sirve para una grilla de 23 causas, 2012–2024,
  tramo 4 = 60–65. Hay que **reconstruirlo** desde los microdatos de defunciones, y eso exige
  decidir la convención de esperanza de vida (en el repo hay tres distintas dando vueltas).
- **No usan ρ.** Queda en 1. Es el enchufe de calibración, no una palanca reportada.
