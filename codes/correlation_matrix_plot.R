library(sf)
library(terra)
library(dplyr)
library(corrplot)

predictors_folder <- "predictors"
soil_file <- "data/suelos_motupe_model.gpkg"
boundary_file <- "data/borde_motupe.gpkg"
output_plot <- "plots/predictor_correlation_matrix.png"

dir.create(dirname(output_plot), recursive = TRUE, showWarnings = FALSE)

raster_files <- list.files(predictors_folder, pattern = "\\.tif$", full.names = TRUE)
stopifnot(length(raster_files) > 0)

covariates <- terra::rast(raster_files)
names(covariates) <- make.names(tools::file_path_sans_ext(basename(raster_files)))

covsoc <- sf::read_sf(soil_file)
boundary <- sf::read_sf(boundary_file) |> sf::st_transform(sf::st_crs(covsoc))

covariates_masked <- covariates |> terra::crop(boundary) |> terra::mask(boundary)
covsoc_extract <- terra::extract(covariates_masked, covsoc, bind = TRUE) |> sf::st_as_sf()
covsoc_extract$X <- NULL
covsoc_extract$Y <- NULL

cor_input <- sf::st_drop_geometry(covsoc_extract)[names(covariates_masked)]
cor_input <- cor_input |> dplyr::select(where(is.numeric))
cor_input <- cor_input[complete.cases(cor_input), ]
stopifnot(ncol(cor_input) >= 2)

cor_matrix <- stats::cor(cor_input)

cor_pmat <- function(mat) {
  n <- ncol(mat)
  p <- matrix(0, nrow = n, ncol = n, dimnames = list(colnames(mat), colnames(mat)))
  for (i in 1:(n - 1)) {
    for (j in (i + 1):n) {
      test <- stats::cor.test(mat[, i], mat[, j])
      p[i, j] <- p[j, i] <- test$p.value
    }
  }
  p
}

p_matrix <- cor_pmat(cor_input)

order_idx <- corrplot::corrMatOrder(cor_matrix, order = "hclust")
cor_matrix_ord <- cor_matrix[order_idx, order_idx, drop = FALSE]
p_matrix_ord <- p_matrix[order_idx, order_idx, drop = FALSE]

png(output_plot, width = 3000, height = 2600, res = 400)
corrplot::corrplot(
  cor_matrix_ord,
  method = "color",
  type = "lower",
  order = "original",
  tl.cex = 0.75,
  tl.col = "black",
  col = colorRampPalette(c("blue", "white", "red"))(200),
  cl.length = 4,
  cl.align.text = "c",
  title = "Predictor Correlation Matrix",
  mar = c(0, 0, 2, 0),
  addCoef.col = "black",
  number.cex = 0.30,
  p.mat = NULL
)

n <- nrow(cor_matrix_ord)
sig_labels <- matrix("", nrow = n, ncol = n, dimnames = dimnames(cor_matrix_ord))
for (i in seq_len(n)) {
  for (j in seq_len(n)) {
    if (i >= j) {
      p_val <- p_matrix_ord[i, j]
      if (!is.na(p_val)) {
        if (p_val < 0.01) {
          sig_labels[i, j] <- "**"
        } else if (p_val < 0.05) {
          sig_labels[i, j] <- "*"
        }
      }
    }
  }
}

par(xpd = NA)
for (i in seq_len(n)) {
  for (j in seq_len(n)) {
    if (sig_labels[i, j] != "") {
      text(
        x = j + 0.3,
        y = n - i + 1,
        labels = sig_labels[i, j],
        cex = 0.25,
        col = "black"
      )
    }
  }
}
par(xpd = FALSE)
dev.off()
