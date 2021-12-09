test_that("cache_postgres works", {
  skip_on_ci()
  system("docker run --rm --name postgresbankunittest -e POSTGRES_PASSWORD=mysecretpassword -d -p 5434:5432 postgres")
  Sys.sleep(10)

  postgres_cache <- cache_postgres$new(
    dbname = "postgres",
    host = "localhost",
    port = 5434,
    user = "postgres",
    password = "mysecretpassword"
  )

  test_them_all(
    cache = postgres_cache
  )

  system("docker kill postgresbankunittest")
})