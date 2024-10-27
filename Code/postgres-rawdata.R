
cat(commandArgs(), fill = TRUE)

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

makeID <- function(schema, table)
{
    DBI::dbQuoteIdentifier(con, DBI::Id(schema, table))
}

## Data source via HTTP[S]: Can point to github (slower) or to a git
## clone served locally (see README)

## RAWDATASRC <- "https://raw.githubusercontent.com/deepayan/nhanes-snapshot/main/data/"
RAWDATASRC <- "http://192.168.0.213:9849/snapshot/data/"


## Function to download and insert a raw NHANES table. A download
## attempt is made only if the table does not already exist, and
## errors are captured; this is to allow the function to be called
## multiple times in case a subsequent download attempt succeeds.

## NOTE: postgres advice is to create primary keys _after_ data has
## been inserted, so skip that step for now. Needs to be done later; see
## addPrimaryKey() in postgres-helpers.R

insertRawTable <- function(nhtable, con,
                           as_integer = TRUE,
                           non_null = primary_keys(nhtable),
                           make_primary_key = FALSE,
                           verbose = TRUE)
{
    target <- makeID("Raw", nhtable)
    if (DBI::dbExistsTable(con, target)) return("")

    ## Read data from csv.xz file
    if (verbose) {
        cat("=== ", nhtable, ": ")
        on.exit(cat("\n"))
        cat("downloading...")
        flush.console()
    }
    d <- try(
    {
        if (startsWith(RAWDATASRC, "http")) {
            TEMPDATA <- "/tmp/temp.csv.xz"
            datafile <- paste0(RAWDATASRC, nhtable, ".csv.xz")
            download.file(datafile, destfile = TEMPDATA, quiet = TRUE)
            datafile <- TEMPDATA
        }
        read.csv(xzfile(datafile))
    }, silent = FALSE)
    if (inherits(d, "try-error"))
        return(structure("error reading raw data", names = nhtable))

    dcols <- names(d)
    if (isTRUE(as_integer)) {
        for (v in dcols) {
            if (isWholeNumber(d[[v]]))
                d[[v]] <- as.integer(d[[v]])
        }
    }

    ## Insert into DB
    if (verbose) {
        cat("inserting into DB...")
        flush.console()
    }
    res <- try(
    {
        dtype <- DBI::dbDataType(con, d)
        if (!is.null(non_null)) {
            if (!all(non_null %in% dcols)) {
                warning("Column(s) specified as non-null do not exist in data: ",
                        non_null[!(non_null %in% dcols)] |> paste(collapse = ", "))
                non_null <- intersect(non_null, dcols)
            }
            dtype[non_null] <- paste0(dtype[non_null], " NOT NULL")
        }
        DBI::dbWriteTable(con, target, d,
                          field.types = dtype,
                          copy = TRUE)
        ## unclear from documentation is we should prefer this 2-step approach:
        ## DBI::dbCreateTable(con, target, dtype)
        ## DBI::dbAppendTable(con, target, d)
    }, silent = FALSE)
    if (inherits(res, "try-error"))
        return(structure("error inserting raw data", names = nhtable))
    else 
        return(structure("", names = nhtable))
}

## Get tables to download from metadata - slightly different from
## manifest (e.g., large tables are included) - but for those
## insertion attempt will simply fail

tablesDF <- DBI::dbReadTable(con, makeID("Metadata", "QuestionnaireDescriptions"))

TABLES <- subset(tablesDF, UseConstraints == "None")[["TableName"]] |> sort()

## TABLES <- head(TABLES)

status <- vapply(TABLES, insertRawTable, FUN.VALUE = "", con = con)

table(status)

cat("*** Status summary ***\n\n")

dstatus <- data.frame(Table = names(status), status = unname(status)) |> subset(nzchar(status))
dstatus
write.csv(dstatus, file = paste0("/status/raw-", gsub(" ", "_", Sys.time(), fixed = TRUE), ".csv"))


cat("=== Finished inserting Raw tables\n")



