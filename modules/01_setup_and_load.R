# 01_setup_and_load.R

# 1.1. Load packages
library(sf)
library(terra)
library(mlr3)
library(mlr3verse)
library(mlr3spatiotempcv)
library(mlr3viz)
library(mlr3fselect)
library(mlr3filters)
library(mlr3tuning)
library(mlr3learners)
library(mlr3extralearners)
library(keras)
library(e1071)
library(ranger)
library(xgboost)
library(ggplot2)
library(gstat)
library(automap)
library(dplyr)
library(tidyr)
library(nnet)
library(foreach)
library(doParallel)
library(parallel)

# Install missing packages if needed
required_packages <- c("mlr3extralearners", "e1071", "nnet", "tidyr", "foreach", "doParallel")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

# Setup parallel processing
n_cores <- min(detectCores() - 1, 8) # Use max 8 cores, leave 1 for system
cat("Setting up parallel processing with", n_cores, "cores\n")
cl <- makeCluster(n_cores)
registerDoParallel(cl)
