# ensemble_blog_extras.R
#
# Companion to codes/ensemble_blog_figures.R. It answers the question
# "are there other combination options we did not even list?"
#
# It fits fourteen combiners on exactly the same out-of-fold matrix used in the
# post, and scores every one of them twice:
#   apparent     -- fitted and scored on the same 109 rows (optimistic)
#   cross-fitted -- weights fitted on 4 spatial folds, scored on the 5th
#
# Run from the repository root:
#   Rscript codes/ensemble_blog_extras.R
#
# Everything printed here is quoted in the post. Nothing is hand-entered.

suppressPackageStartupMessages({
  library(quadprog)
  library(quantreg)
  library(nnet)
})

fig_dir <- "figures/2026-08-29-should-you-combine"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

## ---------------------------------------------------------------------------
## 0. The same out-of-fold matrix the post uses
## ---------------------------------------------------------------------------

files <- c(SVR = "svm_cv_predictions.csv", ANN = "ann_cv_predictions.csv",
           RF  = "rf_cv_predictions.csv",  XGB = "xgb_cv_predictions.csv")

cv   <- lapply(files, function(f) read.csv(file.path("outputs", f)))
y    <- cv[[1]]$observed
fold <- cv[[1]]$fold
Z    <- sapply(cv, function(x) x$predicted)
colnames(Z) <- names(files)

n <- length(y)
L <- ncol(Z)
k <- sort(unique(fold))

# metrics take their truth explicitly: the combiners below are fitted on subsets
rmse_v <- function(p, truth = y) sqrt(mean((p - truth)^2))
mae_v  <- function(p, truth = y) mean(abs(p - truth))
r2_v   <- function(p, truth = y) 1 - sum((p - truth)^2) / sum((truth - mean(truth))^2)

sd_y      <- sd(y)
mean_rmse <- rmse_v(y, rep(mean(y), n))
best_rmse <- min(apply(Z, 2, rmse_v))

cat("=== REFERENCE POINTS ===\n")
cat(sprintf("n = %d, %d folds, sd(y) = %.4f, predict-the-mean RMSE = %.4f\n",
            n, length(k), sd_y, mean_rmse))
cat(sprintf("Best single model: %s at %.4f\n\n",
            colnames(Z)[which.min(apply(Z, 2, rmse_v))], best_rmse))

## ---------------------------------------------------------------------------
## 1. Combiners, one interface: fit(Zi, yi) -> function(Znew) -> predictions
## ---------------------------------------------------------------------------

# --- order statistics: not a weight vector, just arithmetic on the members ----
c_equal <- function(Zi, yi) function(Znew) rowMeans(Znew)

c_median <- function(Zi, yi) function(Znew) apply(Znew, 1, median)

c_trimmed <- function(Zi, yi) {          # L = 4: drop the min and the max,
  function(Znew) apply(Znew, 1, function(v) mean(sort(v)[2:(length(v) - 1)]))
}

c_bestsingle <- function(Zi, yi) {        # picked on the fitting rows only
  j <- which.min(apply(Zi, 2, rmse_v, truth = yi))
  function(Znew) Znew[, j]
}

# --- score-based: each model's own accuracy, no covariance -------------------
c_r2weighted <- function(Zi, yi) {
  r <- sapply(seq_len(ncol(Zi)), function(j) max(0.1, r2_v(Zi[, j], yi)))
  w <- r / sum(r)
  function(Znew) as.vector(Znew %*% w)
}

# --- covariance and least squares, unconstrained ------------------------------
c_bates_granger <- function(Zi, yi) {
  S <- cov(Zi - yi)
  o <- rep(1, ncol(Zi))
  w <- tryCatch(as.vector(solve(S, o) / as.numeric(t(o) %*% solve(S, o))),
                error = function(e) rep(1 / ncol(Zi), ncol(Zi)))
  function(Znew) as.vector(Znew %*% w)
}

c_gr <- function(Zi, yi) {                # Granger-Ramanathan: free sign, intercept
  b <- coef(lm(yi ~ Zi))
  function(Znew) as.vector(cbind(1, Znew) %*% b)
}

