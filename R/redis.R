#' A Caching object for redis
#'
#' Create a cache backend with redis
#'
#' @export
cache_redis <- R6::R6Class(
  "cache_redis",
  public = list(
    #' @description
    #' Start a new redis cache
    #' @param ... Named configuration options passed to
    #'  redis_config, used to create the environment
    #'  (notable keys include host, port, and the
    #'  environment variable REDIS_URL).
    #'  For redis_available, arguments are passed
    #'  through to hiredis.
    #' @param version Version of the interface to generate.
    #' If given as a string to numeric version,
    #' then only commands that exist up to that
    #' version will be included. If given as TRUE,
    #' then we will query the Redis server (with INFO)
    #'  and extract the version number that way.
    #' @param algo for `{memoise}` compatibility, the `digest()` algorithm
    #' @param compress for `{memoise}` compatibility, should the data be compressed?
    #' @return A cache_redis object
    initialize = function(...,
                          version = NULL,
                          algo = "sha512",
                          compress = FALSE) {
      if (!requireNamespace("redux")) {
        stop(
          paste(
            "The {redux} package has to be installed before using `cache_redis`.",
            "Please install it first, for example with install.packages('redux').",
            sep = "\n"
          )
        )
      }
      private$interface <- redux::hiredis(
        ...,
        version = NULL
      )
      private$algo <- algo
      private$compress <- compress
    },
    #' @description
    #' Get a key from the cache
    #' @param key Name of the key.
    #' @return The value stored using the `key`
    get = function(key) {
      res <- private$interface$GET(key)
      if (is.null(res)) {
        return(
          structure(list(), class = "key_missing")
        )
      }
      return(
        redux::bin_to_object(
          res
        )
      )
    },
    #' @description
    #' Set a key in the cache
    #' @param key Name of the key.
    #' @param value Value to store
    #' @return Used for side effect
    set = function(key, value) {
      private$interface$SET(
        key,
        redux::object_to_bin(value)
      )
    },
    #' @description
    #' Does the cache contains a given key?
    #' @param key Name of the key.
    #' @return TRUE/FALSE
    has_key = function(key) {
      as.logical(private$interface$EXISTS(key))
    },
    #' @description
    #' Clear all the cache
    #' @return Used for side-effect
    reset = function() {
      private$interface$FLUSHALL()
    },
    #' @description
    #' Remove a key/value pair
    #' @param key Name of the key.
    #' @return Used for side-effect
    remove = function(key) {
      private$interface$DEL(key)
    },
    #' @description
    #' List all the keys in the cache
    #' @return A list of keys
    keys = function() {
      unlist(private$interface$KEYS("*"))
    },
    #' @description
    #' Function that runs an hash algo.
    #' For compatibily with `{memoise}`
    #' @param ... the value to hash
    #' @return A function
    digest = function(...) digest::digest(..., algo = private$algo)
  ),
  private = list(
    interface = list(),
    algo = character(0),
    compress = logical(0)
  )
)