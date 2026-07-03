# Cargar librerías
library(ggplot2)
library(patchwork)

set.seed(2125)
# 1. Definir exposición y distribución poblacional (Gamma)
x <- seq(0, 150, length.out = 1000)
gamma_dens <- dgamma(x, shape = 2, scale = 15)
scale_factor <- 4 / max(gamma_dens) # Ajuste visual para el fondo

print(paste0("Percentil del valor 36: ", pgamma(36, shape = 2, scale = 15) * 100))
# 2. Configurar parámetros del Modelo Continuo (Polinómico)
betaCurrent <- c(0, -0.00058, 0.000034, 0)
covBetaCurrent <- matrix(c(
  0, 0, 0, 0,
  0, 0.000001038, -0.00000000479, 0,
  0, -0.00000000479, 0.0000000000225, 0,
  0, 0, 0, 0
), nrow = 4, ncol = 4)

# 3. Construir matriz de diseño X para el cálculo de la varianza punto a punto
# Cada fila representa [1, x, x^2, x^3]
X_mat <- cbind(1, x, x^2, x^3)

# Predictor lineal (log RR)
lp_poly <- X_mat %*% betaCurrent

# Método Delta: Var(LP) = diag(X %*% Cov %*% t(X))
# Optimizado en R para evitar calcular una matriz gigante de 1000x1000:
var_lp_poly <- rowSums((X_mat %*% covBetaCurrent) * X_mat)
se_lp_poly <- sqrt(var_lp_poly)

# 4. Crear el Data Frame Base
df <- data.frame(
  x = x,
  densidad_escalada = gamma_dens * scale_factor,
  # Modelo Continuo con sus IC 95%
  rr_poly = exp(lp_poly),
  poly_low = exp(lp_poly - 1.96 * se_lp_poly),
  poly_high = exp(lp_poly + 1.96 * se_lp_poly)
)

# 5. Agregar el Modelo de Umbral (Paso) con sus IC 95%
se_step <- 0.133617

# Hombres (Base: log(1.20))
df$rr_step_m  <- ifelse(df$x < 36, 1, 1.20)
df$step_m_low  <- ifelse(df$x < 36, 1, exp(log(1.20) - 1.96 * se_step))
df$step_m_high <- ifelse(df$x < 36, 1, exp(log(1.20) + 1.96 * se_step))

# Mujeres (Base: log(3.23))
df$rr_step_f  <- ifelse(df$x < 36, 1, 3.23)
df$step_f_low  <- ifelse(df$x < 36, 1, exp(log(3.23) - 1.96 * se_step))
df$step_f_high <- ifelse(df$x < 36, 1, exp(log(3.23) + 1.96 * se_step))


# 6. GRAFICAR - HOMBRES
plot_male <- ggplot(df, aes(x = x)) +
  geom_area(aes(y = densidad_escalada), fill = "gray70", alpha = 0.25) +
  # Bandas de confianza (Ribbons)
  geom_ribbon(aes(ymin = poly_low, ymax = poly_high), fill = "blue", alpha = 0.15) +
  geom_ribbon(aes(ymin = step_m_low, ymax = step_m_high), fill = "red", alpha = 0.1) +
  # Líneas de los modelos
  geom_line(aes(y = rr_poly, color = "Continuo"), linewidth = 1) +
  geom_line(aes(y = rr_step_m, color = "Umbral"), linetype = "dashed", linewidth = 1) +
  scale_color_manual(values = c("Continuo" = "blue", "Umbral" = "red")) +
  scale_y_continuous(limits = c(0.5, 4.5), name = "Riesgo Relativo (RR)") +
  labs(title = "IC 95% Cáncer Estómago - Hombres", x = "Alcohol (g/día)", color = "Modelo") +
  theme_minimal() + theme(legend.position = "bottom")

# 7. GRAFICAR - MUJERES
plot_female <- ggplot(df, aes(x = x)) +
  geom_area(aes(y = densidad_escalada), fill = "gray70", alpha = 0.25) +
  # Bandas de confianza (Ribbons)
  geom_ribbon(aes(ymin = poly_low, ymax = poly_high), fill = "blue", alpha = 0.15) +
  geom_ribbon(aes(ymin = step_f_low, ymax = step_f_high), fill = "red", alpha = 0.1) +
  # Líneas de los modelos
  geom_line(aes(y = rr_poly, color = "Continuo"), linewidth = 1) +
  geom_line(aes(y = rr_step_f, color = "Umbral"), linetype = "dashed", linewidth = 1) +
  scale_color_manual(values = c("Continuo" = "blue", "Umbral" = "red")) +
  scale_y_continuous(limits = c(0.5, 4.5), name = "Riesgo Relativo (RR)") +
  labs(title = "IC 95% Cáncer Estómago - Mujeres", x = "Alcohol (g/día)", color = "Modelo") +
  theme_minimal() + theme(legend.position = "bottom")

# Desplegar ambos gráficos juntos
plot_male + plot_female