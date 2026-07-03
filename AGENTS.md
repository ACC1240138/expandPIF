# Agent Instructions

## Code & File Editing Rules

- **No notebooks or Quarto files will be edited without your explicit permission.**
- **R syntax will use the `function::package` format, and `library()` will be used only when necessary.**
- **Chunks will start with `.t0` and report elapsed time in minutes.**
- **All code comments and messages will be in English unless you ask otherwise.**
- **Watch out for mojibake characters, as incompatibilities between UTF‑8 and Latin1 may occur**

## Handoff Notes

- Sometimes the user would like to append findings or reflections in handoff caveman format to:
  `C:\Users\nDP\Desktop\ACC1240138_private\__andres_control\codex_handoff_adam_rr_full_override_caveman.md`
- Caveman handoff: "codex_handoff_adam_rr_full_override_caveman.md"
- it may be in: "C:\Users\nDP\Desktop\ACC1240138_private\__andres_control\"
- or in getwd() + "/ACC1240138_private/__andres_control/"
- Always add the **date and hour** when appending to this file.

## Imported Claude Cowork project instructions

## Main roadmap

Treat `presentacion_micsim.qmd` and `presentacion_micsim.html` as the working roadmap for current project organization, practical priorities, and presentation language. However, treat claims of completion in the presentation as provisional until independently checked against code, outputs, and validation summaries. Our work should resemble Kilian C, Buckley C, Lemp JM, et al. Targeting alcohol use in high risk population groups: a US microsimulation study of beverage-specific pricing policies. Lancet Public Health 2025; published online Aug 27. https://doi.org/10.1016/S2468-2667(25)00165-3

Current working structure:

* **Mortality:** PAF/AAF estimates and cause-specific alcohol-attributable mortality. Some materials may describe the PAF matrix as complete, but this should be treated as under review until the user confirms it or the pipeline is re-validated.
* **Policy counterfactuals:** PIF scenarios for avoidable mortality and years of potential life lost under changes in exposure, with current work especially focused on injuries and heavy episodic drinking. Expansion to chronic causes and former drinkers requires additional review.
* **Elasticity:** EPF harmonization and own-price/cross-price elasticity estimation. Always document whether estimates capture only the intensive margin or also participation/extensive-margin effects.
* **Simulation:** MicSim or microsimulation prototypes, state space, transition models, calibration, and full simulation cycles.
* **Integration:** connect PAF/PIF, elasticity, and microsimulation into policy scenarios.

When planning work, preserve this structure: mortality, policy counterfactuals, elasticity, simulation, integration.

## RR override and handoff constraints

Some analyses use updated or externally supplied relative-risk objects that override earlier pipeline defaults. These details may change as the user reviews the pipeline.

Before changing RR, PAF, or AAF code:

* Check the current handoff notes and active code before assuming which override is authoritative.
* __andres_control/_bib/supp_Shield et al. 2025 National, regional, and global statistics on alcohol consumption and associated burden of disease 2000-20.pdf Shield et al. 2025 (sometimes named WHO 2024/OMS 2024/adam) supplementary material should indicate ICD-10 codes
* __andres_control/GENERAL_*.R are authoritative because they are the validated RR functions by alcohol use + HED + sometimes stratified by age/sex
* Preserve downstream object names and table structures unless the user explicitly asks to change them.
* Do not add new causes, ICD-10 groups, RR families, or disease categories unless they are present in the data and explicitly requested.
* Keep RR sources modular, auditable, and traceable to source files or source objects.
* Distinguish current-drinker, former-drinker, and HED/binge components when the method requires it.
* Do not apply changes made for one module, such as AAF estimation, to a different module, such as PIF scenarios, unless the user explicitly asks.
* When sourcing helper scripts, avoid loading files in an order that silently redefines functions with incompatible signatures. Prefer project-level loader functions when available, and verify key function signatures after sourcing.
* If a handoff contains highly specific instructions, treat them as temporary implementation context rather than permanent global rules.

## Testing and validation

After code changes, run the relevant tests, smoke tests, or minimal validation scripts when available.

Prefer the closest validation to the modified component, for example:

* source or registry tests for RR objects;
* small end-to-end checks for PAF/AAF tables;
* object-existence and column-schema checks before `bind_rows()`;
* comparison of row counts, cause groups, sex/age strata, and year coverage before and after changes;
* sanity checks for impossible values, such as negative attributable deaths, PAFs outside the expected range, missing ICD-10 mappings, or unexpected `NA`s;
* calibration and loss-function checks for simulation modules.

Do not hard-code a permanent list of test scripts into the global instructions, because test names and file locations may change.

If tests pass but the relevant code has not been executed with real project data, say so explicitly. Passing unit tests is not the same as validating the full pipeline.