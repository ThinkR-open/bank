test_that("cache_redis works", {
  skip_on_ci()
  skip_if_not_installed("redux")
  if (Sys.which("docker") == "") skip("docker not available")
  system("docker run --rm --name redisbankunittest -d -p 6379:6379 redis:5.0.5 --requirepass bebopalula")
  Sys.sleep(10)

  redis_cache <- cache_redis$new(password = "bebopalula")

  test_them_all(
    cache = redis_cache
  )


})