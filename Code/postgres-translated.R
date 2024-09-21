cat(commandArgs(), fill = TRUE)

library(DBI)
library(RPostgres)

options(warn = 1)
source("postgres-helpers.R")
source("translate-table.R")

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


## Function to obtain codebook and raw data from database, and
## translate and insert into DB. Silently does nothing if the target
## table already exists.

## NOTE: postgres advice is to create primary keys _after_ data has
## been inserted, so skip for now. Needs to be done later; see
## addPrimaryKey() in postgres-helpers.R

insertTranslatedTable <-
    function(nhtable, con,
             as_integer = TRUE,
             non_null = primary_keys(nhtable),
             make_primary_key = TRUE,
             verbose = TRUE)
{
    target <- makeID("Translated", nhtable)
    rawtable <- makeID("Raw", nhtable)
    qv <- makeID("Metadata", "QuestionnaireVariables")
    vc <- makeID("Metadata", "VariableCodebook")
    if (DBI::dbExistsTable(con, target)) return("")

    if (verbose) {
        cat("=== ", nhtable, ": ")
        on.exit(cat("\n"))
        cat("translating...")
        flush.console()
    }
    d <- try(
    {
        translate_table(name = nhtable, con = con, x = rawtable,
                        qv = qv, vc = vc, cleanse_numeric = TRUE)
    }, silent = FALSE)
    if (inherits(d, "try-error"))
        return(structure("error translating data", names = nhtable))
    else
        cat(sprintf("[ %d x %d ] ", nrow(d), ncol(d)))

    names(d) <- names(d)
    dcols <- names(d)
    if (isTRUE(as_integer)) {
        for (v in dcols) {
            if (isWholeNumber(d[[v]]))
                d[[v]] <- suppressWarnings(as.integer(d[[v]]))
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

## cat("------------ tables\n")
## str(TABLES)

## cat("------------ variables\n")
## str(DBI::dbReadTable(con, "Metadata.QuestionnaireVariables"))

## cat("------------- codebook\n")
## str(DBI::dbReadTable(con, "Metadata.VariableCodebook"))

status <- vapply(TABLES, insertTranslatedTable, FUN.VALUE = "", con = con)

table(status)

cat("*** Status summary ***\n\n") # TODO: save in timestamped file and record later

dstatus <- data.frame(Table = names(status), status = unname(status)) |> subset(nzchar(status))
dstatus
write.csv(dstatus, file = paste0("/status/translated-", gsub(" ", "_", Sys.time(), fixed = TRUE), ".csv"))


cat("=== Finished inserting Translated tables\n")

