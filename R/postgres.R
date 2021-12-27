#' A Caching object for Postgres
#'
#' Create a cache backend with Postgres
#'
#' @export
cache_postgres <- R6::R6Class(
  "cache_postgres",
  public = list(
    #' @description
    #' Start a new Postgres cache
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

      private$check_dependencies("cache_postgres", "RPostgres")

      private$interface <- private$connect(RPostgres::Postgres(), ...)
      
      private$cache_table <- cache_table

      private$check_table()

      private$algo <- algo

      private$compress <- compress
    },
    #' @description
    #' Closes the connection
    #' @return TRUE, invisibly.
    finalize = function() {
      DBI::dbDisconnect(private$interface)
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
      private$create_table()
    },
    #' @description
    #' Remove a key/value pair
    #' @param key Name of the key.
    #' @return Used for side-effect
    remove = function(key) {
      DBI::dbExecute(
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
    check_dependencies = function(class_name = character(),
                                  packages = character()) {

      needed_packages <- c("DBI", packages)

      stopper <- function(package) {

        if( !requireNamespace(package) ) {
          stop(
            paste0(
              "The {", package, "} package has to be installed before using `",
              class_name, "`. Please install it first, for example with
              install.packages('", package, "')."
            ),
            call. = FALSE
          )
        }

      }

      lapply(needed_packages, FUN = stopper)

    },
    connect = function(...) {
      DBI::dbConnect(...)
    },
    sql_column_data = list(
      column_id = list(type = "VARCHAR", type_description = "character varying"),
      column_cache = list(type = "BYTEA", type_description = "bytea")
    ),
    check_table = function() {
      if (
        private$cache_table %in% DBI::dbListTables(private$interface)
      ) {
        res <- DBI::dbGetQuery(
          private$interface,
          sprintf(
            "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '%s';",
            private$cache_table
          )
        )
        names(res) <- tolower(names(res))
        attempt::stop_if_not(
          nrow(res) == 2,
          msg = "Your cache_table should have only two columns"
        )
        attempt::stop_if_not(
          all(c("cache", "id") %in% res$column_name),
          msg = "Your cache_db should have a `cache` and an `id` column."
        )
        attempt::stop_if_not(
          all(c(private$sql_column_data$column_id$type_description,
                private$sql_column_data$column_cache$type_description) %in%
                res$data_type),
          msg = paste0("Your cache_table data types should be `",
                       private$sql_column_data$column_id$type_description,
                       "` and `",
                       private$sql_column_data$column_cache$type_description,
                       ".")
        )
      } else {
        private$create_table()
      }
    },
    create_table = function() {
      DBI::dbCreateTable(
        private$interface,
        private$cache_table,
        fields = c(
          id = private$sql_column_data$column_id$type,
          cache = private$sql_column_data$column_cache$type
        )
      )
    },
    interface = list(0),
    cache_table = character(0),
    algo = character(0),
    compress = logical(0)
  )
)
