#' A Caching object for MongoDB
#'
#' Create a cache backend with MongoDB.
#'
#' @export
cache_mongo <- R6::R6Class(
  "cache_mongo",
  public = list(
    #' @description
    #' Start a new mongo cache
    #' @param db name of database
    #' @param url address of the mongodb server in mongo connection string URI format
    #' @param prefix string to prefix the collection name
    #' @param options	 additional connection options such as SSL keys/certs.
    #' @param algo for `{memoise}` compatibility. The `digest()` algorithm.
    #' @param compress for `{memoise}` compatibility. Should the data be compressed?
    #' @return A cache_mongo object
    initialize = function(
      db = "test",
      url = "mongodb://localhost",
      prefix = "fs",
      options = mongolite::ssl_options(),
      algo = "sha512",
      compress = FALSE
    ){
      if (!requireNamespace("mongolite")){
        stop(
          paste(
            "The {mongolite} package has to be installed before using `cache_mongo`.",
            "Please install it first, for example with install.packages('mongolite').",
            sep = "\n"
          )
        )
      }
      private$interface <- mongolite::gridfs(
        db = db,
        url = url,
        prefix = prefix,
        options = options
      )
     # browser()
      private$fs_file <- mongolite::mongo(
        db = db,
        collection = sprintf("%s.files", prefix),
        url = url,
        options = options
      )
      private$algo <- algo
      private$compress <- compress
    },
    #' @description
    #' Get a key from the cache
    #' @param key Name of the key.
    #' @return The value stored using the `key`
    get = function(key) {

      if (self$has_key(key)){
        #browser()
        private$fs_file$update(
          sprintf(
            '{"metadata.key": "%s"}',
            key
          ),
          sprintf(
            '{"$set":{"metadata.lastAccessed": "%s"}}',
            Sys.time()
          )
        )
        temp_file <- tempfile(pattern = key, fileext = ".RDS")
        # Handling the case where the value has been deleted in-between
        res <- tryCatch(
          private$interface$read(key, temp_file, progress = FALSE),
          error = function(e){
            return(NULL)
          }
        )

        if (is.null(res)){
          return(
            structure(list(), class = "key_missing")
          )
        }

        return(
          readRDS(temp_file)
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
      temp_file <- tempfile(pattern = key, fileext = ".RDS")
      on.exit(unlink(temp_file))
      saveRDS(value, file = temp_file, compress = private$compress)
      private$interface$write(
        temp_file,
        key,
        progress = FALSE,
        metadata = sprintf(
          '{"key": "%s", "lastAccessed" : "%s"}',
          key, Sys.time()
        )
      )
    },
    #' @description
    #' Does the cache contains a given key?
    #' @param key Name of the key.
    #' @return TRUE/FALSE
    has_key = function(key) {
      nrow(
        private$interface$find(
          sprintf(
            '{"metadata.key": "%s"}',
            key
          )
        )
      )  > 0
    },
    #' @description
    #' Clear all the cache
    #' @return Used for side-effect
    reset = function() {
      private$interface$drop()
    },
    #' @description
    #' Remove a key/value pair
    #' @param key Name of the key.
    #' @return Used for side-effect
    remove = function(key) {
      private$interface$remove(
        sprintf(
          '{"metadata.key": "%s"}',
          key
        )
      )
    },
    #' @description
    #' List all the keys in the cache
    #' @return A list of keys
    keys = function() {
      private$interface$find()$name
    },
    #' @description
    #' Function that runs an hash algo.
    #' For compatibily with `{memoise}`.
    #' @param ... the value to hash
    #' @return A function
    digest = function(...) digest::digest(..., algo = private$algo)
  ),
  private = list(
    interface = list(),
    fs_file = list(),
    algo = character(0),
    compress = logical(0)
  )
)

