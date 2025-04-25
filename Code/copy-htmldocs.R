
cat(commandArgs(), fill = TRUE)

## Data source via HTTP[S]: Can point to github (slower) or to a git
## clone served locally (see README)

## RAWDATALOC <- "https://raw.githubusercontent.com/deepayan/nhanes-snapshot/main/"
RAWDATALOC <- "http://192.168.0.27:9849/snapshot/"

RAWDATASRC <- paste0(RAWDATALOC, "docs/")

ydirs <- sprintf("/htmldoc/%s-%s",	
                 seq(1999, 2021, by = 2),
                 seq(2000, 2022, by = 2))

sapply(ydirs[-11], dir.create)

htmlfiles <- readLines(paste0(RAWDATASRC, "MANIFEST.txt"))
htmlfiles <- htmlfiles[!endsWith(htmlfiles, "All Years.htm")]

for (f in htmlfiles) {
    cat("Copying ", f, "...\n")
    download.file(paste0(RAWDATASRC, f),
                  destfile = file.path("/htmldoc", f))
}

