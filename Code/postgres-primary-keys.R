
library(DBI)
library(RPostgres)

options(warn = 1)
source("postgres-helpers.R")

Sys.sleep(5)

con <- 
    DBI::dbConnect(RPostgres::Postgres(),
                   dbname = "NhanesLandingZone",
                   host = "localhost",
                   port = 5432L,
                   password = "NHAN35",
                   user = "sa")


## Function to obtain codebook and raw data from database, and
## translate and insert into DB. Silently does nothing if the target
## table already exists.

## NOTE: postgres advice is to create primary keys _after_ data has
## been inserted, so skip for now. Needs to be done later; see
## addPrimaryKey() in postgres-helpers.R

update_pkey <- function(nhtable, con,
                        verbose = TRUE)
{
    trtable <- DBI::dbQuoteIdentifier(con, paste0("Translated.", nhtable))
    rawtable <- DBI::dbQuoteIdentifier(con, paste0("Raw.", nhtable))
    ans <- data.frame(raw = DBI::dbExistsTable(con, rawtable),
                      translated = DBI::dbExistsTable(con, rawtable),
                      updated = NA)
    if (verbose) {
        cat("=== ", nhtable, ": ")
        on.exit(cat("\n"))
        cat("updating primary keys...")
        flush.console()
    }
    res <- try(
    {
        pkey <- primary_keys(nhtable, require_unique = TRUE)
        addPrimaryKey(con, rawtable, pkey)
        addPrimaryKey(con, trtable, pkey)
        TRUE
    }, silent = FALSE)
    ans$updated <- isTRUE(res)
    ans
}

## Get tables to download from metadata - slightly different from
## manifest (e.g., large tables are included) - but for those
## insertion attempt will simply fail

tablesDF <- DBI::dbReadTable(con, "Metadata.QuestionnaireDescriptions")

TABLES <- subset(tablesDF, UseConstraints == "None")[["TableName"]] |> sort()

status <- lapply(TABLES, update_pkey, con = con)
dstatus <- do.call(rbind, status)

write.csv(dstatus, file = "/status/final-summary.csv")



