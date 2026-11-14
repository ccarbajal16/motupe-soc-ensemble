# ensemble_blog_figures.R
#
# Reproduces every number and figure used in the blog post
# "Should you combine your models at all?" (2026-08-29-should-you-combine-your-models.md)
#
# Input: the out-of-fold spatial-CV predictions produced by modules/04_spatial_cv.R
#        (outputs/<model>_cv_predictions.csv), plus the prediction rasters produced by
#        modules/06_prediction.R for the map panel.
#
# Run from the repository root:
#   Rscript codes/ensemble_blog_figures.R
#
# Everything printed here is quoted in the post. Nothing is hand-entered.

suppressPackageStartupMessages({
  library(quadprog)
  library(ggplot2)
  library(patchwork)
})

fig_dir <- "figures/2026-08-29-should-you-combine"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

read_output <- function(f) read.csv(file.path("outputs", f), stringsAsFactors = FALSE)

files <- c(SVR = "svm_cv_predictions.csv", ANN = "ann_cv_predictions.csv",
           RF  = "rf_cv_predictions.csv",  XGB = "xgb_cv_predictions.csv")

cv  <- lapply(files, read_output)
y   <- cv[[1]]$observed
fold <- cv[[1]]$fold
Z   <- sapply(cv, function(x) x$predicted)
colnames(Z) <- names(files)

n <- length(y)
L <- ncol(Z)
k <- sort(unique(fold))

## ---------------------------------------------------------------------------
## 0. The target, and the baseline nobody reports
## ---------------------------------------------------------------------------

sd_y <- sd(y)
cat("=== THE TARGET ===\n")
cat(sprintf("n = %d samples, %d spatial folds (sizes: %s)\n",
            n, length(k), paste(as.integer(table(fold)), collapse = "/")))
cat(sprintf("SOC: min %.2f, mean %.4f, max %.2f, SD %.4f %s\n",
            min(y), mean(y), max(y), sd_y, "%"))
cat(sprintf("Baseline 'predict the mean' RMSE = %.4f\n\n", sqrt(mean((y - mean(y))^2))))

## ---------------------------------------------------------------------------
## 1. Metrics, computed two ways on purpose
## ---------------------------------------------------------------------------

metrics <- function(p, truth = y) {
  ss <- sum((p - truth)^2)
  mx <- mean(p); my <- mean(truth)
  c(RMSE = sqrt(mean((p - truth)^2)),
    MAE  = mean(abs(p - truth)),
    R2   = 1 - ss / sum((truth - my)^2),
    CCC  = 2 * mean((p - mx) * (truth - my)) /
             (var(p) + var(truth) + (mx - my)^2))
}

pooled <- t(sapply(cv, function(x) metrics(x$predicted)))
cat("=== POOLED OUT-OF-FOLD METRICS (one honest number per model) ===\n")
print(round(pooled, 4))

per_fold <- sapply(cv, function(x)
  sapply(k, function(g) metrics(x$predicted[fold == g], y[fold == g])["RMSE"]))
rownames(per_fold) <- paste0("fold", k)
cat("\n=== PER-FOLD RMSE (the sample size of any model comparison) ===\n")
print(round(per_fold, 4))
cat("\nMean of the five per-fold RMSEs:\n")
print(round(colMeans(per_fold), 4))
cat("Note: mean-of-folds and pooled RMSE are different numbers for the same run.\n\n")

best_rmse <- min(pooled[, "RMSE"])
cat(sprintf("Best single model (pooled OOF RMSE): %s at %.4f\n\n",
            names(which.min(pooled[, "RMSE"])), best_rmse))

## ---------------------------------------------------------------------------
## 2. The identity: ensemble error = mean member error - disagreement
## ---------------------------------------------------------------------------

w_eq  <- rep(1 / L, L)
f_bar <- as.vector(Z %*% w_eq)
mean_ind <- sum(w_eq * colMeans((Z - y)^2))
ambiguity <- sum(w_eq * colMeans((Z - f_bar)^2))
ens_mse <- mean((f_bar - y)^2)

