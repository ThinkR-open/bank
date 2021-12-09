test_that("cache_redis works", {
  skip_on_ci()
  system("docker run --rm --name mongobankunittest -d -p 27066:27017 -e MONGO_INITDB_ROOT_USERNAME=bebop -e MONGO_INITDB_ROOT_PASSWORD=aloula mongo:3.4")
  Sys.sleep(10)

  mongo_cache <- cache_mongo$new(
    db = "bank",
    url = "mongodb://bebop:aloula@localhost:27066",
    prefix = "sn"
  )

  test_them_all(
    cache = mongo_cache
  )

  system("docker kill mongobankunittest")
})