c_ridge <- function(Zi, yi) {
  f <- MASS::lm.ridge(yi ~ Zi, lambda = c(0, 10^seq(-3, 3, length = 60)))
  b <- as.numeric(coef(f)[which.min(f$GCV), ])
  function(Znew) as.vector(cbind(1, Znew) %*% b)
}

c_lad <- function(Zi, yi) {               # least absolute deviations, not squares
  b <- coef(quantreg::rq(yi ~ Zi))
  function(Znew) as.vector(cbind(1, Znew) %*% b)
}

# --- convex: weights non-negative, sum to one --------------------------------
c_nnls <- function(Zi, yi) {
  D <- t(Zi) %*% Zi; d <- t(Zi) %*% yi
  w <- solve.QP(Dmat = D + diag(1e-10, ncol(Zi)), dvec = d,
                Amat = cbind(rep(1, ncol(Zi)), diag(ncol(Zi))),
                bvec = c(1, rep(0, ncol(Zi))), meq = 1)$solution
  function(Znew) as.vector(Znew %*% w)
}

# --- non-negative weights, free intercept, sum NOT constrained ---------------
c_nnls_intercept <- function(Zi, yi) {
  Zm <- sweep(Zi, 2, colMeans(Zi)); ym <- yi - mean(yi)
  D <- t(Zm) %*% Zm; d <- t(Zm) %*% ym
  w <- solve.QP(Dmat = D + diag(1e-10, ncol(Zi)), dvec = d,
                Amat = diag(ncol(Zi)), bvec = rep(0, ncol(Zi)), meq = 0)$solution
  b <- mean(yi) - as.vector(colMeans(Zi) %*% w)
  function(Znew) as.vector(Znew %*% w + b)
}

# --- greedy ensemble selection with replacement (Caruana et al., 2004) ------
hill_climb_weights <- function(Zi, yi, iters = 200) {
  Lz <- ncol(Zi)
  counts <- rep(0, Lz)
  best <- Inf
  for (it in seq_len(iters)) {
    cand <- vapply(seq_len(Lz), function(j) {
      cc <- counts; cc[j] <- cc[j] + 1
      rmse_v(as.vector(Zi %*% (cc / sum(cc))), yi)
    }, numeric(1))
    j <- which.min(cand)
    if (cand[j] > best - 1e-8) break
    best <- cand[j]; counts[j] <- counts[j] + 1
  }
  counts / sum(counts)
}

c_hillclimb <- function(Zi, yi) {
  w <- hill_climb_weights(Zi, yi)
  function(Znew) as.vector(Znew %*% w)
}

# --- non-parametric and neural meta-learners --------------------------------
c_knn <- function(Zi, yi, kk = 10) {
  function(Znew) {
    d <- as.matrix(dist(rbind(Zi, Znew)))
    d <- d[nrow(Zi) + seq_len(nrow(Znew)), seq_len(nrow(Zi)), drop = FALSE]
    apply(d, 1, function(row) {
      nn <- order(row)[seq_len(kk)]
      w <- 1 / pmax(row[nn], 1e-8)
      sum(w * yi[nn]) / sum(w)
    })
  }
}

c_mlp <- function(Zi, yi) {
  set.seed(1)                            # nnet starts from random weights
  sc <- scale(Zi)
  fit <- nnet::nnet(x = sc, y = yi, size = 2, decay = 0.1, linout = TRUE,
                    maxit = 600, trace = FALSE, MaxNWts = 200)
  mu <- attr(sc, "scaled:center"); sg <- attr(sc, "scaled:scale")
  function(Znew) as.vector(predict(fit, sweep(sweep(Znew, 2, mu), 2, sg, "/")))
}

## ---------------------------------------------------------------------------
## 2. Fit every combiner on all rows (apparent), then on 4/5 of the folds
## ---------------------------------------------------------------------------

