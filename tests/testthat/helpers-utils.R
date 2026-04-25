test_them_all <- function(cache_obj) {
  f <- function(x) {
    sample(1:1000, x)
  }

  mf <- memoise::memoise(f, cache = cache_obj)
  expect_equal(
    mf(5),
    mf(5)
  )
  kys <- cache_obj$keys()
  expect_true(
    length(kys) > 0
  )
  kys <- kys[1]
  expect_true(
    cache_obj$has_key(kys)
  )

  expect_equal(
    cache_obj$get(kys)$value,
    mf(5)
  )
  mf(6)
  kys <- cache_obj$keys()
  expect_true(
    length(kys) > 1
  )
  old_key <- kys[1]
  rm <- cache_obj$remove(old_key)
  if (
    inherits(cache_obj, "cache_postgres")
  ) {
    expect_equal(
      rm,
      1
    )
  }

  kys <- cache_obj$keys()
  expect_true(
    length(kys) > 0
  )
  expect_false(
    old_key %in% kys
  )

  kys <- kys[1]
  expect_true(
    cache_obj$has_key(kys)
  )
  expect_false(
    cache_obj$has_key(old_key)
  )
}

# Optional backend deps. They are only useful for the docker-backed
# integration tests (Redis / Mongo / Postgres). Failure to install them
# (e.g. on a sandbox without a compiler or repo access) must not crash the
# whole test run — cache_sqlite is a pure-R backend that needs none of
# them, and individual tests already skip_if_not_installed().
maybe_install <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    tryCatch(
      install.packages(pkg),
      error = function(e) message("Could not install ", pkg, ": ", conditionMessage(e)),
      warning = function(w) message("Could not install ", pkg, ": ", conditionMessage(w))
    )
  }
}
maybe_install("redux")
maybe_install("mongolite")
maybe_install("DBI")
maybe_install("RPostgres")

withr::defer(
  {
    system("docker kill mongobankunittest")
    system("docker kill postgresbankunittest")
    system("docker kill redisbankunittest")
  },
  envir = testthat::teardown_env()
)