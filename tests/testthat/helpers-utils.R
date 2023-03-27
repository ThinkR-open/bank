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

if (!requireNamespace("redux", quietly = TRUE)) {
  install.packages("redux")
}
if (!requireNamespace("mongolite", quietly = TRUE)) {
  install.packages("mongolite")
}
if (!requireNamespace("DBI", quietly = TRUE)) {
  install.packages("DBI")
}
if (!requireNamespace("RPostgres", quietly = TRUE)) {
  install.packages("RPostgres")
}

withr::defer(
  {
    system("docker kill mongobankunittest")
    system("docker kill postgresbankunittest")
    system("docker kill redisbankunittest")
  },
  envir = testthat::teardown_env()
)