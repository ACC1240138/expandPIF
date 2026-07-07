# .t0
# install.packages("nanoparquet")
# install.packages("data.table")

input_csv <- ""
output_parquet <- ""

# 1. Leer CSV con data.table (rápido para archivos grandes)
df <- data.table::fread(
  input = input_csv,
  encoding = "UTF-8",   # prueba "Latin-1" si salen caracteres extraños
  data.table = FALSE    # devuelve data.frame
)

# 2. Guardar como Parquet con compresión zstd
nanoparquet::write_parquet(
  x = df,
  file = output_parquet,
  compression = "zstd"
)

# 3. Comparar tamaños
size_csv <- file.size(input_csv) / 1024^2
size_parquet <- file.size(output_parquet) / 1024^2
cat(sprintf("CSV: %.1f MB\nParquet: %.1f MB (%.1f%% of the original)\n",
            size_csv, size_parquet, 100 * size_parquet / size_csv))

# 4. Verificar que se lee bien
df_check <- nanoparquet::read_parquet(output_parquet)
cat("rows:", nrow(df_check), "| columns:", ncol(df_check), "\n")