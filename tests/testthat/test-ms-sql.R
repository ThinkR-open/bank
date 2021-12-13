test_that("cache_ms_sql works", {
  skip_on_ci()

  system('docker run --rm --name mssqlbankunittest -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=MySecret@Passw0rd" -p 1433:1433 -d mcr.microsoft.com/mssql/server:2019-latest')

  Sys.sleep(10)

  ms_sql_cache <- cache_ms_sql$new(
    Driver = "SQL Server",
    Server = "localhost",
    Database = "master",
    UID = "SA",
    PWD = "MySecret@Passw0rd",
    Port = 1433)

  test_them_all(
    cache = ms_sql_cache
  )

  system("docker kill mssqlbankunittest")
})