combiners <- list(
  "Simple average"              = c_equal,
  "R2-weighted (0.1 floor)"     = c_r2weighted,
  "Median of members"           = c_median,
  "Trimmed mean (drop min/max)" = c_trimmed,
  "Best single model"           = c_bestsingle,
  "Bates-Granger"               = c_bates_granger,
  "NNLS (convex)"               = c_nnls,
  "NNLS + free intercept"       = c_nnls_intercept,
  "Hill-climbing (Caruana)"     = c_hillclimb,
  "Ridge meta (GCV)"            = c_ridge,
  "Granger-Ramanathan"          = c_gr,
  "LAD meta (quantile reg.)"    = c_lad,
  "kNN meta (k = 10)"           = c_knn,
  "MLP meta (2 hidden units)"   = c_mlp
)

free_par <- c("Simple average" = 0, "R2-weighted (0.1 floor)" = 0,
              "Median of members" = 0, "Trimmed mean (drop min/max)" = 0,
              "Best single model" = 1, "Bates-Granger" = L - 1,
              "NNLS (convex)" = L - 1, "NNLS + free intercept" = L,
              "Hill-climbing (Caruana)" = L - 1, "Ridge meta (GCV)" = L + 1,
              "Granger-Ramanathan" = L + 1, "LAD meta (quantile reg.)" = L + 1,
              "kNN meta (k = 10)" = n,          # it stores every training row
              "MLP meta (2 hidden units)" = 2 * L + 3)

set.seed(2026)
rows <- lapply(names(combiners), function(s) {
  f <- combiners[[s]]
  pred_apparent <- f(Z, y)(Z)

  pred_crossfit <- numeric(n)
  for (g in k) {
    out <- which(fold == g); inn <- which(fold != g)
    f_in <- f(Z[inn, , drop = FALSE], y[inn])
    pred_crossfit[out] <- f_in(Z[out, , drop = FALSE])
  }

  data.frame(scheme        = s,
             free_par      = free_par[[s]],
             apparent_rmse = rmse_v(pred_apparent),
             crossfit_rmse = rmse_v(pred_crossfit),
             crossfit_mae  = mae_v(pred_crossfit),
             crossfit_r2   = r2_v(pred_crossfit),
             apparent_gain = 100 * (1 - rmse_v(pred_apparent) / best_rmse),
             crossfit_gain = 100 * (1 - rmse_v(pred_crossfit) / best_rmse))
})
spec <- do.call(rbind, rows)
spec$optimism_pp <- spec$apparent_gain - spec$crossfit_gain
spec <- spec[order(spec$free_par, spec$crossfit_rmse), ]

cat("=== FOURTEEN COMBINERS, SAME MATRIX, SAME FOLDS ===\n")
print(spec[, c("scheme", "free_par", "apparent_gain", "crossfit_gain",
               "optimism_pp", "crossfit_r2")], digits = 3, row.names = FALSE)

cat(sprintf("\nPredict-the-mean RMSE = %.4f. Best single model = %.4f.\n",
            mean_rmse, best_rmse))
cat(sprintf("Combiners that beat the mean baseline out of fold: %d of %d\n",
            sum(spec$crossfit_rmse < mean_rmse), nrow(spec)))
cat(sprintf("Mean optimism: %.1f pp, worst: %s at %.1f pp\n\n",
            mean(spec$optimism_pp), spec$scheme[which.max(spec$optimism_pp)],
            max(spec$optimism_pp)))

## ---------------------------------------------------------------------------
## 3. Do the coefficients of the flexible meta-learners say anything sane?
## ---------------------------------------------------------------------------

cat("=== WHAT THE FLEXIBLE META-LEARNERS USED ===\n")
cat("Hill-climbing weights (fit on all rows):\n")
print(round(setNames(hill_climb_weights(Z, y), colnames(Z)), 3))

cat("\nLAD meta coefficients (quantile regression, tau = 0.5):\n")
print(round(coef(quantreg::rq(y ~ Z)), 3))

cat("\nMLP meta: 2 hidden units fitted on 109 rows.\n")

cat("\nWith four members, the trimmed mean and the median are the same estimator:\n")
cat(sprintf("  max |trimmed mean - median| = %.2e\n",
            max(abs(c_trimmed(Z, y)(Z) - c_median(Z, y)(Z)))))

