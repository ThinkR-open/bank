test_that("cache_sqlite works end-to-end in-memory", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("memoise")

  sqlite_cache <- cache_sqlite$new(dbname = ":memory:")

  expect_true(inherits(sqlite_cache, "cache_sqlite"))
  expect_length(sqlite_cache$keys(), 0L)

  sqlite_cache$set("hello", list(value = 42))
  expect_true(sqlite_cache$has_key("hello"))
  expect_equal(sqlite_cache$get("hello"), list(value = 42))

  sqlite_cache$set("world", "abc")
  expect_setequal(sqlite_cache$keys(), c("hello", "world"))

  sqlite_cache$remove("hello")
  expect_false(sqlite_cache$has_key("hello"))

  sqlite_cache$reset()
  expect_length(sqlite_cache$keys(), 0L)
})

test_that("cache_sqlite is compatible with {memoise}", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("memoise")

  sqlite_cache <- cache_sqlite$new(dbname = ":memory:")
  f <- function(x) sample(1:1000, x)
  mf <- memoise::memoise(f, cache = sqlite_cache)
  expect_equal(mf(5), mf(5))
  expect_true(length(sqlite_cache$keys()) >= 1L)
})

test_that("missing key returns a key_missing sentinel", {
  skip_if_not_installed("RSQLite")

  sqlite_cache <- cache_sqlite$new(dbname = ":memory:")
  res <- sqlite_cache$get("nope")
  expect_s3_class(res, "key_missing")
})

test_that("set() overwrites an existing key", {
  skip_if_not_installed("RSQLite")

  sqlite_cache <- cache_sqlite$new(dbname = ":memory:")
  sqlite_cache$set("k", "first")
  sqlite_cache$set("k", "second")
  expect_equal(sqlite_cache$get("k"), "second")
  expect_length(sqlite_cache$keys(), 1L)
})

test_that("opening an existing table with a foreign schema errors clearly", {
  skip_if_not_installed("RSQLite")
  skip_if_not_installed("DBI")

  path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(path), add = TRUE)
  con <- DBI::dbConnect(RSQLite::SQLite(), dbname = path)
  DBI::dbExecute(con, "CREATE TABLE bankrcache (foo TEXT, bar TEXT);")
  DBI::dbDisconnect(con)

  expect_error(
    cache_sqlite$new(dbname = path),
    regexp = "does not match the cache schema"
  )
})

test_that("file-backed sqlite cache persists across sessions", {
  skip_if_not_installed("RSQLite")

  path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(path), add = TRUE)

  c1 <- cache_sqlite$new(dbname = path)
  c1$set("alpha", list(x = 1L, y = 2L))
  rm(c1)
  gc()

  c2 <- cache_sqlite$new(dbname = path)
  expect_true(c2$has_key("alpha"))
  expect_equal(c2$get("alpha"), list(x = 1L, y = 2L))
})
