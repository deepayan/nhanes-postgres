#
# Container image with NHANES data inside a Postgres database
# Author: Deepayan Sarkar

## Build / run: See README.md

# rocker/r-base is Debian unstable, whereas rocker/r-ver|tidyverse is
# Ubuntu LTS (better for our purposes)

## has more stuff built-in, including RStudio server, DBI, etc, but no arm64 support

FROM rocker/tidyverse:4.4

# FROM rocker/r-ver:4.4

# TODO: See <https://eddelbuettel.github.io/r2u/> to get binary packages

#------------------------------------------------------------------------------
# Basic initial system configuration
#------------------------------------------------------------------------------

USER root

# install standard Ubuntu Server packages --- WHY?
# RUN yes | unminimize

# we're going to create a non-root user at runtime and give the user sudo
RUN apt-get update && \
	apt-get -y install sudo \
	&& echo "Set disable_coredump false" >> /etc/sudo.conf
	
# set locale info
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
	&& apt-get update && apt-get install -y locales \
	&& locale-gen en_US.utf8 \
	&& /usr/sbin/update-locale LANG=en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV TZ=America/New_York

WORKDIR /tmp

#------------------------------------------------------------------------------
# Install system tools and libraries via apt
#------------------------------------------------------------------------------

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install \
	       -y \
	       ca-certificates \
	       curl \
	       less \
	       libgomp1 \
	       libpango-1.0-0 \
	       libxt6 \
	       libsm6 \
	       make \
	       texinfo \
	       texlive-latex-base \
	       texlive-latex-recommended \
	       fonts-noto \
	       libtiff-dev \
	       libpng-dev \
	       libicu-dev \
	       libpcre3 \
	       libpcre3-dev \
	       libbz2-dev \
	       liblzma-dev \
	       gcc \
	       g++ \
	       openjdk-8-jre \
	       openjdk-8-jdk \
	       gfortran \
	       libreadline-dev \
	       libx11-dev \
	       libcurl4-openssl-dev \
	       libssl-dev \
	       libxml2-dev \
	       wget \
	       openssh-server \
	       ssh \
	       xterm \
	       xauth \
	       screen \
	       git \
	       libgit2-dev \
	       nano \
	       emacs \
	       gnupg \
	       krb5-user \
	       python3-dev \
	       python3 \
	       python3-pip \
	       libaio1 \
	       pkg-config \
	       libkrb5-dev \
	       unzip \
	       cifs-utils \
	       lsof \
	       libnlopt-dev \
	       libopenblas-openmp-dev \
	       libpcre2-dev \
	       systemd \
	       libcairo2-dev \
	       libharfbuzz-dev \
	       libfribidi-dev \
	       cmake \
	       qpdf \
	       postgresql postgresql-client phppgadmin libpq-dev \
    && rm -rf /var/lib/apt/lists/*

#------------------------------------------------------------------------------
# Configure system tools
#------------------------------------------------------------------------------

# required for ssh and sshd	
RUN mkdir /var/run/sshd	

# enable password authedtication over SSH
RUN sed -i 's!^#PasswordAuthentication yes!PasswordAuthentication yes!' /etc/ssh/sshd_config

# configure X11
RUN sed -i "s/^.*X11Forwarding.*$/X11Forwarding yes/" /etc/ssh/sshd_config \
    && sed -i "s/^.*X11UseLocalhost.*$/X11UseLocalhost no/" /etc/ssh/sshd_config \
    && grep "^X11UseLocalhost" /etc/ssh/sshd_config || echo "X11UseLocalhost no" >> /etc/ssh/sshd_config	

# tell git to use the cache credential helper and set a 1 day-expiration
RUN git config --system credential.helper 'cache --timeout 86400'

#------------------------------------------------------------------------------
# Install DBI and RPostgres
#------------------------------------------------------------------------------

# use the remotes package to manage installations
RUN Rscript -e "install.packages('remotes')" \
    && Rscript -e "remotes :: install_cran('DBI')" \
    && Rscript -e "remotes :: install_cran('RPostgres')"


#------------------------------------------------------------------------------
# Set up SQL Server, download and insert metadata + raw tables
#------------------------------------------------------------------------------

RUN mkdir /status
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
# Install nhanesA and phonto + misc other packages that might be useful
#------------------------------------------------------------------------------

# use the remotes package to manage installations
RUN Rscript -e "install.packages('remotes')" \
    && Rscript -e "remotes :: install_github('cjendres1/nhanes@postgres-backend')" \
    && Rscript -e "remotes :: install_github('ainilaha/phonto')"


# use the remotes package to manage installations
RUN Rscript -e "install.packages(c('git2r', 'getPass', 'xlsx', 'forestplot', 'glmnet', 'glmpath', 'kableExtra', 'plotROC', 'sjPlot', 'survey', 'mitools', 'bookdown', 'lme4', 'survminer', 'DT', 'Hmisc', 'latticeExtra'))"


# # allow modification of these locations so users can install R packages without warnings
RUN chmod -R 777 /usr/local/lib/R/library
RUN chmod -R 777 /usr/local/lib/R/site-library
RUN chmod -R 777 /usr/local/lib/R/doc/html/packages.html

## env variables identifying container (FIXME: get collection date from snapshot on GitHub)
ENV EPICONDUCTOR_CONTAINER_DB postgres
ENV EPICONDUCTOR_CONTAINER_VERSION v0.9.0
ENV EPICONDUCTOR_COLLECTION_DATE 2024-02-12

RUN echo "EPICONDUCTOR_CONTAINER_DB=$EPICONDUCTOR_CONTAINER_DB" >> /usr/local/lib/R/etc/Renviron.site
RUN echo "EPICONDUCTOR_CONTAINER_VERSION=$EPICONDUCTOR_CONTAINER_VERSION" >> /usr/local/lib/R/etc/Renviron.site
RUN echo "EPICONDUCTOR_COLLECTION_DATE=$EPICONDUCTOR_COLLECTION_DATE" >> /usr/local/lib/R/etc/Renviron.site

RUN echo "EPICONDUCTOR_CONTAINER_DB=$EPICONDUCTOR_CONTAINER_DB" >> /etc/environment
RUN echo "EPICONDUCTOR_CONTAINER_VERSION=$EPICONDUCTOR_CONTAINER_VERSION" >> /etc/environment
RUN echo "EPICONDUCTOR_COLLECTION_DATE=$EPICONDUCTOR_COLLECTION_DATE" >> /etc/environment


## Configure postgres to accept connections over the network. TODO: We
## may also want to make such connections read-only

# Ensure PostgreSQL listens on all interfaces
RUN sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/14/main/postgresql.conf

# Allow all IP addresses to connect to PostgreSQL (this affects both all and replication)
RUN sed -i "s/127.0.0.1\/32/0.0.0.0\/0/" /etc/postgresql/14/main/pg_hba.conf

## OR
## RUN echo "host all all 0.0.0.0/0 scram-sha-256" >> /etc/postgresql/14/main/pg_hba.conf

# Ports available for mapping

# EXPOSE 22   # ssh
# EXPOSE 8787 # RStudio Server
# EXPOSE 5432 # PostgreSQL

# # Copy startup script
RUN mkdir /startup
COPY Container/startup.sh /startup/startup.sh
RUN chmod 700 /startup/startup.sh

# Create a mount point for host filesystem data
RUN mkdir /HostData

CMD ["/startup/startup.sh"]

# Local Variables:
# mode: sh
# End:
