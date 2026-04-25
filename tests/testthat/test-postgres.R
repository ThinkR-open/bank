test_that("cache_postgres works", {
  skip_on_ci()
  skip_if_not_installed("RPostgres")
  skip_if_not_installed("DBI")
  if (Sys.which("docker") == "") skip("docker not available")
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

})