# Auditoría de los códigos de José Ruiz Tagle (injuries) — ICD‑10 / AAF

**Fecha:** 2026‑06‑25
**Archivos adjuntos auditados:** `resultadosinjuries.zip` (`functions.R`, `run_comparison.R`, `icd10_codes_inj.R`, `Mortality injuries.R`, `paf_comparisonV2.xlsx`, `pif_comparisonV2.xlsx`) y `reresultadosinjuries.zip` (los 4 `.rds`).
**Referencias de verdad usadas:** `_bib/Table S6 Shield et al 2025 ICD-10 classification.pdf` (leído como imagen) y tu propio `__andres_control/expand_pif.ipynb` (celdas 9–10).
**Método:** triple verificación independiente — (1) lectura directa del PDF de Shield S6, (2) auditoría adversarial de la lógica de conjuntos, (3) conteo numérico sobre los **131.824 registros reales** de `mortality_data_injuriesV2.rds`.

---

## 0. Veredicto en una línea

`functions.R` y `run_comparison.R` que mandó JRT son **byte‑idénticos** a la versión que ya auditamos el 16‑jun → las 4 divergencias de esa auditoría **siguen vigentes**. Lo **nuevo** es `icd10_codes_inj.R`: está bien construido en su mayor parte (97,06 % de las muertes bien clasificadas, sin doble conteo), pero **diverge de tu propia decisión ya tomada en `expand_pif.ipynb`** en tres puntos que afectan directamente los AAF: **X45 (intoxicación alcohólica accidental, AAF=1) — 2.050 muertes se pierden**, **X30–X39 (fuerzas de la naturaleza) — 1.041 muertes**, y **X65 dentro de self‑harm parcial — 7 muertes**.

---

## 1. Qué audité y qué es realmente nuevo

| Archivo de JRT | ¿Nuevo? | Estado |
|---|---|---|
| `functions.R` | **No** — idéntico a `udpate jun 26/functions.R` | Las 4 divergencias del 16‑jun siguen presentes (§5). |
| `run_comparison.R` | **No** — idéntico | Sin cambios. Corre los 2 contrafácticos (hed/volume) y la sensibilidad. |
| `icd10_codes_inj.R` | **Sí** | El foco de esta auditoría (§3–§4). |
| `Mortality injuries.R` | **Sí** | Aplica los códigos a la data; matchea **solo `diag2`** (§4, H5). |
| `paf/pif_comparisonV2.xlsx` | **Sí** | Resultados sanos: sin NaN, todo en [0,1], punto dentro del IC (§5). |

> Conclusión de arranque: la parte de PAF/PIF **no cambió**, así que esta auditoría no la repite — la confirma (§5). El trabajo real está en los **códigos ICD‑10 / AAF**, que es justo lo que necesitas dejar "robusto y bien elegido".

---

## 2. Cómo lo verifiqué (para que confíes en los números)

1. **Ground truth Shield S6**: el PDF no tiene capa de texto (es un escaneo), así que se leyó rasterizado, celda por celda. Resultado verbatim en §3.
2. **Auditoría adversarial de conjuntos**: se replicó en Python la lógica exacta de `expand_codes()` de JRT y de tu `icd_codes_s6()/icd_stems_s6()`, y se calcularon las diferencias de conjuntos. JRT genera **3.764** códigos distintos; tu versión Shield, **3.885**. Diferencia: 132 que tú tienes y JRT no + 11 que JRT tiene y tú no.
3. **Conteo sobre datos reales**: se parseó `mortality_data_injuriesV2.rds` (**131.824 defunciones**, 2008–2024, ≥15 años) y se contó cuántas muertes caen en cada hueco. Esto convierte "faltan códigos" en "se pierden N muertes".

---

## 3. Verdad de referencia: Shield et al. 2025, Table S6 (filas de injuries, verbatim)

| Código | Categoría | ICD‑10 (verbatim de la tabla) |
|---|---|---|
| 1520 | **A. Unintentional injuries (padre)** | **V01–X40, X43, X46–59, Y40–86, Y88, Y89** |
| 1530 | Road injury | V01–V04, V06, V09–V80, V87, V89, V99 |
| 1540 | Poisonings | X40, X43, X46–48, X49 |
| 1550 | Falls | W00–19 |
| 1560 | Fire, heat, hot substances | X00–19 |
| 1570 | Drowning | W65–74 |
| 1575 | Exposure to mechanical forces | W20–38, W40–43, W45, W46, W49–52, W75, W76 |
| 1590 | Other unintentional injuries | **Rest of V, W39, W44, W53–64, W77–99, X20–29, X50–59, Y40–86, Y88, Y89** |
| 1600 | **B. Intentional injuries (padre)** | (celda ICD vacía) |
| 1610 | Self‑harm | **X60–84, Y870** |
| 1620 | Interpersonal violence | X85–Y09, Y871 |

**El matiz clave (y por qué esto NO es un simple "JRT está mal"):**

