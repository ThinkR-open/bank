
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
flushed using the `$reset()` method – this will call `drop()` on MongoDB
and `FLUSHALL` in Redis.

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
metadata field whenever you `$get()` the key, meaning that you can
implement your own caching strategy to evict least recently used cached
objects.

## Backends

Note that if you want to use `{bank}` in a `{shiny}` app:

  - `renderCachedPlot()` require `{shiny}` version 1.5.0 or higher

  - `bindCache()` require `{shiny}` version 1.6.0 or higher

For now, the following backends are supported:

  - [MongoDB](#mongo)

  - [Redis](#redis)

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
#> [1]  34 831 763 518 609
mf(5)
#> [1]  34 831 763 518 609
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

server <- function(input, output, session){
  
  output$plot <- renderCachedPlot({
    # Pretending this takes a long time
    Sys.sleep(2)
    plot(mtcars[1:input$nrow, ])
    
  }, cacheKeyExpr = list(
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

generate_app <- function(cache_object){
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
  
  server <- function(
    input, 
    output, 
    session
  ){
    
    # Our plot, cached using the cache object and 
    # watching the nrow
    output$plot <- renderCachedPlot({
      
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
    
    observeEvent( input$clear , {
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
get_metadata <- function(mongo){
  purrr::map(mongo$find()$metadata, jsonlite::fromJSON)
}
Sys.sleep(10)
mf(5)
#> [1]  34 831 763 518 609
get_metadata(mongo)
#> [[1]]
#> [[1]]$key
#> [1] "ea651131fb3af348c02d9a21d03270c0fe90649d93d2ed30fadd32334910167c2a3bad912b46b11c87b80d93abe06b4fead0d4f9971eef4bad946335037be8ee"
#> 
#> [[1]]$lastAccessed
#> [1] "2021-03-30 09:10:04"

Sys.sleep(10)
mf(5)
#> [1]  34 831 763 518 609
get_metadata(mongo)
#> [[1]]
#> [[1]]$key
#> [1] "ea651131fb3af348c02d9a21d03270c0fe90649d93d2ed30fadd32334910167c2a3bad912b46b11c87b80d93abe06b4fead0d4f9971eef4bad946335037be8ee"
#> 
#> [[1]]$lastAccessed
#> [1] "2021-03-30 09:10:14"
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
#> [1] 433 551 342 130 265
mf(5)
#> [1] 433 551 342 130 265
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

server <- function(input, output, session){
  
  output$plot <- renderCachedPlot({
    # Pretending this takes a long time
    Sys.sleep(2)
    plot(mtcars[1:input$nrow, ])
    
  }, cacheKeyExpr = list(
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

## Chosing a cache method

### Benchmark

As we are deporting the caching to an external DBMS, the query will of
course be slower than using memory cache of disk cache. But this
difference in speed comes with a simpler scalability of the caching, as
several instances of the app can rely on the same caching backend
without the need to be on the same machine.

``` r
library(magrittr)
#> Warning: package 'magrittr' was built under R version 3.6.2
library(bank)
big_iris <- purrr::rerun(100, iris) %>% data.table::rbindlist()

nrow(big_iris)
#> [1] 15000
pryr::object_size(big_iris)
#> Registered S3 method overwritten by 'pryr':
#>   method      from
#>   print.bytes Rcpp
#> 542 kB

library(cachem)

mem_cache <- cache_mem()

disk_cache <- cache_disk()

mongo_cache <- cache_mongo$new(
  db = "bank",
  url = "mongodb://bebop:aloula@localhost:27066",
  prefix = "sn"
)

redis_cache <- cache_redis$new(password = "bebopalula")

bench::mark(
  mem_cache = mem_cache$set("iris", big_iris),
  disk_cache = disk_cache$set("iris", big_iris),
  mongo_cache = mongo_cache$set("iris", big_iris),
  redis_cache = redis_cache$set("iris", big_iris),
  check = FALSE, 
  iterations = 100
)
#> # A tibble: 4 x 6
#>   expression       min   median `itr/sec` mem_alloc `gc/sec`
#>   <bch:expr>  <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
#> 1 mem_cache     24.6µs  33.77µs   19585.     5.02KB    0    
#> 2 disk_cache    6.33ms   8.23ms      94.0   18.45KB    0    
#> 3 mongo_cache  49.27ms  67.34ms      11.6    2.52MB    0.482
#> 4 redis_cache  26.91ms  36.95ms      21.3  536.58KB    0.215

bench::mark(
  mem_cache = mem_cache$get("iris"),
  disk_cache = disk_cache$get("iris"),
  mongo_cache = mongo_cache$get("iris"),
  redis_cache = redis_cache$get("iris"),
  iterations = 100
)
#> # A tibble: 4 x 6
#>   expression       min   median `itr/sec` mem_alloc `gc/sec`
#>   <bch:expr>  <bch:tm> <bch:tm>     <dbl> <bch:byt>    <dbl>
#> 1 mem_cache    14.45µs  20.17µs   38244.         0B    0    
#> 2 disk_cache    2.13ms   2.66ms     335.   548.19KB    3.38 
#> 3 mongo_cache  41.14ms  60.34ms      15.0    2.06MB    0.624
#> 4 redis_cache     19ms  30.32ms      25.9    1.03MB    0.529
```

``` bash
docker stop mongobank redisbank
```

## You want another backend?

If you have any other backend in mind, feel free to open an issue here
and we’ll discuss the possibility of implementing it in `{bank}`.

## Code of Conduct

Please note that the bank project is released with a [Contributor Code
of
Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
