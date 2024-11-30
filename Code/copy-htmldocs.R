
cat(commandArgs(), fill = TRUE)

ydirs <- sprintf("/htmldoc/%s-%s",	
                 seq(1999, 2021, by = 2),
                 seq(2000, 2022, by = 2))

sapply(ydirs[-11], dir.create)

## Data source via HTTP[S]: Can point to github (slower) or to a git
## clone served locally (see README)

## RAWDATASRC <- "https://raw.githubusercontent.com/deepayan/nhanes-snapshot/main/docs/"
RAWDATASRC <- "http://192.168.0.213:9849/snapshot/docs/"

htmlfiles <- readLines(paste0(RAWDATASRC, "MANIFEST.txt"))
htmlfiles <- htmlfiles[!endsWith(htmlfiles, "All Years.htm")]

for (f in htmlfiles) {
    cat("Copying ", f, "...\n")
    download.file(paste0(RAWDATASRC, f),
                  destfile = file.path("/htmldoc", f))
}