- En la **fila de subcategoría** "Other unintentional" (1590), Shield **NO lista** W47–W48 ni X30–X39. De hecho **no existe una fila "7. Exposure to forces of nature"** en la tabla — la numeración salta del 6 al 8.
- Pero la **fila padre** (1520) sí dice "**V01–X40**…", un rango continuo que **sí barre** W47–48 y X30–39 (ambos < X40).
- Es decir, **la propia Table S6 es internamente inconsistente**: el padre es más ancho que la suma de sus subfilas.

Por eso hay dos lecturas legítimas:
- **Reproducción estricta de subfilas** → excluye W47–48 y X30–39. **Esto es lo que hizo JRT.**
- **Cierre del envelope padre** → incluye W47–48 y X30–39. **Esto es lo que decidiste tú** en `expand_pif.ipynb` (celda 9: *"decided explicitly … to close the parent unintentional category by adding W47‑W48 and X30‑X39"*; celda 10: *"Added W47‑W48 and X30‑X39 to close the parent row"*).

→ JRT no contradice a Shield; **contradice tu decisión ya tomada.** El entregable debe usar **una** convención, y la coherente con tu notebook es cerrar el envelope.

Sobre **X45 / X65 / Y15**: Table S6 es una tabla de *riesgo relativo / causalidad*, **no** marca AAF=1. Esos códigos (100 % atribuibles al alcohol) se manejan **fuera** de S6 — y tu `expand_pif.ipynb` ya lo hace (bloque `aaf1`: `enven_acc=X45`, `enven_int=X65`, `enven_indet=Y15`). `icd10_codes_inj.R` de JRT **no tiene ese bloque**.

---

## 4. Hallazgos sobre `icd10_codes_inj.R` (con muertes reales)

De 131.824 defunciones, JRT clasifica correctamente **127.954 (97,06 %)**. Caen fuera **3.870 (2,94 %)**. Desglose:

| # | Hallazgo | Códigos | Muertes | Severidad | Qué hace tu `expand_pif.ipynb` |
|---|---|---|---:|---|---|
| **H1** | **X45 (intox. alcohólica accidental) se pierde por completo** | X45* | **2.050** | **Alta** — son AAF=1 (100 % alcohol) | Las captura como `enven_acc` (AAF=1) |
| **H2** | **X30–X39 (fuerzas de la naturaleza) excluidas** | X30*–X39* | **1.041** | Media — decisión envelope vs subfila | Las incluye (cierre de envelope) |
| **H3** | **X65 queda como self‑harm parcial** | X65* | **7** | Baja (nº), conceptual | La saca de self‑harm → AAF=1 (`enven_int`) |
| **H4** | W47–W48 ausentes | W47*–W48* | **0** | Nula en la práctica | Las incluye (inocuo aquí) |
| **H5** | Match solo en `diag2` | — | 0 perdidos | Nula en estos datos | Matchea `diag1 | diag2` (redundante aquí) |

### H1 — X45: el hallazgo importante (2.050 muertes, AAF=1)

`poisonings_codes` de JRT = X40, X43, X46, X47, X48, X49. **X45 no está en ningún bucket** y **no hay bloque AAF=1**, así que las 2.050 muertes por **intoxicación accidental por alcohol** simplemente **desaparecen** del archivo de injuries. Son las muertes *más* atribuibles al alcohol que existen (100 %). En tu pipeline van como `enven_acc` (AAF=1); en el de JRT no van a ningún lado.
*(Top códigos perdidos confirmados en la data: X459=936, X450=718, X454=261, X458=118…)*

> Nota: excluir X45 del bucket *parcial* de poisonings es **correcto** (no debe recibir un AAF fraccional). El problema es que JRT no las recupera en ningún lado.

### H2 — X30–X39: 1.041 muertes (decisión, no bug)

Desglose por código: **X31 (frío natural) 509 · X34 (terremoto) 448 · X36 (aluvión/derrumbe) 67 · X30 (calor) 12 · X33 2 · X32, X35, X37 1 c/u**. Tienen sentido en Chile (sismos, frío). Bajo "reproducción estricta" (JRT) se excluyen; bajo "cierre de envelope" (tu notebook) se incluyen. *Pregunta epidemiológica honesta a zanjar:* ¿tiene sentido aplicarle un AAF de alcohol a una muerte por terremoto? GBD las barre en "other unintentional"; tú ya decidiste incluirlas. Solo asegúrate de que sea la misma decisión en ambos lados.

### H3 — X65: sacarlo de self‑harm (7 muertes)

`self_harm_codes` de JRT = X60–X84 + Y870, que **incluye X65** (autointoxicación intencional por alcohol). Eso le da a esas muertes un AAF *parcial* de self‑harm cuando deberían ser AAF=1. Son solo 7, pero conceptualmente hay que sacarlas de self‑harm (como ya haces con `setdiff(self_harm_codes_shield, x65…)`).

### H4 — W47–W48: hueco real pero inocuo

Entre `mechanical_forces` (…W45, W46, **W49**–W52…) y `other_unintentional` (…W44, **W53**–W64…) quedan W47–W48 en tierra de nadie. En los datos chilenos: **0 muertes**. Lo cierras gratis al cerrar el envelope.

