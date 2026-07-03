# Nota — Causas 100% atribuibles (`aaf1`) faltantes en el total vs Shield 2025

**Fecha:** 2026-06-25
**Para:** notebook (`expand_pif.ipynb` / `revision_datos.ipynb`) y documentación / tesis.
**Hallazgo:** el bloque `aaf1` (causas 100% atribuibles, incluida la cardiomiopatía alcohólica I42.6) se **calcula pero nunca se suma** al total. Shield **sí** las incluye. Hay que sumarlas.

---

## 1. Qué hace Shield (verificado en su material suplementario)

- **Causa 860 — "Alcohol use disorders": `F10, G72.1, Q86.0, X45` → "100% alcohol attributable".** Entran al total al 100%.
- **Causa 1150 — "Cardiomyopathy, myocarditis, endocarditis": `I30–33, I38, I40, I42` → "Regression based estimates".** La cardiomiopatía **está** en la carga de Shield.
- Sección *"Estimation of alcoholic cardiomyopathy mortality and morbidity"*: la **cardiomiopatía alcohólica (I42.6)** se aísla del *envelope* I30–I42 y se estima por regresión (método de Manthey: consumo per cápita + prevalencia de trastornos por alcohol). Aparece en las tablas de resultados de Shield.

→ Shield NO omite ninguna; el bloque 100% (trastornos por alcohol, intoxicaciones, cardiomiopatía alcohólica, etc.) es parte estándar del total en cualquier evaluación de riesgo comparativo (Rehm/Shield/WHO).

## 2. Qué hace nuestro pipeline (heredado de JRT)

`aaf1 = rowSums(...)` con `F10 (des_men), G31.2 (deg_nerv), G62.1 (polineu), G72.1 (myopathy_oh), Q86.0 (fetal_oh), I42.6 (cardiomio), K86.0 (pancreati_oh), K29.2 (gastrit), X45 (enven_acc), X65 (enven_int), Y15 (enven_indet)` — **se computa y nunca se vuelve a usar**. El total (`mortality_results`) se arma solo con las 23 causas parciales de `disease_filters`. Mismo patrón en `Paper mortality trends.R` (JRT, paper publicado: `aaf1` aparece una sola vez, línea 3184, y no se suma).

→ Resultado: el total subestima la carga justo en las muertes donde el rol del alcohol es 100% seguro. La cardiomiopatía alcohólica (I42.6) contribuye **cero** (ni se modela el resto de I30–I42, ni se suma el I42.6 que sí capturamos).

**Aclaración (corrige una imprecisión previa):** mantener `cardiomio = I426` al 100% **está alineado con Shield**, que también aísla la cardiomiopatía alcohólica. La diferencia es el método de conteo: Shield la imputa por regresión (Manthey); nosotros usamos el I42.6 codificado directo del DEIS (legítimo, incluso preferible si Chile lo codifica bien). El único error es no sumarla.

---

## 3. Fix (cell lista para pegar)

```r
# Causas 100% atribuibles (AAF=1): se cuentan y se suman al total.
# Shield 2025 (Suppl., causa 860 "100% alcohol attributable"; cardiomiopatía alcohólica I42.6 vía regresión).
# aaf1 ya es disjunto de las causas parciales (K860 fuera de panc, X45 fuera de poisonings) -> sin doble conteo.
fully_attr <- def |>
  dplyr::filter(aaf1 >= 1) |>
  dplyr::group_by(year, age_group, gender) |>
  dplyr::summarise(n = dplyr::n(), .groups = "drop") |>
  dplyr::mutate(disease = "Fully attributable to alcohol",
                mort = n, ll_mort = n, up_mort = n) |>
  dplyr::select(year, age_group, gender, disease, mort, ll_mort, up_mort)

mortality_results <- dplyr::bind_rows(mortality_results, fully_attr)
```

**Variante (causas separadas, reporte estilo Shield)** — en vez de un solo "Fully attributable", agregar columnas por causa al `mutate` y sumarlas:

