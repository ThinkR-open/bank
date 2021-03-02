#' @export
cache_redis <- R6::R6Class(
  "cache_redis",
  public = list(
    initialize = function(
      ...,
      version = NULL,
      algo = "sha512",
      compress = FALSE
    ){
      if (!requireNamespace("redux")){
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
    get = function(key) {
      res <- private$interface$GET(key)
      if (is.null(res)){
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
    set = function(key, value) {
      private$interface$SET(
        key,
        redux::object_to_bin(value)
      )
    },
    has_key = function(key) {
      private$interface$EXISTS(key)
    },
    reset = function() {
      private$interface$FLUSHALL()
    },
    remove = function(key) {
      private$interface$DEL(key)
    },
    keys = function() {
      unlist(private$interface$KEYS("*"))
    },
    # For compatibily with {memoise}
    digest = function(...) digest::digest(..., algo = private$algo)
  ),
  private = list(
    interface = list(),
    algo = character(0),
    compress = logical(0)
  )
)

