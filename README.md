Github Dependency Analyzer for Java
-----------

This repository contains two tools for analyzing dependency data for Java projects. One tool deals with mining the data from Github. The other tool analyzes the downloaded dependency data and provides several statistics.

The folder *github-data* contains Java build file data mined from Github on 05-30-2015.

Github Miner
--------------------

The bash script *github-miner.sh* downloads Java build files from Github for projects created withing a specified date range. The script takes three parameters:

* A date range
* Github username:password
* Extra search parameters

Github's search API is limited to thousand results per query, therefore a large date range cannot be queried at once. Fortunately the script will automatically and dynamically partition the specified date range into sub-ranges in order to retrieve all data. Depending on the range this might take some time.

The downloaded data is stored in *./data* (relative to where the script is being executed). If a project has multiple dependency files, they are combined in one single file (e.g. all pom.xml's are unified into a file called *{projectName}*.poms).

The following is an example to download dependency data from Java projects created from 2007 until 20014 that have at least one commit since januari 2013. See https://developer.github.com/v3/search/#search-repositories for all possible search filters.

```bash
./mine-data.sh 20070101 20140101 username:password "pushed:>=2013-01-01+language:java" | tee ./mining.log
```

Java Dependency Data Analyzer
-------------------

The dependency analyzer is written in [Rascal](http://www.rascal-mpl.org/).


More coming soon...
