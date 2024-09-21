
cat(commandArgs(), fill = TRUE)

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

## Can change these to a local source 

METADATASRC <- "https://raw.githubusercontent.com/ccb-hms/NHANES-metadata/master/metadata/"

codebookFile <- paste0(METADATASRC, "nhanes_variables_codebooks.tsv")
tablesFile <- paste0(METADATASRC, "nhanes_tables.tsv")
variablesFile <- paste0(METADATASRC, "nhanes_variables.tsv")

cat("=== Reading ", codebookFile, "\n")
codebookDF <- read.delim(codebookFile)
names(codebookDF)[2] <- "TableName"
## str(codebookDF)

cat("=== Reading ", tablesFile, "\n")
tablesDF <- read.delim(tablesFile)
names(tablesDF)[c(1,2)] <- c("TableName", "Description")
## str(tablesDF)

cat("=== Reading ", variablesFile, "\n")
variablesDF <- read.delim(variablesFile, sep = "\t", header = TRUE)
names(variablesDF)[c(2, 3, 4)] <- c("TableName", "SasLabel", "Description")
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
