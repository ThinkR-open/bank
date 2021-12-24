test_that("cache_elasticsearch works", {
  skip_on_ci()
  system(
    "docker run --rm --name elasticbankunittest -d -p 9201:9200 -e discovery.type=single-node elasticsearch:7.10.1"
  )
  Sys.sleep(10)

  private <- list()
  private$interface <- connect(port = 9201)
  purrr::insistently(
    private$interface$ping,
    purrr::rate_delay(5)
  )()

  cache_obj <- cache_elasticsearch$new(
    port = 9201
  )

  test_them_all(
    cache_obj = cache_obj
  )

  system("docker kill elasticbankunittest")
})