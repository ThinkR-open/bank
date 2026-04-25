#' A caching object backed by SQLite
#'
#' Create a cache backend stored in a SQLite database. This is the most
#' lightweight SQL-backed cache offered by `{bank}` — it only needs `{DBI}`
#' and `{RSQLite}` and supports an in-memory database (`dbname = ":memory:"`),
#' which makes it ideal for unit tests and short-lived sessions (#1).
#'
#' @export
#' @importFrom R6 R6Class
#' @importFrom digest digest
cache_sqlite <- R6::R6Class(
  "cache_sqlite",
  public = list(
    #' @description Start a new SQLite cache.
    #' @param dbname path to the SQLite file, or `":memory:"` for an
    #'   in-memory database (default).
    #' @param ... additional arguments passed to
    #'   `DBI::dbConnect(RSQLite::SQLite(), dbname = dbname, ...)`.
    #' @param cache_table name of the SQLite table backing the cache.
    #'   Defaults to `"bankrcache"`.
    #' @param algo for `{memoise}` compatibility, the `digest()` algorithm.
    #' @param compress for `{memoise}` compatibility, should the data be
    #'   compressed?
    #' @return A `cache_sqlite` object.
    initialize = function(dbname = ":memory:",
                          ...,
                          cache_table = "bankrcache",
                          algo = "sha512",
                          compress = FALSE) {
      if (!requireNamespace("RSQLite", quietly = TRUE)) {
        stop(
          "The {RSQLite} package has to be installed before using `cache_sqlite`.\n",
          "Please install it first, for example with install.packages('RSQLite')."
        )
      }
      if (!requireNamespace("DBI", quietly = TRUE)) {
        stop(
          "The {DBI} package has to be installed before using `cache_sqlite`.\n",
          "Please install it first, for example with install.packages('DBI')."
        )
      }

      private$interface <- DBI::dbConnect(
        RSQLite::SQLite(),
        dbname = dbname,
        ...
      )

      private$cache_table <- cache_table

      if (cache_table %in% DBI::dbListTables(private$interface)) {
        # Reusing an existing table: validate that the schema matches what
        # cache_sqlite expects. Bail out early with a readable error rather
        # than failing later inside an INSERT/SELECT.
        cols <- DBI::dbListFields(private$interface, cache_table)
        if (!setequal(cols, c("id", "cache"))) {
          stop(
            "Existing table `", cache_table, "` does not match the cache schema.",
            "\nExpected columns: id, cache. Found: ",
            paste(cols, collapse = ", "),
            call. = FALSE
          )
        }
      } else {
        DBI::dbCreateTable(
          private$interface,
          cache_table,
          fields = c(
            id = "TEXT",
            cache = "BLOB"
          )
        )
      }

      private$algo <- algo
      private$compress <- compress
    },
    #' @description Does the cache contain a given key?
    #' @param key key name.
    #' @return `TRUE`/`FALSE`.
    has_key = function(key) {
      res <- DBI::dbGetQuery(
        private$interface,
        sprintf("SELECT id FROM %s WHERE id = ?;", private$cache_table),
        params = list(key)
      )
      if (nrow(res) > 1L) {
        stop("Corrupted cache: more than one entry for ", key)
      }
      nrow(res) == 1L
    },
    #' @description Get a key from the cache.
    #' @param key key name.
    #' @return the value stored under `key`, or an object of class
    #'   `"key_missing"` if the key is absent.
    get = function(key) {
      if (!self$has_key(key)) {
        return(structure(list(), class = "key_missing"))
      }
      out <- DBI::dbGetQuery(
        private$interface,
        sprintf("SELECT cache FROM %s WHERE id = ?;", private$cache_table),
        params = list(key)
      )
      tryCatch(
        unserialize(out$cache[[1L]]),
        error = function(e) structure(list(), class = "key_missing")
      )
    },
    #' @description Set a key in the cache. If the key already exists, its
    #'   value is overwritten (matching the {memoise} cache contract).
    #' @param key key name.
    #' @param value value to store.
    #' @return used for side effect.
    set = function(key, value) {
      blob <- serialize(value, NULL)
      if (self$has_key(key)) {
        DBI::dbExecute(
          private$interface,
          sprintf(
            "UPDATE %s SET cache = ? WHERE id = ?;",
            private$cache_table
          ),
          params = list(list(blob), key)
        )
      } else {
        DBI::dbExecute(
          private$interface,
          sprintf(
            "INSERT INTO %s (id, cache) VALUES (?, ?);",
            private$cache_table
          ),
          params = list(key, list(blob))
        )
      }
      invisible(NULL)
    },
    #' @description Clear the whole cache.
    #' @return used for side effect.
    reset = function() {
      DBI::dbExecute(
        private$interface,
        sprintf("DELETE FROM %s;", private$cache_table)
      )
      invisible(NULL)
    },
    #' @description Remove a single key.
    #' @param key key name.
    #' @return number of rows removed.
    remove = function(key) {
      DBI::dbExecute(
        private$interface,
        sprintf("DELETE FROM %s WHERE id = ?;", private$cache_table),
        params = list(key)
      )
    },
    #' @description List every key in the cache.
    #' @return a character vector of keys.
    keys = function() {
      DBI::dbGetQuery(
        private$interface,
        sprintf("SELECT id FROM %s;", private$cache_table)
      )$id
    },
    #' @description Hash helper for `{memoise}` compatibility.
    #' @param ... value to hash.
    #' @return a character(1) hash.
    digest = function(...) digest::digest(..., algo = private$algo)
  ),
  private = list(
    interface = NULL,
    cache_table = character(0),
    algo = character(0),
    compress = logical(0),
    finalize = function() {
      if (!is.null(private$interface) &&
        inherits(private$interface, "DBIConnection") &&
        DBI::dbIsValid(private$interface)) {
        DBI::dbDisconnect(private$interface)
      }
      invisible(NULL)
    }
  )
)