```r
fully_attr <- def |>
  dplyr::group_by(year, age_group, gender) |>
  dplyr::summarise(
    `Alcohol Use Disorders`    = sum(des_men + deg_nerv + polineu + myopathy_oh + fetal_oh, na.rm = TRUE),
    `Alcoholic Cardiomyopathy` = sum(cardiomio, na.rm = TRUE),                # I42.6
    `Alcohol-induced Pancreatitis/Gastritis` = sum(pancreati_oh + gastrit, na.rm = TRUE),
    `Alcohol Poisoning`        = sum(enven_acc + enven_int + enven_indet, na.rm = TRUE), # X45/X65/Y15
    .groups = "drop"
  ) |>
  tidyr::pivot_longer(-c(year, age_group, gender), names_to = "disease", values_to = "n") |>
  dplyr::filter(n > 0) |>
  dplyr::mutate(mort = n, ll_mort = n, up_mort = n) |>
  dplyr::select(year, age_group, gender, disease, mort, ll_mort, up_mort)

mortality_results <- dplyr::bind_rows(mortality_results, fully_attr)
```

---

## 4. Nota para documentación / methods (EN — notebook)

> **Wholly (100%) alcohol-attributable causes.** Following Shield et al. 2025 (Supplement, cause 860 "Alcohol use disorders": F10, G72.1, Q86.0, X45 — flagged *100% alcohol attributable*; and alcoholic cardiomyopathy I42.6, estimated within the cardiomyopathy/myocarditis/endocarditis envelope I30–I33, I38, I40, I42), wholly-attributable deaths are assigned AAF = 1 and **included in the total burden**. In the inherited pipeline (`Paper mortality trends.R`; `revision_datos.ipynb`; `expand_pif.ipynb`), the `aaf1` block was computed (F10, G31.2, G62.1, G72.1, Q86.0, **I42.6**, K86.0, K29.2, X45, X65, Y15) but **never summed into `mortality_results`**, so these deaths were absent from the total. This was corrected by binding a fully-attributable table (AAF = 1) before aggregation. Alcoholic cardiomyopathy (I42.6) is counted from directly-coded deaths (DIAG1 == "I426") rather than Shield's regression imputation; the non-alcoholic remainder of I30–I42 is not modelled, as no usable RR exists for it in the WHO 2024 / Adam function set.

## 5. Nota para documentación / tesis (ES)

> **Causas 100% atribuibles al alcohol.** Siguiendo a Shield et al. (2025) (Material suplementario, causa 860 "Alcohol use disorders": F10, G72.1, Q86.0, X45, señaladas como *100% alcohol attributable*; y la cardiomiopatía alcohólica I42.6, estimada dentro del grupo cardiomiopatía/miocarditis/endocarditis I30–I33, I38, I40, I42), las defunciones íntegramente atribuibles se asignan con una FAA = 1 y **se incorporan al total**. En el pipeline heredado, el bloque `aaf1` (F10, G31.2, G62.1, G72.1, Q86.0, I42.6, K86.0, K29.2, X45, X65, Y15) se calculaba pero **no se sumaba** a `mortality_results`, por lo que estas muertes quedaban fuera del total; esto se corrigió incorporando una tabla íntegramente atribuible (FAA = 1) previo a la agregación. La cardiomiopatía alcohólica (I42.6) se contabiliza desde los códigos directamente registrados (DIAG1 == "I426"), en lugar de la imputación por regresión de Shield; el resto de I30–I42 (cardiomiopatías no alcohólicas, mio/endocarditis) no se modela por no existir una RR utilizable en el set WHO 2024 / Adam.

---

## 6. Salvedad antes de sumar (para no comerte un revisor)

Confirma que `aaf1` sea **disjunto** de las causas parciales (lo es: K860 fuera de `panc`, X45 fuera de poisonings, I426 no está en ninguna parcial) → sin doble conteo. Y reporta la magnitud: solo en intoxicaciones X45 ya son ~2.050 muertes (2008–2024); F10 (trastornos por alcohol) suele ser la causa 100% más grande.
