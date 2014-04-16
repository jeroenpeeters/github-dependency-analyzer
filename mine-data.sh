#!/bin/bash

DATE_RANGE=$1

CURL_CMD="curl --silent -A \"MasterThesisMiner\" -u jeroen@peetersweb.nl:FUffjTD7WstuBtPkxh5k"

function find_shas_by_filetype {
  local __data=$1
  local __ext=$2
  echo $__data | grep -P -o "[a-z0-9]{20,}\",\s+\"path\":\s?\"[\w\/\-_]*${__ext}" | grep -P -o '[a-z-0-9]{20,}'
}

function find_by_ext {
  local __data=$1
  local __ext=$2
  echo $__data | grep -P -o "path\":\"[\w\/\-_]*${__ext}" | cut -c8-
}

function download {
  declare -a __shas=("${!1}")
  local __project=$2
  local __url=$3
  local __to_file=$4

  for sha in ${__shas[@]}
  do
    #$CURL_CMD ${__url}/git/blobs/${sha} | grep -P -o '"content":\s"[\w\\n\+\=\/]+' | cut -c13- | sed 's/\\n//g' | base64 -d  >> "${__to_file}"
    echo "    $sha"
    curl --silent https://raw.githubusercontent.com/${__project}/master/${sha}  >> "${__to_file}"
  done
}

function fexists {
  local __file=$1
  COUNT=$(ls -A $__file 2> /dev/null | grep -c .)
  [ $COUNT -gt 0 ]
}

FOLDER=$(echo $DATE_RANGE | sed 's:\.\.:_:g')
mkdir -p ./data/$FOLDER/

TOTAL_RESULTS=1
NUM_PROCESSED=0
NUM_URLS=1
page=1
while [ $TOTAL_RESULTS -gt $NUM_PROCESSED ] && [ $NUM_URLS -gt 0 ]
do
  # Download
  DATA=$($CURL_CMD "https://api.github.com/search/repositories?q=created:$DATE_RANGE+pushed:>=2013-01-01+language:java+stars:>10&per_page=100&page=$page")
  TOTAL_RESULTS=$(echo $DATA | grep -P -o '"total_count":?\d+' | grep -P -o '\d+')
  # Parse project URLS
  echo "Totalresults: $TOTAL_RESULTS"
  URLS=($(echo $DATA | grep -P -o '"url":"https://api.github.com/repos[\w\-_\/\.]+"' | grep -P -o 'https://api.github.com/repos[\w\-_\/]+'))
  NUM_URLS=${#URLS[@]}
  NUM_PROCESSED=$(($NUM_PROCESSED + $NUM_URLS))
  ((page++))
  
  for url in ${URLS[@]}
  do
    PROJECT=$(echo $url | cut -c30-)
    NAME=$(echo $PROJECT | sed s:\/:_:g)
    echo "${url} - $NAME - $PROJECT"
    if fexists "./data/${FOLDER}/${NAME}**"
    then
      echo "    Skipping..."
    else
      DATA=$($CURL_CMD ${url}/git/refs/heads/master)
      NF=$(echo $DATA | grep -o "Not Found")
      if [ "$NF" == "Not Found" ]
      then
        DATA=$($CURL_CMD ${url}/git/refs/heads/trunk)
      fi
      SHA=$(echo $DATA | grep -P -o '[a-z0-9]{20,}' | head -n 1)
      DATA=$($CURL_CMD ${url}/git/trees/${SHA}?recursive=1)
    
      PSHAS=($(find_by_ext "$DATA" "pom.xml"))
      download PSHAS[@] $PROJECT "$url" "./data/${FOLDER}/${NAME}.poms"

      GSHAS=($(find_by_ext "$DATA" "build.gradle"))
      download GSHAS[@] $PROJECT "$url" "./data/${FOLDER}/${NAME}.gradles"

      BSHAS=($(find_by_ext "$DATA" "build.xml"))
      download BSHAS[@] $PROJECT "$url" "./data/${FOLDER}/${NAME}.buildxmls"

      IFILES=($(find_by_ext "$DATA" "ivy.xml"))
      download IFILES[@] $PROJECT "$url" "./data/${FOLDER}/${NAME}.ivys"

      if [ ${#PSHAS[@]} -eq 0 ] && [ ${#GSHAS[@]} -eq 0 ] && [ ${#BSHAS[@]} -eq 0 ] && [ ${#IFILES[@]} -eq 0 ]
      then
        echo "    No build files found!"
        touch "./data/${FOLDER}/${NAME}.nobuild"
      fi
    fi
  done
done 

echo "URLS processed: $NUM_PROCESSED"
exit 0

