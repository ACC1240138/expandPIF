# Wrapper to execute expand_pif2.ipynb code cells directly in R.
# This bypasses Quarto's .ipynb execution path, which does not execute the
# notebook because the .ipynb lacks a kernelspec. The wrapper extracts only
# code cells, writes them to a temp .R file, and sources it.
#
# Run from __andres_control/ with:
#   "C:/Program Files/R/R-4.4.1/bin/Rscript.exe" run_expand_pif2_full.R

.t0 <- Sys.time()

notebook_path <- "expand_pif2.ipynb"
stopifnot(file.exists(notebook_path))

nb <- jsonlite::fromJSON(notebook_path, simplifyVector = FALSE)

# Extract only code cells and label them for easier debugging.
code_cells <- Filter(function(cell) identical(cell$cell_type, "code"), nb$cells)

lines <- character()
for (i in seq_along(code_cells)) {
  cell <- code_cells[[i]]
  src <- cell$source
  if (is.list(src)) src <- unlist(src, use.names = FALSE)
  src <- as.character(src)
  src <- paste(src, collapse = "")
  
  label <- cell$id
  if (is.null(label) || !nzchar(label)) label <- paste0("cell_", i)
  
  lines <- c(
    lines,
    paste0("# --- cell: ", label, " ---"),
    src,
    ""
  )
}

out_file <- tempfile(pattern = "expand_pif2_extracted_", fileext = ".R")
writeLines(lines, out_file)

message("[wrapper] Extracted ", length(code_cells), " code cells to ", out_file)
message("[wrapper] Starting source() ...")

# Source in the current working directory (__andres_control).
source(out_file, echo = TRUE, max.deparse.length = 1e4)

message(sprintf(
  "[wrapper] Total elapsed minutes: %.2f",
  as.numeric(difftime(Sys.time(), .t0, units = "mins"))
))