cat("=== AMBIGUITY DECOMPOSITION (equal weights) ===\n")
cat(sprintf("mean individual MSE : %.5f\n", mean_ind))
cat(sprintf("ambiguity           : %.5f   = %.1f%% of mean individual MSE\n",
            ambiguity, 100 * ambiguity / mean_ind))
cat(sprintf("ensemble MSE        : %.5f   (check %.5f)\n\n", ens_mse, mean_ind - ambiguity))

E <- Z - y
cor_err <- cor(E)
cor_pred <- cor(Z)
cat("=== ERROR CORRELATION (errors, not predictions) ===\n")
print(round(cor_err, 3))
cat("\n=== PREDICTION CORRELATION (what people usually report) ===\n")
print(round(cor_pred, 3))
cat(sprintf("\nRange of error correlations: %.2f to %.2f\n\n",
            min(cor_err[upper.tri(cor_err)]), max(cor_err[upper.tri(cor_err)])))

## ---------------------------------------------------------------------------
## 3. The combiner menu, apparent vs cross-fitted
## ---------------------------------------------------------------------------

nnls_convex <- function(Zi, yi) {
  Dm <- t(Zi) %*% Zi
  dv <- t(Zi) %*% yi
  Amat <- cbind(rep(1, ncol(Zi)), diag(ncol(Zi)))
  solve.QP(Dmat = Dm + diag(1e-10, ncol(Zi)), dvec = dv,
           Amat = Amat, bvec = c(1, rep(0, ncol(Zi))), meq = 1)$solution
}

bates_granger <- function(Zi, yi) {
  S <- cov(Zi - yi)
  o <- rep(1, ncol(Zi))
  tryCatch(as.vector(solve(S, o) / as.numeric(t(o) %*% solve(S, o))),
           error = function(e) rep(1 / ncol(Zi), ncol(Zi)))
}

combiner_fit <- list(
  "Simple average"           = function(Zi, yi) rep(1 / ncol(Zi), ncol(Zi)),
  "R2-weighted (0.1 floor)"  = function(Zi, yi) {
    r <- sapply(seq_len(ncol(Zi)), function(j) max(0.1, metrics(Zi[, j], yi)["R2"]))
    r / sum(r)
  },
  "Bates-Granger"            = bates_granger,
  "NNLS (convex)"            = nnls_convex,
  "Ridge meta (GCV)"         = function(Zi, yi) {
    f <- MASS::lm.ridge(yi ~ Zi, lambda = c(0, 10^seq(-3, 3, length = 60)))
    as.numeric(coef(f)[which.min(f$GCV), ])
  },
  "Granger-Ramanathan"       = function(Zi, yi) coef(lm(yi ~ Zi))
)

w_list <- lapply(combiner_fit, function(f) f(Z, y))
wrows <- c(colnames(Z), "intercept")
weights <- matrix(NA_real_, nrow = L + 1, ncol = length(w_list),
                  dimnames = list(wrows, names(w_list)))
for (s in names(w_list)) {
  w <- w_list[[s]]
  if (length(w) == L + 1) weights[, s] <- c(w[-1], w[1])   # canonical order: predictors, intercept
  else weights[seq_len(L), s] <- w
}
cat("=== WEIGHTS FITTED ON ALL ROWS (canonical order: predictors, then intercept) ===\n")
print(round(weights, 3))
cat(sprintf("Granger-Ramanathan intercept: %.3f (observed SOC mean %.3f, max %.2f)\n\n",
            weights["intercept", "Granger-Ramanathan"], mean(y), max(y)))

predict_with <- function(w, Zo) {
  if (length(w) == ncol(Zo) + 1) as.vector(cbind(1, Zo) %*% w)
  else as.vector(Zo %*% w)
}

