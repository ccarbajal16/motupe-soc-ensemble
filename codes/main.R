# main.R

# Source the modules in the correct order
source("modules/01_setup_and_load.R")
source("modules/02_preprocessing.R")
source("modules/03_model_definition.R")
source("modules/04_spatial_cv.R")
source("modules/05_ensemble.R")
source("modules/06_prediction.R")
source("modules/07_uncertainty.R")
source("modules/08_evaluation_and_report.R")

# Cleanup parallel processing (if still running)
if (exists("cl") && !is.null(cl)) {
  tryCatch({
    stopCluster(cl)
    registerDoSEQ()
    cat("\nParallel processing cleanup completed\n")
  }, error = function(e) {
    cat("\nNote: Parallel cluster was already stopped\n")
  })
}

# Print completion message
cat("\n=== ANALYSIS COMPLETE ===")
