#' A Caching object for postgres
#'
#' Create a cache backend with redis
#'
#' @export
cache_postgres <- R6::R6Class(
  "cache_postgres",
  public = list(
    #' @description
    #' Start a new redis cache
    #' @param ... Parameters passes do DBI::dbConnect(RPostgres::Postgres(), ...)
    #' @param cache_table On `initialize()`, the cache object will create a table
    #' to store the cache. Default name is `bankrcache`. Change it if you already
    #' have a table named `bankrcache` in your DB.
    #' @param algo for `{memoise}` compatibility, the `digest()` algorithm
    #' @param compress for `{memoise}` compatibility, should the data be compressed?
    #' @return A cache_postgres object
    initialize = function(...,
                          cache_table = "bankrcache",
                          algo = "sha512",
                          compress = FALSE) {
      if (!requireNamespace("RPostgres")) {
        stop(
          paste(
            "The {RPostgres} package has to be installed before using `cache_postgres`.",
            "Please install it first, for example with install.packages('RPostgres').",
            sep = "\n"
          )
        )
      }
      if (!requireNamespace("DBI")) {
        stop(
          paste(
            "The {DBI} package has to be installed before using `cache_redis`.",
            "Please install it first, for example with install.packages('DBI').",
            sep = "\n"
          )
        )
      }
      private$interface <- DBI::dbConnect(
        RPostgres::Postgres(),
        ...
      )

      private$cache_table <- cache_table

      if (
        cache_table %in% DBI::dbListTables(private$interface)
      ) {
        res <- DBI::dbGetQuery(
          private$interface,
          sprintf(
            "SELECT COLUMN_NAME ,DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '%s';",
            cache_table
          )
        )
        names(res) <- tolower(names(res))
        attempt::stop_if_not(
          nrow(res) == 2,
          msg = "Your cache_table your only have two column"
        )
        attempt::stop_if_not(
          all(c("cache", "id") %in% res$column_name),
          msg = "Your cache_db should have a `cache` and an `id` column."
        )
        attempt::stop_if_not(
          all(c("character varying", "bytea") %in% res$data_type),
          msg = "Your cache_table data types should be `bytea` and `character varying`."
        )
      } else {
        DBI::dbCreateTable(
          private$interface,
          cache_table,
          fields = c(
            id = "VARCHAR",
            cache = "BYTEA"
          )
        )
      }

      private$algo <- algo
      private$compress <- compress
    },
    #' @description
    #' Does the cache contains a given key?
    #' @param key Name of the key.
    #' @return TRUE/FALSE
    has_key = function(key) {
      res <- DBI::dbGetQuery(
        private$interface,
        sprintf(
          "SELECT id FROM %s WHERE id = '%s';",
          private$cache_table,
          key
        )
      )
      if (nrow(res) > 1) {
        stop("Corrupted cache: more than one entry for ", key)
      }
      nrow(res) == 1
    },
    #' @description
    #' Get a key from the cache
    #' @param key Name of the key.
    #' @return The value stored using the `key`
    # Inspied by @jrosell https://stackoverflow.com/a/70288183/8236642
    get = function(key) {
      if (self$has_key(key)) {
        tmp <- tempfile(fileext = ".RDS")
        on.exit({
          unlink(tmp, TRUE, TRUE)
        })
        out <- DBI::dbGetQuery(
          private$interface,
          sprintf(
            "SELECT * FROM %s WHERE id = '%s';",
            private$cache_table,
            key
          )
        )

        # Handling the case where the value has been deleted in-between
        # (should be very, very corner case)
        res <- tryCatch(
          {
            unserialized_out <- unserialize(out$cache[[1]])
            writeBin(object = unserialized_out, con = tmp)
            readRDS(tmp)
          },
          error = function(e) {
            return(NULL)
          }
        )
        if (is.null(res)) {
          return(
            structure(list(), class = "key_missing")
          )
        }
        return(
          res
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
        temp_file <- tempfile(fileext = ".RDS")
        saveRDS(value, file = temp_file)
        pdf <- readBin(con = temp_file, what = raw(), n = file.info(temp_file)$size)
        pdf_serialized <- serialize(pdf, NULL)

        DBI::dbWriteTable(
          private$interface,
          private$cache_table,
          data.frame(
            id = key,
            cache = I(list(pdf_serialized))
          ),
          append = TRUE
        )
      }
    },
    #' @description
    #' Clear all the cache
    #' @return Used for side-effect
    reset = function() {
      DBI::dbRemoveTable(
        private$interface,
        private$cache_table
      )
      DBI::dbCreateTable(
        private$interface,
        private$cache_table,
        fields = c(
          id = "VARCHAR",
          cache = "BYTEA"
        )
      )
    },
    #' @description
    #' Remove a key/value pair
    #' @param key Name of the key.
    #' @return Used for side-effect
    remove = function(key) {
      DBI::dbGetQuery(
        private$interface,
        sprintf(
          "DELETE FROM %s WHERE id = '%s';",
          private$cache_table,
          key
        )
      )
    },
    #' @description
    #' List all the keys in the cache
    #' @return A list of keys
    keys = function() {
      DBI::dbGetQuery(
        private$interface,
        sprintf(
          "SELECT id FROM %s",
          private$cache_table
        )
      )$id
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
    cache_table = character(0),
    algo = character(0),
    compress = logical(0)
  )
)