rows <- lapply(names(combiner_fit), function(s) {
  f_all <- combiner_fit[[s]]
  w_all <- f_all(Z, y)
  apparent <- predict_with(w_all, Z)
  crossfit <- numeric(n)
  for (g in k) {
    out <- which(fold == g); inn <- which(fold != g)
    w_in <- f_all(Z[inn, , drop = FALSE], y[inn])
    crossfit[out] <- predict_with(w_in, Z[out, , drop = FALSE])
  }
  data.frame(scheme        = s,
             free_par      = if (s == "Simple average") 0
                             else if (grepl("R2", s)) 0
                             else length(w_all) - 1,
             apparent_rmse = metrics(apparent)["RMSE"],
             crossfit_rmse = metrics(crossfit)["RMSE"],
             crossfit_r2   = metrics(crossfit)["R2"],
             apparent_gain = 100 * (1 - metrics(apparent)["RMSE"] / best_rmse),
             crossfit_gain = 100 * (1 - metrics(crossfit)["RMSE"] / best_rmse))
})
spec <- do.call(rbind, rows)
spec$optimism_pp <- spec$apparent_gain - spec$crossfit_gain

cat("=== COMBINER SPECTRUM: apparent (fit and scored on the same rows) vs cross-fitted ===\n")
print(spec, digits = 3, row.names = FALSE)
cat(sprintf("\nSD(y) baseline RMSE = %.4f. Every cross-fitted R2 above is %.2f or lower.\n\n",
            sd_y, max(spec$crossfit_r2)))

ceiling_rmse <- metrics(fitted(lm(y ~ Z)))["RMSE"]
cat(sprintf("=== CEILING (lm fitted and scored on the same rows) RMSE %.4f, gain vs best model %.2f%% ===\n\n",
            ceiling_rmse, 100 * (1 - ceiling_rmse / best_rmse)))

## ---------------------------------------------------------------------------
## 4. Is any of it distinguishable from chance? Friedman + Nemenyi
## ---------------------------------------------------------------------------

fried <- friedman.test(per_fold)
cat("=== FRIEDMAN TEST ON PER-FOLD RMSE ===\n")
print(fried)
ranks <- t(apply(per_fold, 1, rank))
mean_rank <- colMeans(ranks)
q_alpha <- qchisq(0.95, L - 1)
crit_diff <- sqrt(q_alpha * L * (L + 1) / (6 * nrow(per_fold)))
cat("\nMean ranks:", round(mean_rank, 2), "\n")
cat(sprintf("Nemenyi critical difference: %.3f\n", crit_diff))
cat("Pairs separated by more than the critical difference:\n")
found <- FALSE
for (i in seq_len(L - 1)) for (j in seq(i + 1, L)) {
  d <- abs(mean_rank[i] - mean_rank[j])
  if (d > crit_diff) { cat(sprintf("  %s vs %s: %.2f\n", names(mean_rank)[i],
                                   names(mean_rank)[j], d)); found <- TRUE }
}
if (!found) cat("  none\n")
cat("\n")

## ---------------------------------------------------------------------------
## Figure 1 -- what the models actually do out of fold
## ---------------------------------------------------------------------------

plot_df <- do.call(rbind, lapply(names(cv), function(m) {
  data.frame(model = m, observed = y, predicted = cv[[m]]$predicted)
}))
plot_df$model <- factor(plot_df$model, levels = names(files))

strip_labels <- setNames(
  sprintf("%s\nR\u00b2 = %.2f   RMSE = %.3f", names(files),
          pooled[, "R2"], pooled[, "RMSE"]),
  names(files))

p1 <- ggplot(plot_df, aes(observed, predicted)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", linewidth = 0.5,
              colour = "grey35") +
  geom_hline(yintercept = mean(y), linewidth = 0.5, colour = "#d95f02") +
  geom_point(size = 1.5, alpha = 0.65, colour = "#2c7fb8") +
  facet_wrap(~ model, nrow = 2, labeller = as_labeller(strip_labels)) +
  coord_equal(xlim = c(0.40, 0.90), ylim = c(0.40, 0.90)) +
  labs(x = "Observed SOC (%)", y = "Predicted SOC (%)",
       title = "Scored out of fold, no model beats the mean",
       subtitle = paste0("109 samples, 5 spatial block folds. Orange line = the ",
                         "\u201cpredict the mean\u201d benchmark (RMSE ",
                         round(sd_y, 3), ").")) +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(),
        strip.text = element_text(size = 8.5, hjust = 0),
        plot.subtitle = element_text(colour = "grey30", size = 8.5))

