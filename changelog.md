
# Change Log

All notable changes to this project will be documented in this
file. No changelog was maintained till version 0.10.1.

## Changes in version 0.10.1

### Added

- New files `COLLECTION_DATE` and `CONTAINER_VERSION` to record
  release information

- Newly released upstream data from NHANES August 2021-23 cycle have
  been included in the release.

- The vignettes of the phonto package are now installed. These are
  built during install time, and hence require the nhanesA package to
  be configured to use the database before this happens. The sequence
  of events in the docker file have been suitably rearranged.

 
### Changed

- Moved to using container version as docker version

- Use metadata from the
  [nhanes-snapshot](https://github.com/deepayan/nhanes-snapshot)
  repository, which is generated directly from the HTML doc
  files. This removes the earlier additional dependency on 
  [NHANES-metadata](https://github.com/ccb-hms/NHANES-metadata)

### Pending

- Include collection date and other relevant metadata in a metadata
  table in the database.
  
- Update `nhanesA::browseNHANES()` to use local copies of doc files if
  available.

- Investigate database insertion errors

- Add primary keys for metadata tables

