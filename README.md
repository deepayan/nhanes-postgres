# NHANES in Postgres

This repository contains R code and a Docker image definition that
facilitate pulling the CDC's NHANES data files into a SQL DBMS. It is
inspired by the [this
project](https://github.com/ccb-hms/NHANES-database), retaining its
design but using a different implentation.

The image is derived from
[rocker/tidyverse](https://hub.docker.com/r/rocker/tidyverse/), which
is an Ubuntu GNU/Linux image containing R and RStudio Server, and adds
a PostgreSQL database containing data from NHANES.


# Quick start

To run the current pre-built image, install docker and run

```
docker run --rm --name nhanes-pg -d \
    -p 8787:8787 \
	-p 2200:22 \
	-p 5432:5432 \
	-e 'CONTAINER_USER_USERNAME=test' \
	-e 'CONTAINER_USER_PASSWORD=test' \
	deepayansarkar/nhanes-postgresql:0.1.6
```

To map a local directory so that it becomes accessible within the
container, add

```
         -v <LOCAL_DIRECTORY>:/HostData \
```


This is the easiest way to get started. The various `-p` flags exposes
useful ports in the container:

* Port 8787 is used for access to the RStudio Server HTTP server
  (usually through a web browser using the address
  <http://localhost:8787>). This is the simplest way to use the
  container, as it will give access to an RStudio setup (with username
  `test` and password `test`, customizable in the call above), which
  will have the
  [`nhanesA`](https://cran.r-project.org/package=nhanesA)
  pre-installed and pre-configured to use the database.

* Port 22 can be used to access the container via SSH. If
  needed, it is usually mapped to a different port (2200 in the
  incantation above) as the host machine is likely running its own
  SSH server on port 22.
  
* The PostgreSQL server running in the container can be accessed via
  port 5432. Mapping it to a port on the host machine allows direct
  access to the database over the local network, which can be useful
  in multi-user environments.



# Building

Build the docker image using (but see below for the version using `time`)

```
docker build --progress plain --shm-size=1024M --platform=linux/amd64 --tag nhanes-postgres -f Container/Dockerfile .
```

In principle, one could also build on ARM64 (typically on an Apple Silicon machine) using the following,

```
docker build --progress plain --shm-size=1024M --platform=linux/arm64 --tag nhanes-postgres -f Container/Dockerfile .
```

but this is not currently possible due to limitations of the parent
image (rocker/tidyverse).

It may be useful to redirect the console output to a log file, as it
will contain informative messages about failures. This may be done
using something like

```
time docker build --progress plain --shm-size=2048M --platform=linux/amd64 --tag nhanes-postgres -f Container/Dockerfile . &> build.log
```

To upload to docker hub:

```
docker tag nhanes-postgres <user>/nhanes-postgresql:x.y.z
docker push <user>/nhanes-postgresql:x.y.z
```


# Running

Run the locally built image as before, replacing the image name:

```
docker run --rm --name nhanes-pg -d \
         -p 8787:8787 \
         -p 2200:22 \
         -p 5432:5432 \
         -e 'CONTAINER_USER_USERNAME=test' \
         -e 'CONTAINER_USER_PASSWORD=test' \
         nhanes-postgres
```

As before, to map a local directory, add

```
         -v <LOCAL_DIRECTORY>:/HostData \
```


# Developer notes

## Salient features:

- Based on rocker/tidyverse:4.3.3, which gives us Ubuntu 22.04 LTS
  along with RStudio Server and DBI packages (and of course tidyverse,
  which we do not use)
  
- All database insertions are done through `DBI`. All data are
  downloaded directly from GitHub "raw" URLs. No data is saved in
  files locally.
  
- By default, raw data is obtained from
  <https://github.com/ccb-hms/nhanes-data>, and not directly from the
  CDC website. The source is customizable in `Dockerfile`, which may
  be useful if one wants to avoid build-time downloads by making a a
  local clone of the repository available via a (local) server such as
  [httpuv](https://cran.r-project.org/package=httpuv).

- Codebook data is obtained from
  <https://github.com/ccb-hms/NHANES-metadata> (ontology tables are
  not loaded yet)

- There are a handful of failures, which are not yet tracked properly,
  but some information is saved inside the `/status/` directory inside
  the image, as well as in the [`build.log`](./build.log) file (see build
  instructions above).


## Changes

The DB schema and other interface details are largely similar to the
SQL Server implementation. However, Postgres has one big difference:
unquoted table and column names in SQL statements are automatically
converted to lowercase, which means we need to change how queries are
constructed.

This is mainly an issue with the hard-coded SQL queries in
`nhanesA`. Work on this is being done in the `postgres-backend` branch
of <https://github.com/cjendres1/nhanes>.

## Postgres vs MS SQL Server

Use `RPostgres` to establish connections, with port 5432 by default. For example:

```
DBI::dbConnect(RPostgres::Postgres(),
               dbname = "NhanesLandingZone",
               host = "localhost",
               port = 5432L,
               password = "NHAN35",
               user = "sa")
```

There is no need to install separate drivers, as in the case of Microsoft SQL Server.

## Efficient DB operations

See <https://www.postgresql.org/docs/current/populate.html>.

We follow two of these recommendations explicitly:

- In lieu of bulk insert, we use
  [RPostgres::dbWriteTable()](https://rpostgres.r-dbi.org/reference/postgres-tables.html),
  which uses `COPY` by default.
  
- Primary keys are added after all tables have been created.

We should explore others as well.


## Installing pgAdmin

See <https://www.pgadmin.org/download/>



## Other Thoughts

- Not sure if there is anything analogous to SQL Server's `DBCC
SHRINKFILE` or MariaDB's `FLUSH BINARY LOG`. The one log file produced
in `var/log/postgresql` is fairly small.