### H5 — `diag1` vs `diag2`: equivalente aquí, pero ojo con el filtro de arriba

JRT matchea solo `diag2`; tú matcheas `diag1 | diag2`. Verificado empíricamente: `diag1` contiene la **naturaleza de la lesión** (T=79.637, S=52.187), no la causa externa; `diag2` es la causa externa (V/W/X/Y) y está poblada en el 100 % de las filas. Registros donde la causa externa esté en `diag1` y no en `diag2`: **0**. → En *estos* datos, `diag2`‑solo y `diag1|diag2` dan lo mismo; tu doble match es redundante (inofensivo).
**Pero**: `Mortality injuries.R` filtra `diag2 != ""` *antes* de clasificar. Si en el CSV crudo del DEIS alguna defunción por lesión trae la causa externa en `diag1` con `diag2` vacío, ese filtro la borra antes de que nadie la vea. No pude testearlo (el archivo ya viene filtrado); es el único punto de `diag2`‑solo que vale la pena revisar en el crudo.

### Lo que JRT hace BIEN (para que no sobre‑corrijas)

- **Sin doble conteo**: las 9 categorías hoja son disjuntas (0 intersecciones). El `setdiff(all_v, road)` evita contar dos veces los V.
- **X41/X42/X44 excluidos correctamente** de poisonings (no son alcohol‑poisonings de Shield) — caen fuera *a propósito*; coincide con tu notebook.
- **Road, mechanical, falls, fire, drowning**: rangos idénticos a tu versión Shield.
- **V81–V86 → "rest of V"** (no road): coincide con Shield y con tu notebook. Lo documenta en el comentario.
- **V00** se omite en ambos (JRT y tú) — defunciones 0 en la data; irrelevante.

---

## 5. `functions.R` / `run_comparison.R`: idénticos → divergencias del 16‑jun vigentes

Como el archivo es byte‑idéntico al auditado, las 4 divergencias siguen exactamente igual (ver `explicacion_divergencias.md` y la sección caveman del 16‑jun para el detalle didáctico):

1. **PIF troceado en `cut=60`** (L230–231) vs PAF normalizado en rango completo (L104) → baseline NHED distinto entre PAF y PIF.
2. **Colapso de `w_curr`** (L141–142 sortean `p_abs`,`p_form` independientes; L108 `max(0,1−(p_abs+p_form))`) → PAF=0 espurios en tramos de alta abstinencia.
3. **ICs asimétricos**: PAF sin clamp a [0,1] (L148–150); PIF/vol con clamp.
4. **`s_hed` remuestreado en PAF (L143) pero fijo en PIF** + `neff=1000` binomial ignora el efecto de diseño.

**Resultados (`xlsx`)**: 360 filas PAF + 2.160 PIF, **sin NaN, todo en [0,1], punto siempre dentro del IC**. Corren `dataset` ∈ {original, sensitivity}, `cf_type` ∈ {hed, volume}, `shift` ∈ {10,20,30 %}, 3 enfermedades (Intentional, Road, Unintentional). O sea: el pipeline corre sano; la incoherencia es la del baseline PAF↔PIF, no un crash.

---

## 6. Recomendaciones priorizadas (para AAFs robustos)

1. **(ICD, prioridad 1) Unificar en una sola fuente de verdad.** Tu `expand_pif.ipynb` (celdas 9–10) **ya es la versión correcta y cerrada**. Lo más seguro es que el pipeline de injuries **consuma esos mismos vectores**, no el `icd10_codes_inj.R` de JRT. Si se mantiene el `.R` separado, hay que portarle: W47–48, X30–39, quitar X65 de self‑harm, y añadir el bloque AAF=1.
2. **(ICD, prioridad 1) Decidir y documentar X45/X65/Y15.** Son ~2.057 muertes 100 % atribuibles. O entran al pipeline de injuries como AAF=1, o se cuentan explícitamente en el all‑cause — pero **que quede escrito dónde**, para no perderlas ni duplicarlas.
3. **(ICD, prioridad 2) Ratificar envelope vs subfila para X30–39/W47–48** y aplicarlo idéntico en ambos lados. Recomendación: cierre de envelope (tu decisión actual), documentando el supuesto de aplicar AAF a fuerzas de la naturaleza.
4. **(ICD, prioridad 3) Revisar el filtro `diag2 != ""`** en el CSV crudo del DEIS (H5).
5. **(funciones) Las 4 divergencias del 16‑jun siguen sin resolverse** — no son de este encargo, pero siguen en la cola para que el PAF y el PIF "hablen el mismo idioma".

---

## 7. Apéndice — reproducibilidad

- Lógica de conjuntos y conteos: parser RDS propio (Python puro, decodifica latin‑1) + réplica de `expand_codes`. Total 131.824; capturados 127.954; X45=2.050; X30‑39=1.041; X65=7; W47‑48=0; Y15=0.
- Shield S6: lectura de imagen del PDF, filas de injuries transcritas verbatim en §3.
- `functions.R` vs `udpate jun 26/functions.R`: `diff` → idénticos. `run_comparison.R`: idéntico.