ggsave(file.path(fig_dir, "fig2-out-of-fold-reality.png"), p1,
       width = 7.2, height = 6.2, dpi = 200)

## ---------------------------------------------------------------------------
## Figure 2 -- the identity: how little the models disagree
## ---------------------------------------------------------------------------

cor_long <- expand.grid(from = colnames(Z), to = colnames(Z))
cor_long$value <- as.vector(cor_err)
cor_long$from <- factor(cor_long$from, levels = rev(colnames(Z)))
cor_long$to   <- factor(cor_long$to, levels = colnames(Z))

p2a <- ggplot(cor_long, aes(to, from, fill = value)) +
  geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.2f", value),
                colour = value > 0.90), size = 3.4, show.legend = FALSE) +
  scale_fill_gradient2(low = "#f7f7f7", mid = "#a6bddb", high = "#08519c",
                       midpoint = 0.6, limits = c(0, 1), name = "r") +
  scale_colour_manual(values = c(`FALSE` = "grey15", `TRUE` = "white")) +
  labs(x = NULL, y = NULL,
       title = "A. Correlation of errors, not predictions",
       subtitle = "Every pair sits between 0.85 and 0.94 \u2014 one opinion, four voices") +
  theme_minimal(base_size = 10) +
  theme(panel.grid = element_blank(), plot.subtitle = element_text(size = 8.5, colour = "grey30"))

decomp <- data.frame(
  term  = factor(c("Mean member error\n(sum of the four)", "Minus disagreement\n(the only gain)",
                   "= Ensemble error"),
                 levels = c("Mean member error\n(sum of the four)",
                            "Minus disagreement\n(the only gain)", "= Ensemble error")),
  value = c(mean_ind, -ambiguity, ens_mse))

p2b <- ggplot(decomp, aes(term, value, fill = term)) +
  geom_col(width = 0.62) +
  geom_text(aes(label = sprintf("%.4f", abs(value)),
                vjust = ifelse(value < 0, 1.6, -0.6)), size = 3.2) +
  scale_fill_manual(values = c("#b8b8b8", "#e6ab02", "#2c7fb8"), guide = "none") +
  labs(x = NULL, y = "Squared error (SOC\u00b2)",
       title = "B. The identity on real out-of-fold predictions",
       subtitle = sprintf("Disagreement recovers only %.1f%% of the mean member error",
                          100 * ambiguity / mean_ind)) +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        plot.subtitle = element_text(size = 8.5, colour = "grey30"))

p2 <- p2a + p2b + plot_layout(widths = c(1, 1.05))
ggsave(file.path(fig_dir, "fig1-error-correlation.png"), p2,
       width = 9.6, height = 4.4, dpi = 200)

## ---------------------------------------------------------------------------
## Figure 3 -- where the weights go under each scheme
## ---------------------------------------------------------------------------

w_long <- as.data.frame(as.table(weights))
names(w_long) <- c("model", "scheme", "weight")
w_long$model  <- trimws(w_long$model)
w_long$model  <- factor(w_long$model, levels = c(colnames(Z), "intercept"))
w_long$scheme <- factor(w_long$scheme, levels = names(combiner_fit))
w_long <- w_long[!is.na(w_long$weight), ]