cat(sprintf(
  "\nkNN apparent RMSE = %.2e: with the row itself among its own neighbours\n",
  rmse_v(c_knn(Z, y)(Z))))
cat("every training point is predicted by itself. That column is not a result.\n\n")

## ---------------------------------------------------------------------------
## 4. Local (zone-varying) weights: one convex combiner per basin sector
## ---------------------------------------------------------------------------

# Northing runs from the lower dry-forest sector to the upper Andean grassland,
# so terciles of Y are a crude but honest "different rule per zone" test.
coords <- read.csv("data/soil_motupe_table.csv")[, c("X", "Y")]
stopifnot(nrow(coords) == n)
zone <- cut(coords$Y, quantile(coords$Y, c(0, 1/3, 2/3, 1)),
            labels = c("lower", "middle", "upper"), include.lowest = TRUE)

local_predict <- function(inner, outer) {
  out <- numeric(length(outer))
  for (z in levels(zone)) {
    itr <- inner[zone[inner] == z]
    pos <- which(zone[outer] == z)
    if (length(itr) < 10 || !length(pos)) next
    f <- c_nnls(Z[itr, , drop = FALSE], y[itr])
    out[pos] <- f(Z[outer[pos], , drop = FALSE])
  }
  out
}

pred_local <- numeric(n)
for (g in k) {
  out <- which(fold == g); inn <- which(fold != g)
  pred_local[out] <- local_predict(inn, out)
}

cat("=== LOCAL WEIGHTS (one NNLS combiner per northing tercile) ===\n")
cat(sprintf("RMSE %.4f, gain vs best single model %+.1f%%, R2 %.3f\n",
            rmse_v(pred_local), 100 * (1 - rmse_v(pred_local) / best_rmse),
            r2_v(pred_local)))
cat(sprintf("Samples per zone: %s\n",
            paste(sprintf("%s %d", levels(zone), as.integer(table(zone))), collapse = ", ")))
cat("\n")

## ---------------------------------------------------------------------------
## 5. Figure 7 -- the whole menu, all scored out of fold
## ---------------------------------------------------------------------------

if (requireNamespace("ggplot2", quietly = TRUE)) {
  suppressPackageStartupMessages(library(ggplot2))

  comp <- rbind(
    data.frame(name = spec$scheme, rmse = spec$crossfit_rmse,
               kind = "Combiner (cross-fitted)"),
    data.frame(name = colnames(Z), rmse = apply(Z, 2, rmse_v),
               kind = "Base learner"),
    data.frame(name = "Predict the mean", rmse = mean_rmse, kind = "Baseline")
  )
  comp <- comp[order(comp$rmse), ]
  comp$name <- factor(comp$name, levels = comp$name)

  p7 <- ggplot(comp, aes(rmse, name, colour = kind)) +
    geom_segment(aes(xend = mean_rmse, yend = name), colour = "grey85", linewidth = 0.6) +
    geom_point(size = 2.7) +
    geom_vline(xintercept = mean_rmse, linetype = "dashed", linewidth = 0.6,
               colour = "#d95f02") +
    scale_colour_manual(values = c("Base learner" = "#2c7fb8",
                                   "Combiner (cross-fitted)" = "#41ab5d",
                                   "Baseline" = "#d95f02"), name = NULL) +
    labs(x = "RMSE (SOC %), out of fold", y = NULL,
         title = "Fourteen combiners, one benchmark, no winner",
         subtitle = paste0("Every scheme in the extended menu, scored on folds it ",
                           "did not help fit. Dashed line = predict the mean.")) +
    theme_minimal(base_size = 10) +
    theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
          legend.position = "top",
          plot.subtitle = element_text(size = 8.5, colour = "grey30"))

  ggsave(file.path(fig_dir, "fig7-extended-menu.png"), p7,
         width = 8.8, height = 6.0, dpi = 200)
  cat("Figure written: ", file.path(fig_dir, "fig7-extended-menu.png"), "\n", sep = "")
}

cat("Done.\n")
