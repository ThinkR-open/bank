#' A Caching object for elasticsearch
#'
#' Create a cache backend with elasticsearch
#'
#' @export
cache_elasticsearch <- R6::R6Class(
  "cache_elasticsearch",
  public = list(
    #' @description
    #' Start a new elasticsearch cache
    #' @param ... passed to `elastic::connect()`
    #' @param cache_table On `initialize()`, the cache object will create a table
    #' to store the cache. Default name is `bankrcache`. Change it if you already
    #' have a table named `bankrcache` in your DB.
    #' @param algo for `{memoise}` compatibility, the `digest()` algorithm
    #' @param compress for `{memoise}` compatibility, should the data be compressed?
    #' @return A cache_elasticsearch object
    initialize = function(...,
                          cache_table = "bankrcache",
                          algo = "sha512",
                          compress = FALSE) {
      if (!requireNamespace("elastic")) {
        stop(
          paste(
            "The {elastic} package has to be installed before using `cache_elasticsearch`.",
            "Please install it first, for example with install.packages('elastic').",
            sep = "\n"
          )
        )
      }
      private$interface <- elastic::connect(...)
      private$algo <- algo
      private$compress <- compress
      private$cache_table <- cache_table
      if (!index_exists(private$interface, private$cache_table)) {
        index_create(
          private$interface,
          private$cache_table,
          body = '{"mappings": {"properties": {"id": {"type":"keyword","doc_values": true}}}}'
        )
      }
    },
    #' @description
    #' Get a key from the cache
    #' @param key Name of the key.
    #' @return The value stored using the `key`
    get = function(key) {
      if (self$has_key(key)) {
        res <- docs_get(
          private$interface,
          private$cache_table,
          key
        )
        unserialize(
          base64enc::base64decode(
            res$`_source`$val
          )
        )
      } else {
        return(
          structure(list(), class = "key_missing")
        )
      }
    },
    #' @description
    #' Set a key in the cache
    #' @param key Name of the key.
    #' @param value Value to store
    #' @return Used for side effect
    set = function(key, value) {
      if (!self$has_key(key)) {
        docs_create(
          private$interface,
          private$cache_table,
          body = list(
            val = base64enc::base64encode(
              serialize(value, NULL)
            ),
            id = key
          ), id = key
        )
      }
    },
    #' @description
    #' Does the cache contains a given key?
    #' @param key Name of the key.
    #' @return TRUE/FALSE
    has_key = function(key) {
      res <- Search(private$interface,
        time_scroll = "1m",
        body = sprintf(
          '{"query": {"match":{"_id" : "%s"}}}',
          key
        )
      )
      length(res$hits$hits) == 1
    },
    #' @description
    #' Clear all the cache
    #' @return Used for side-effect
    reset = function() {
      index_delete(
        private$interface,
        private$cache_table
      )
      index_create(
        private$interface,
        private$cache_table
      )
    },
    #' @description
    #' Remove a key/value pair
    #' @param key Name of the key.
    #' @return Used for side-effect
    remove = function(key) { # index_flush ?
      docs_delete(
        private$interface,
        private$cache_table,
        key
      )
    },
    #' @description
    #' List all the keys in the cache
    #' @return A list of keys
    keys = function() {
      n_key <- Search(
        private$interface,
        body = '{"aggs": {"ids_agg": { "terms": { "field":"id", "size": 1}}},"size": 0}'
      )
      res <- Search(
        private$interface,
        body = sprintf(
          '{"aggs": {"ids_agg": { "terms": { "field":"id", "size": %s} }},"size": 0}',
          n_key$hits$total$value
        )
      )
      vapply(
        res$aggregations$ids_agg$buckets,
        "[[",
        character(1),
        "key"
      )
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
    compress = logical(0),
    cache_table = character(0)
  )
)