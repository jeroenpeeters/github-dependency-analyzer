
This project contains a script to download Java build files (pom.xml, build.gradle, ivy.xml) from Github. Secondly it contains a Rascal application to analyze the downloaded data.

Download Github Data
====================

The bash script *mine-data* downloads Java build files from Github. The script takes two parameters:

    * A project creation date range
    * A Github username:password
    
The script is setup to download build files from projects that have at least one commit since 2013-01-01. This assures that we only take into account ***active*** projects.
Github's search API is limited to thousand results per query. As a consequence I added a project creation data range. One needs to accertain that less than thousand results are returned by adapting the date range.

The following is an example to download projects created in the year 2010.
```bash
./mine-data "2010-01-01..2010-12-30" username:password | tee ./data/2010.log
```

Build File Analyzer
===================

tbd....
