
cat(commandArgs(), fill = TRUE)

## Data source via HTTP[S]: Can point to github (slower) or to a git
## clone served locally (see README)

## RAWDATALOC <- "https://raw.githubusercontent.com/deepayan/nhanes-snapshot/main/"
RAWDATALOC <- "http://192.168.0.27:9849/snapshot/"

## would have been more general but does not always work
## RAWDATALOC <- "http://host.docker.internal:9849/snapshot/"

METADATASRC <- paste0(RAWDATALOC, "metadata/")


library(DBI)
library(RPostgres)

options(warn = 1)

Sys.sleep(10)

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

DBI::dbExecute(con, "CREATE SCHEMA \"Metadata\";")
DBI::dbExecute(con, "CREATE SCHEMA \"Raw\";")
DBI::dbExecute(con, "CREATE SCHEMA \"Translated\";")

cat("=== Inserting Container version information\n")

COLLECTION_DATE <- paste(trimws(readLines("/tmp/COLLECTION_DATE")), collapse = "")
CONTAINER_VERSION <- paste(trimws(readLines("/tmp/CONTAINER_VERSION")), collapse = "")

VersionInfo <-
    data.frame(Tag = c("COLLECTION_DATE", "CONTAINER_VERSION"), 
               Value = c(COLLECTION_DATE, CONTAINER_VERSION))

print(VersionInfo)

DBI::dbWriteTable(con, makeID("Metadata", "VersionInfo"), VersionInfo)


codebookFile <- paste0(METADATASRC, "codebookDF.rds")
tablesFile <- paste0(METADATASRC, "tablesDF.rds")
variablesFile <- paste0(METADATASRC, "variablesDF.rds")

cat("=== Reading ", codebookFile, "\n")
codebookDF <- readRDS(url(codebookFile))
## str(codebookDF)

cat("=== Reading ", tablesFile, "\n")
tablesDF <- readRDS(url(tablesFile))
## str(tablesDF)

cat("=== Reading ", variablesFile, "\n")
variablesDF <- readRDS(url(variablesFile))
## str(variablesDF)

## Postgres queries convert all un-(double)quoted column names to
## lowercase. Rather than change all usage code, it might have been
## simpler to make all column names consistently lowercase, but
## unfortunately this makes comparison in R unwieldy.

## names(codebookDF) <- tolower(names(codebookDF))
## names(tablesDF) <- tolower(names(tablesDF))
## names(variablesDF) <- tolower(names(variablesDF))


## RPostgres::dbWriteTable() will use copy = TRUE (fast but less
## general) by default for Postgres connections

DBI::dbWriteTable(con, makeID("Metadata", "QuestionnaireDescriptions"), tablesDF)
DBI::dbWriteTable(con, makeID("Metadata", "VariableCodebook"), codebookDF)
DBI::dbWriteTable(con, makeID("Metadata", "QuestionnaireVariables"), variablesDF)

cat("=== Finished inserting Metadata tables\n")






## FIXME: Need to add non-null columns, create primary keys
