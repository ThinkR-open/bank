
<!-- README.md is generated from README.Rmd. Please edit that file -->

# bank

<!-- badges: start -->

[![R-CMD-check](https://github.com/ThinkR-open/bank/workflows/R-CMD-check/badge.svg)](https://github.com/ThinkR-open/bank/actions)
<!-- badges: end -->

The goal of `{bank}` is to provide alternative backends for caching with
`{memoise}` & `{shiny}`.

## Installation

``` r
# install.packages("remotes")
remotes::install_github("thinkr-open/bank")
```

## Some things to know before starting

### Caching scope

When using `{bank}` backends with `{shiny}`, caching will done at the
app-level, in other words the cache is stored across sessions. Be aware
of this behavior if you have sensitive data inside your app, as this
might imply data leakage.

See `?shiny::bindCache`

> With an app-level cache scope, one user can benefit from the work done
> for another user’s session. In most cases, this is the best way to get
> performance improvements from caching. However, in some cases, this
> could leak information between sessions. For example, if the cache key
> does not fully encompass the inputs used by the value, then data could
> leak between the sessions. Or if a user sees that a cached reactive
> returns its value very quickly, they may be able to infer that someone
> else has already used it with the same values.

### Cache flushing

As with any `{cachem}` compatible objects, the cache can be manually
flushed using the `$reset()` method – this will call `drop()` on
MongoDb, `FLUSHALL` in Redis, & `DBI::dbRemoveTable()` +
`DBI::dbCreateTable()` with Postgres.

``` r
library(bank)
mongo_cache <- cache_mongo$new(
  db = "bank",
  url = "mongodb://localhost:27066",
  prefix = "sn"
)

mongo_cache$reset()
```

As `{bank}` relies on external backends, it’s probably better to let the
DBMS handle the flushing of cache. For example, in `redis.conf`, you can
set :

    maxmemory 2mb
    maxmemory-policy allkeys-lru

LRU (least recently used) will allow redis to flush the key based on
when they were used. See <https://redis.io/topics/lru-cache>.

MongoDB doesn’t come with a LRU mechanism, but you can set data to be
ephemeral with [TTL
index](https://docs.mongodb.com/manual/core/index-ttl/) inside your
collection.

`{bank}` also tries to help with that by updating a `lastAccessed` date
metadata field in Mongo whenever you `$get()` the key, meaning that you
can implement your own caching strategy to evict least recently used
cached objects.

### Postgre limitation

Postgre `bytea` column can only store up to 1GB elements, so you can’t
write a cache that’s &gt; 1GB.

## Backends

Note that if you want to use `{bank}` in a `{shiny}` app:

-   `renderCachedPlot()` require `{shiny}` version 1.5.0 or higher

-   `bindCache()` require `{shiny}` version 1.6.0 or higher

For now, the following backends are supported:

-   [MongoDB](#mongo)

-   [Redis](#redis)

-   [Postgre](#postgres)

### Mongo

Launching a container with mongo.

``` bash
docker run --rm --name mongobank -d -p 27066:27017 -e MONGO_INITDB_ROOT_USERNAME=bebop -e MONGO_INITDB_ROOT_PASSWORD=aloula mongo:3.4
```

#### With `{memoise}`

First, the `cache_mongo` can be used

``` r
library(memoise)
library(bank)
# Create a mongo cache.
# The arguments will be passed to mongo::gridfs
mongo_cache <- cache_mongo$new(
  db = "bank",
  url = "mongodb://bebop:aloula@localhost:27066",
  prefix = "sn"
)
#> Loading required namespace: mongolite

f <- function(x) {
  sample(1:1000, x)
}

mf <- memoise(f, cache = mongo_cache)
mf(5)
#> [1] 405  27 327 821 203
mf(5)
#> [1] 405  27 327 821 203
```

#### Inside `{shiny}`

Here is a first simple application that shows you the basics :

``` r
library(shiny)
ui <- fluidPage(
  # Creating a slider input that will be used as a cache key
  sliderInput("nrow", "NROW", 1, 32, 32),
  # Plotting a piece of mtcars
  plotOutput("plot")
)

server <- function(input, output, session) {
  output$plot <- renderCachedPlot(
    {
      # Pretending this takes a long time
      Sys.sleep(2)
      plot(mtcars[1:input$nrow, ])
    },
    cacheKeyExpr = list(
      # Defining the cache key
      input$nrow
    ),
    # Using our mongo cache
    cache = mongo_cache
  )
}
shinyApp(ui, server)
```

As you can see, the first time you set the slider to a given value, it
takes a little bit to compute. Then it’s almost instantaneous.

Let’s try a more complex application:

``` r
# We'll put everything in a function so that it can later be reused with other backends
library(magrittr)

generate_app <- function(cache_object) {
  ui <- fluidPage(
    h1(
      sprintf(
        "Caching in an external DB using %s",
        deparse(
          substitute(cache_object)
        )
      )
    ),
    sidebarLayout(
      sidebarPanel = sidebarPanel(
        # This sliderInput will be the cache key
        # i.e we don't want to recompute the plot everytime
        sliderInput("nrow", "Nrow", 1, 32, 32),
        # Allow to clear the cache
        actionButton("clear", "Clear Cache")
      ),
      mainPanel = mainPanel(
        # Outputing the reactive and a plot
        verbatimTextOutput("txt"),
        plotOutput("plot"),
        # If you care about listing the cache keys
        uiOutput("keys")
      )
    )
  )

  server <- function(input,
                     output,
                     session) {

    # Our plot, cached using the cache object and
    # watching the nrow
    output$plot <- renderCachedPlot(
      {
        showNotification(
          h2("I'm computing the plot"),
          type = "message"
        )

        # Fake long computation
        Sys.sleep(2)

        # Plot
        plot(mtcars[1:input$nrow, ])
      },
      # We cache on the input$nrow
      cacheKeyExpr = list(
        input$nrow
      ),
      # The cache object is used here
      cache = cache_object
    )

    rc <- reactive({
      showNotification(
        h2("I'm computing the reactive()"),
        type = "message"
      )
      # Fake long computation
      Sys.sleep(2)

      input$nrow * 100
    }) %>%
      # Using bindCache() require shiny > 1.6.0
      bindCache(
        input$nrow,
        cache = cache_object
      )

    output$txt <- renderText({
      rc()
    })

    keys <- reactive({
      # Listing the keys
      invalidateLater(500)
      cache_object$keys()
    })

    output$keys <- renderUI({
      tags$ul(
        lapply(keys(), tags$li)
      )
    })

    observeEvent(input$clear, {
      # Sometime you might want to remove everything from the cache
      cache_object$reset()

      showNotification(
        h2("Cache reset"),
        type = "message"
      )
    })
  }

  shinyApp(ui, server)
}

generate_app(mongo_cache)
```

#### Flushing MongoDB cache using LRU

All keys registered to MongoDB comes with a `metadata.lastAccessed`
parameter. Using this parameter, you’ll be able to flush old cache if
needed.

``` r
mongo <- mongolite::gridfs(
  db = "bank",
  url = "mongodb://bebop:aloula@localhost:27066",
  prefix = "sn"
)
get_metadata <- function(mongo) {
  purrr::map(mongo$find()$metadata, jsonlite::fromJSON)
}
Sys.sleep(10)
mf(5)
#> [1] 405  27 327 821 203
get_metadata(mongo)
#> [[1]]
#> [[1]]$key
#> [1] "116acf5d3c7188709a0374305ba3a33747ef5ce323f3e170862551ed523d7a425658d2fb50d11a557250935326669e0a37efb90205d2ba114795359bb55234ca"
#> 
#> [[1]]$lastAccessed
#> [1] "2021-12-09 15:45:12"

Sys.sleep(10)
mf(5)
#> [1] 405  27 327 821 203
get_metadata(mongo)
#> [[1]]
#> [[1]]$key
#> [1] "116acf5d3c7188709a0374305ba3a33747ef5ce323f3e170862551ed523d7a425658d2fb50d11a557250935326669e0a37efb90205d2ba114795359bb55234ca"
#> 
#> [[1]]$lastAccessed
#> [1] "2021-12-09 15:45:22"
```

### Redis

Launching a container with redis.

``` bash
docker run --rm --name redisbank -d -p 6379:6379 redis:5.0.5 --requirepass bebopalula
```

#### With `{memoise}`

``` r
# Create a redis cache.
# The arguments will be passed to redux::hiredis
redis_cache <- cache_redis$new(password = "bebopalula")
#> Loading required namespace: redux

f <- function(x) {
  sample(1:1000, x)
}

mf <- memoise(f, cache = redis_cache)
mf(5)
#> [1] 697 688 427 706 328
mf(5)
#> [1] 697 688 427 706 328
```

#### Inside `{shiny}`

Here is a first simple application that shows you the basics :

``` r
ui <- fluidPage(
  # Creating a slider input that will be used as a cache key
  sliderInput("nrow", "NROW", 1, 32, 32),
  # Plotting a piece of mtcars
  plotOutput("plot")
)

server <- function(input, output, session) {
  output$plot <- renderCachedPlot(
    {
      # Pretending this takes a long time
      Sys.sleep(2)
      plot(mtcars[1:input$nrow, ])
    },
    cacheKeyExpr = list(
      # Defining the cache key
      input$nrow
    ),
    # Using our redis cache
    cache = redis_cache
  )
}
shinyApp(ui, server)
```

For the larger app:

``` r
generate_app(redis_cache)
```

### Postgres

Launching a container with postgres.

``` bash
docker run --rm --name some-postgres -e POSTGRES_PASSWORD=mysecretpassword -d -p 5433:5432 postgres
```

#### With `{memoise}`

``` r
# Create a postgres cache.
# The arguments will be passed to DBI::dbConnect(RPostgres::Postgres(), ...)
postgres_cache <- cache_postgres$new(
  dbname = "postgres",
  host = "localhost",
  port = 5433,
  user = "postgres",
  password = "mysecretpassword"
)
#> Loading required namespace: RPostgres

f <- function(x) {
  sample(1:1000, x)
}

mf <- memoise(f, cache = postgres_cache)
mf(5)
#> [1] 423 405 460 138 492
mf(5)
#> [1] 423 405 460 138 492
```

#### Inside `{shiny}`

Here is a first simple application that shows you the basics :

``` r
ui <- fluidPage(
  # Creating a slider input that will be used as a cache key
  sliderInput("nrow", "NROW", 1, 32, 32),
  # Plotting a piece of mtcars
  plotOutput("plot")
)

server <- function(input, output, session) {
  output$plot <- renderCachedPlot(
    {
      # Pretending this takes a long time
      Sys.sleep(2)
      plot(mtcars[1:input$nrow, ])
    },
    cacheKeyExpr = list(
      # Defining the cache key
      input$nrow
    ),
    # Using our postgres cache
    cache = postgres_cache
  )
}
shinyApp(ui, server)
```

For the larger app:

``` r
generate_app(postgres_cache)
```

## Chosing a cache method

### Benchmark

As we are deporting the caching to an external DBMS, the query will of
course be slower than using memory cache of disk cache. But this
difference in speed comes with a simpler scalability of the caching, as
several instances of the app can rely on the same caching backend
without the need to be on the same machine.

``` r
library(magrittr)
library(bank)
big_iris <- purrr::rerun(100, iris) %>% data.table::rbindlist()

nrow(big_iris)
#> [1] 15000
pryr::object_size(big_iris)
#> 542,112 B

library(cachem)

mem_cache <- cache_mem()

disk_cache <- cache_disk()

mongo_cache <- cache_mongo$new(
  db = "bank",
  url = "mongodb://bebop:aloula@localhost:27066",
  prefix = "sn"
)

redis_cache <- cache_redis$new(password = "bebopalula")

postgres_cache <- cache_postgres$new(
  dbname = "postgres",
  host = "localhost",
  port = 5433,
  user = "postgres",
  password = "mysecretpassword"
)

bench::mark(
  mem_cache = mem_cache$set("iris", big_iris),
  disk_cache = disk_cache$set("iris", big_iris),
  mongo_cache = mongo_cache$set("iris", big_iris),
  redis_cache = redis_cache$set("iris", big_iris),
  postgres_cache = postgres_cache$set("iris", big_iris),
  check = FALSE,
  iterations = 100
)
#> # A tibble: 5 × 6
#>   expression          min   median `itr/sec` mem_alloc `gc/sec`
#>   <bch:expr>     <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
#> 1 mem_cache       22.94µs  39.86µs  15037.      2.23KB   0     
#> 2 disk_cache       6.24ms   8.06ms    115.     18.44KB   0     
#> 3 mongo_cache     47.74ms  88.24ms      8.40    2.52MB   0.442 
#> 4 redis_cache     35.99ms 100.24ms      6.69  536.58KB   0.0675
#> 5 postgres_cache   6.11ms  13.17ms     44.3   535.65KB   0

bench::mark(
  mem_cache = mem_cache$get("iris"),
  disk_cache = disk_cache$get("iris"),
  mongo_cache = mongo_cache$get("iris"),
  redis_cache = redis_cache$get("iris"),
  postgres_cache = postgres_cache$get("iris"),
  iterations = 100
)
#> # A tibble: 5 × 6
#>   expression          min   median `itr/sec` mem_alloc `gc/sec`
#>   <bch:expr>     <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
#> 1 mem_cache       13.55µs  25.16µs  26185.          0B    0    
#> 2 disk_cache       2.27ms   4.21ms    183.    535.09KB    1.85 
#> 3 mongo_cache     52.98ms  86.59ms      9.35    2.06MB    0.492
#> 4 redis_cache     26.77ms  65.73ms     11.3     1.03MB    0.230
#> 5 postgres_cache  19.47ms  31.49ms     25.1   566.62KB    0.254
```

``` bash
docker stop mongobank redisbank postgresbank
```

## You want another backend?

If you have any other backend in mind, feel free to open an issue here
and we’ll discuss the possibility of implementing it in `{bank}`.

## Code of Conduct

Please note that the bank project is released with a [Contributor Code
of
Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
