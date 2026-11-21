# Runs every test in tests/testthat.
# From the project root: Rscript tests/testthat.R
# In RStudio, with the project open: source("tests/testthat.R")
testthat::test_dir("tests/testthat", stop_on_failure = TRUE)