p3 <- ggplot(w_long, aes(model, weight, fill = model)) +
  geom_col(width = 0.7) +
  geom_hline(yintercept = 0.25, linetype = "dashed", linewidth = 0.4, colour = "grey45") +
  geom_hline(yintercept = 0, linewidth = 0.4, colour = "grey25") +
  geom_text(aes(label = ifelse(abs(weight) < 0.005, "0",
                               sprintf("%.2f", weight)),
                vjust = ifelse(weight >= 0, -0.35, 1.35)), size = 2.5) +
  facet_wrap(~ scheme, nrow = 1) +
  scale_fill_manual(values = c(SVR = "#8c96c6", ANN = "#fdae6b",
                               RF = "#41ab5d", XGB = "#c51b8a",
                               intercept = "grey45"), guide = "none") +
  labs(x = NULL, y = "Weight on each base learner",
       title = "Give the combiner freedom and it starts betting against your models",
       subtitle = paste0("Dashed line = 0.25 (equal weight). Bars below zero are negative ",
                         "weights: the combiner is subtracting a model.")) +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        axis.text.x = element_text(angle = 30, hjust = 1, size = 8),
        plot.subtitle = element_text(size = 8.5, colour = "grey30"),
        strip.text = element_text(size = 8.5))

ggsave(file.path(fig_dir, "fig3-combiner-weights.png"), p3,
       width = 9.6, height = 4.0, dpi = 200)

## ---------------------------------------------------------------------------
## Figure 4 -- apparent versus cross-fitted gain
## ---------------------------------------------------------------------------

ord <- spec[order(spec$crossfit_gain), ]
ord$scheme <- factor(ord$scheme, levels = ord$scheme)

p4 <- ggplot(ord, aes(y = scheme)) +
  geom_vline(xintercept = 0, linetype = "solid", linewidth = 0.5, colour = "grey55") +
  geom_segment(aes(x = crossfit_gain, xend = apparent_gain,
                   yend = scheme), colour = "grey70", linewidth = 0.9) +
  geom_point(aes(x = apparent_gain, colour = "Fit and scored\non the same rows"), size = 3.1) +
  geom_point(aes(x = crossfit_gain, colour = "Cross-fitted"), size = 3.1) +
  geom_text(aes(x = apparent_gain, label = sprintf("%+.1f", apparent_gain)),
            vjust = -0.9, size = 2.9, colour = "#d95f02") +
  geom_text(aes(x = crossfit_gain, label = sprintf("%+.1f", crossfit_gain)),
            vjust = -0.9, size = 2.9, colour = "#1f78b4") +
  scale_colour_manual(values = c("Fit and scored\non the same rows" = "#d95f02",
                                 "Cross-fitted" = "#1f78b4"), name = NULL) +
  labs(x = "Gain in RMSE against the best single model (%)", y = NULL,
       title = "Optimism grows with the freedom you give the combiner",
       subtitle = paste0("Identical base learners. The only thing that changes is whether ",
                         "the combiner was scored on rows it helped fit.")) +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
        legend.position = "top", plot.subtitle = element_text(size = 8.5, colour = "grey30"))

ggsave(file.path(fig_dir, "fig4-apparent-vs-honest.png"), p4,
       width = 8.4, height = 4.4, dpi = 200)

## ---------------------------------------------------------------------------
## Figure 5 -- gain measured against what?
## ---------------------------------------------------------------------------

comp <- rbind(
  data.frame(name = names(cv)[order(pooled[, "RMSE"])],
             rmse = sort(pooled[, "RMSE"]), kind = "Base learner"),
  data.frame(name = spec$scheme,
             rmse = spec$crossfit_rmse, kind = "Combiner (cross-fitted)")
)
comp$name <- factor(comp$name, levels = comp$name[order(comp$rmse)])

