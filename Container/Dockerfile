#
# Container image with NHANES data inside a Postgres database
# Author: Deepayan Sarkar

## Build / run: See README.md

## Base image: See <https://github.com/epiconnector/docker-rdev>

FROM epiconnector/rdev:4.4

#------------------------------------------------------------------------------
# Basic initial system configuration
#------------------------------------------------------------------------------

USER root
WORKDIR /tmp

#------------------------------------------------------------------------------
# Install system tools and libraries via apt
#------------------------------------------------------------------------------

ARG DEBIAN_FRONTEND=noninteractive

## FIXME: Should we do postgres here or in the base image?

#RUN apt-get update \
#    && apt-get install \
#	       -y \
#	       postgresql postgresql-client phppgadmin libpq-dev \
#    && rm -rf /var/lib/apt/lists/*

#------------------------------------------------------------------------------
# Set up SQL Server, download and insert metadata + raw tables
# Install DBI and RPostgres first if needed (already included in rocker/tidyverse)
#------------------------------------------------------------------------------

RUN mkdir /status
COPY COLLECTION_DATE /tmp/COLLECTION_DATE
COPY CONTAINER_VERSION /tmp/CONTAINER_VERSION
COPY Code/utils/postgres-helpers.R /tmp/postgres-helpers.R
COPY Code/postgres-setup.sql /tmp/postgres-setup.sql
COPY Code/postgres-setup.R /tmp/postgres-setup.R
COPY Code/postgres-rawdata.R /tmp/postgres-rawdata.R

# Create DB user sa, database NhanesLandingZone, and load metadata +
# raw data. Repeat the raw data loading once, in case the second
# attempt resolves cases that gave errors the first time

RUN service postgresql start \
    && sleep 5 \
    && sudo -u postgres psql --file=/tmp/postgres-setup.sql \
    && Rscript /tmp/postgres-setup.R \
    && Rscript /tmp/postgres-rawdata.R \
    && Rscript /tmp/postgres-rawdata.R \
    && service postgresql stop

#------------------------------------------------------------------------------
# Insert translated tables, add primary keys
#------------------------------------------------------------------------------

COPY Code/utils/translate-table.R /tmp/translate-table.R
COPY Code/postgres-translated.R /tmp/postgres-translated.R
COPY Code/postgres-primary-keys.R /tmp/postgres-primary-keys.R

RUN service postgresql start \
    && sleep 5 \
    && Rscript /tmp/postgres-translated.R \
    && Rscript /tmp/postgres-primary-keys.R \
    && service postgresql stop


#------------------------------------------------------------------------------
# Copy over HTML documentation files
#------------------------------------------------------------------------------

COPY Code/copy-htmldocs.R /tmp/copy-htmldocs.R
RUN mkdir /htmldoc \
    && Rscript /tmp/copy-htmldocs.R

#------------------------------------------------------------------------------
# Set environment variables (e.g., so that nhanesA uses the database)
#------------------------------------------------------------------------------

## env variables identifying container
ENV NHANES_DB_BACKEND="postgres"

RUN echo "EPICONDUCTOR_CONTAINER_DB=$NHANES_DB_BACKEND" >> /usr/local/lib/R/etc/Renviron.site
RUN echo "NHANES_DB_BACKEND=$NHANES_DB_BACKEND" >> /usr/local/lib/R/etc/Renviron.site

RUN echo "EPICONDUCTOR_CONTAINER_DB=$NHANES_DB_BACKEND" >> /etc/environment
RUN echo "NHANES_DB_BACKEND=$NHANES_DB_BACKEND" >> /etc/environment

#------------------------------------------------------------------------------
# Install nhanesA + phonto for end-users
#------------------------------------------------------------------------------

# use the remotes package to manage installations
RUN Rscript -e "install.packages('remotes')"

RUN service postgresql start \
    && sleep 5 \
    && Rscript -e "remotes:: install_github('deepayan/nhanes')" \
    && Rscript -e "remotes:: install_github('ainilaha/phonto', dependencies = TRUE)" \
#    && Rscript -e "remotes:: install_github('ainilaha/phonto', dependencies = TRUE, build_opts = '')" \
    && service postgresql stop


## allow modification of these locations so users can install R packages without warnings.
## Configure postgres to accept connections over the network. 
## TODO: We may also want to make such connections read-only

RUN chmod -R 777 /usr/local/lib/R/library \
    && chmod -R 777 /usr/local/lib/R/site-library \
    && chmod -R 777 /usr/local/lib/R/doc/html/packages.html \
    # Ensure PostgreSQL listens on all interfaces
    && sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/16/main/postgresql.conf \
    # Allow all IP addresses to connect to PostgreSQL (this affects both all and replication)
    && sed -i "s/127.0.0.1\/32/0.0.0.0\/0/" /etc/postgresql/16/main/pg_hba.conf

## OR
## RUN echo "host all all 0.0.0.0/0 scram-sha-256" >> /etc/postgresql/16/main/pg_hba.conf

# Ports available for mapping

# EXPOSE 22   # ssh
# EXPOSE 8787 # RStudio Server
# EXPOSE 5432 # PostgreSQL

# Point nhanesA to local copies of HTML documentation

RUN echo "NHANES_TABLE_BASE=/htmldoc" >> /usr/local/lib/R/etc/Renviron.site \
    && echo "NHANES_TABLE_BASE=/htmldoc" >> /etc/environment \
    && mkdir /htmldoc/Nchs && ln -s /htmldoc /htmldoc/Nchs/Nhanes

# Create a mount point for host filesystem data and copy startup script
RUN mkdir /HostData && mkdir -p /startup
COPY Container/startup.sh /startup/startup.sh
RUN chmod 700 /startup/startup.sh

CMD ["/startup/startup.sh"]

# Local Variables:
# mode: sh
# End:
