% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/postgres.R
\name{cache_postgres}
\alias{cache_postgres}
\title{A Caching object for postgres}
\description{
A Caching object for postgres

A Caching object for postgres
}
\details{
Create a cache backend with postgres
}
\section{Methods}{
\subsection{Public methods}{
\itemize{
\item \href{#method-cache_postgres-new}{\code{cache_postgres$new()}}
\item \href{#method-cache_postgres-has_key}{\code{cache_postgres$has_key()}}
\item \href{#method-cache_postgres-get}{\code{cache_postgres$get()}}
\item \href{#method-cache_postgres-set}{\code{cache_postgres$set()}}
\item \href{#method-cache_postgres-reset}{\code{cache_postgres$reset()}}
\item \href{#method-cache_postgres-remove}{\code{cache_postgres$remove()}}
\item \href{#method-cache_postgres-keys}{\code{cache_postgres$keys()}}
\item \href{#method-cache_postgres-digest}{\code{cache_postgres$digest()}}
\item \href{#method-cache_postgres-clone}{\code{cache_postgres$clone()}}
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-cache_postgres-new"></a>}}
\if{latex}{\out{\hypertarget{method-cache_postgres-new}{}}}
\subsection{Method \code{new()}}{
Start a new postgres cache
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{cache_postgres$new(
  ...,
  cache_table = "bankrcache",
  algo = "sha512",
  compress = FALSE
)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{...}}{Parameters passes do DBI::dbConnect(RPostgres::Postgres(), ...)}

\item{\code{cache_table}}{On \code{initialize()}, the cache object will create a table
to store the cache. Default name is \code{bankrcache}. Change it if you already
have a table named \code{bankrcache} in your DB.}

\item{\code{algo}}{for \code{{memoise}} compatibility, the \code{digest()} algorithm}

\item{\code{compress}}{for \code{{memoise}} compatibility, should the data be compressed?}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
A cache_postgres object
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-cache_postgres-has_key"></a>}}
\if{latex}{\out{\hypertarget{method-cache_postgres-has_key}{}}}
\subsection{Method \code{has_key()}}{
Does the cache contains a given key?
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{cache_postgres$has_key(key)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{key}}{Name of the key.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
TRUE/FALSE
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-cache_postgres-get"></a>}}
\if{latex}{\out{\hypertarget{method-cache_postgres-get}{}}}
\subsection{Method \code{get()}}{
Get a key from the cache
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{cache_postgres$get(key)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{key}}{Name of the key.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
The value stored using the \code{key}
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-cache_postgres-set"></a>}}
\if{latex}{\out{\hypertarget{method-cache_postgres-set}{}}}
\subsection{Method \code{set()}}{
Set a key in the cache
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{cache_postgres$set(key, value)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{key}}{Name of the key.}

\item{\code{value}}{Value to store}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
Used for side effect
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-cache_postgres-reset"></a>}}
\if{latex}{\out{\hypertarget{method-cache_postgres-reset}{}}}
\subsection{Method \code{reset()}}{
Clear all the cache
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{cache_postgres$reset()}\if{html}{\out{</div>}}
}

\subsection{Returns}{
Used for side-effect
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-cache_postgres-remove"></a>}}
\if{latex}{\out{\hypertarget{method-cache_postgres-remove}{}}}
\subsection{Method \code{remove()}}{
Remove a key/value pair
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{cache_postgres$remove(key)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{key}}{Name of the key.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
Used for side-effect
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-cache_postgres-keys"></a>}}
\if{latex}{\out{\hypertarget{method-cache_postgres-keys}{}}}
\subsection{Method \code{keys()}}{
List all the keys in the cache
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{cache_postgres$keys()}\if{html}{\out{</div>}}
}

\subsection{Returns}{
A list of keys
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-cache_postgres-digest"></a>}}
\if{latex}{\out{\hypertarget{method-cache_postgres-digest}{}}}
\subsection{Method \code{digest()}}{
Function that runs an hash algo.
For compatibily with \code{{memoise}}
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{cache_postgres$digest(...)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{...}}{the value to hash}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
A function
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-cache_postgres-clone"></a>}}
\if{latex}{\out{\hypertarget{method-cache_postgres-clone}{}}}
\subsection{Method \code{clone()}}{
The objects of this class are cloneable with this method.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{cache_postgres$clone(deep = FALSE)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{deep}}{Whether to make a deep clone.}
}
\if{html}{\out{</div>}}
}
}
}