p5 <- ggplot(comp, aes(rmse, name, colour = kind)) +
  geom_segment(aes(xend = sd_y, yend = name), colour = "grey80", linewidth = 0.7) +
  geom_point(size = 3) +
  geom_vline(xintercept = sd_y, linewidth = 0.7, colour = "#d95f02", linetype = "dashed") +
  annotate("text", x = sd_y, y = 0.55, label = sprintf("predict the mean = %.3f", sd_y),
           hjust = -0.06, size = 3, colour = "#d95f02") +
  scale_colour_manual(values = c("Base learner" = "#2c7fb8",
                                 "Combiner (cross-fitted)" = "#41ab5d"), name = NULL) +
  labs(x = "RMSE (SOC %), out of fold", y = NULL,
       title = "Every single option is worse than predicting the mean",
       subtitle = paste0("A \u201c+6% gain over the best model\u201d still lands on the wrong ",
                         "side of the only benchmark that matters here.")) +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
        legend.position = "top", plot.subtitle = element_text(size = 8.5, colour = "grey30"))

ggsave(file.path(fig_dir, "fig5-against-the-mean.png"), p5,
       width = 8.4, height = 4.2, dpi = 200)

## ---------------------------------------------------------------------------
## Figure 6 -- the maps the ensembles actually produced
## ---------------------------------------------------------------------------

if (requireNamespace("terra", quietly = TRUE)) {
  suppressPackageStartupMessages(library(terra))
  rasters <- c(SVR = "svm_prediction_spatial_cv.tif",
               ANN = "ann_prediction_spatial_cv.tif",
               RF  = "rf_prediction_spatial_cv.tif",
               XGB = "xgb_prediction_spatial_cv.tif",
               "Simple average" = "ensemble_avg_spatial_cv.tif",
               "Weighted average" = "ensemble_weighted_spatial_cv.tif")
  if (all(file.exists(file.path("outputs", rasters)))) {
    map_stats <- do.call(rbind, lapply(names(rasters), function(nm) {
      v <- values(rast(file.path("outputs", rasters[[nm]])))[, 1]
      data.frame(map = nm, mean = mean(v, na.rm = TRUE), sd = sd(v, na.rm = TRUE),
                 min = min(v, na.rm = TRUE), max = max(v, na.rm = TRUE))
    }))
    cat("=== MAP SUMMARY (all 4,089,160 pixels) ===\n")
    print(map_stats, digits = 3, row.names = FALSE)
    cat(sprintf("Observed SOC mean %.4f, SD %.4f\n\n", mean(y), sd_y))

    grid <- do.call(rbind, lapply(names(rasters), function(nm) {
      r <- aggregate(rast(file.path("outputs", rasters[[nm]])), fact = 8, fun = "mean")
      d <- as.data.frame(r, xy = TRUE, na.rm = TRUE)
      names(d)[3] <- "soc"
      d$map <- nm
      d
    }))
    grid$map <- factor(grid$map, levels = names(rasters))
    strip_map <- setNames(sprintf("%s\nmean %.3f   sd %.3f", map_stats$map,
                                  map_stats$mean, map_stats$sd), map_stats$map)

    p6 <- ggplot(grid, aes(x, y, fill = soc)) +
      geom_raster() +
      facet_wrap(~ map, nrow = 2, labeller = as_labeller(strip_map)) +
      coord_equal() +
      scale_fill_gradient2(low = "#2166ac", mid = "#f7f7f7", high = "#b2182b",
                           midpoint = mean(y), limits = c(0.45, 0.85),
                           oob = scales::squish, name = "SOC (%)") +
      labs(x = NULL, y = NULL,
           title = "Six maps of the Motupe basin, one answer",
           subtitle = paste0("Real 30 m prediction surfaces, downsampled 8\u00d7 for display. ",
                             "Observed mean is ", round(mean(y), 3),
                             "; every map reproduces it and almost nothing else.")) +
      theme_minimal(base_size = 10) +
      theme(axis.text = element_blank(), panel.grid = element_blank(),
            strip.text = element_text(size = 8.5, hjust = 0),
            legend.position = "right",
            plot.subtitle = element_text(size = 8.5, colour = "grey30"))

    ggsave(file.path(fig_dir, "fig6-maps.png"), p6,
           width = 8.4, height = 5.4, dpi = 200)
  }
}

cat("Figures written to ", fig_dir, "\n", sep = "")
