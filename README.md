
<!-- README.md is generated from README.Rmd. Please edit that file -->

# bank

<!-- badges: start -->

<!-- badges: end -->

The goal of `{bank}` is to provide alternative backends for caching with
`{memoise}` & `{shiny}`.

## Installation

``` r
# install.packages("remotes")
remotes::install_github("thinkr-open/bank")
```

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
docker run --rm --name mongobank -d -p 27066:27017 mongo:3.4
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
  url = "mongodb://localhost:27066",
  prefix = "sn"
)
#> Loading required namespace: mongolite

f <- function(x) {
  sample(1:1000, x)
}

mf <- memoise(f, cache = mongo_cache)
mf(5)
#> [1] 717 178 548 579 885
mf(5)
#> [1] 717 178 548 579 885
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

### Redis

Launching a container with redis.

``` bash
docker run --rm --name redisbank -d -p 6379:6379 redis:5.0.5
```

#### With `{memoise}`

``` r
# Create a redis cache. 
# The arguments will be passed to redux::hiredis
redis_cache <- cache_redis$new()

f <- function(x) {
  sample(1:1000, x)
}

mf <- memoise(f, cache = redis_cache)
mf(5)
mf(5)
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
  url = "mongodb://localhost:27066",
  prefix = "sn"
)

redis_cache <- cache_redis$new()
#> Loading required namespace: redux

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
#> 1 mem_cache    27.73µs  30.62µs   25519.     5.02KB    0    
#> 2 disk_cache    5.87ms   7.05ms     134.    18.45KB    0    
#> 3 mongo_cache  41.42ms  64.88ms      13.0    2.52MB    0.540
#> 4 redis_cache  27.53ms   39.4ms      24.6  569.09KB    0.503

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
#> 1 mem_cache    13.75µs  17.82µs   41938.         0B    0    
#> 2 disk_cache    2.14ms   2.79ms     330.   548.19KB    3.33 
#> 3 mongo_cache   36.6ms  49.28ms      19.4    2.06MB    0.807
#> 4 redis_cache  17.23ms   28.3ms      33.5    1.04MB    1.04
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
