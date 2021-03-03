#' @export
cache_mongo <- R6::R6Class(
  "cache_mongo",
  public = list(
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
    reset = function() {
      private$interface$drop()
    },
    remove = function(key) {
      private$interface$remove(
        sprintf(
          '{"metadata.key": "%s"}',
          key
        )
      )
    },
    keys = function() {
      private$interface$find()$name
    },
    # For compatibily with {memoise}
    digest = function(...) digest::digest(..., algo = private$algo)
  ),
  private = list(
    interface = list(),
    fs_file = list(),
    algo = character(0),
    compress = logical(0)
  )
)

