
cat(commandArgs(), fill = TRUE)

## Data source via HTTP[S]: Can point to github (slower) or to a git
## clone served locally (see README)

## RAWDATASRC <- "https://raw.githubusercontent.com/deepayan/nhanes-snapshot/main/docs/"
RAWDATASRC <- "http://192.168.0.213:9849/snapshot/docs/"

htmlfiles <- readLines(paste0(RAWDATASRC, "MANIFEST.txt"))
htmlfiles <- htmlfiles[htmlfiles != "All Years.html"]

for (f in htmlfiles) {
    cat("Copying ", f, "...\n")
    download.file(paste0(RAWDATASRC, f),
                  destfile = file.path("/htmldoc", f))
}

