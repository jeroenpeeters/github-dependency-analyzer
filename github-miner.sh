#!/bin/bash

#
# Mines dependency data from Github projects
#

me=`basename $0`
function usage(){
  echo "Usage: $me [BEGIN DATE] [END DATE] [USER]:[PASSWORD] [CRITERIA]"
  echo "Mines dependency data from Github"
  echo ""
  echo "Mandatory arguments:"
  echo "   BEGIN DATE   The start of the mining window"
  echo "   END DATE     The end of the mining window"
  echo "   USER         A Github user account"
  echo "   PASSWORD     The password"
  echo ""
  echo "Optional arguments:"
  echo "   CRITERIA     Additional filtering criteria (https://developer.github.com/v3/search/#search-repositories)"
  echo ""
  echo "Example: $me 20070101 20140101 username:password \"pushed:>=2013-01-01+language:java+stars:>1\""
  exit 1
}
if [ $# -lt 3 ]; then
  usage
fi

DATE_S="$(date -d $1 +%s)"
DATE_E="$(date -d $2 +%s)"
DATE_DIFF=$(($DATE_E-$DATE_S))
AUTH=$3
CRITERIA=$4
CURL_CMD="curl --silent -i -A \"MasterThesisMiner-2.0\" -u $AUTH"
export CURL_CMD

function curl_do {
  local __url=$1
  #echo "CURLCMD:: $CURL_CMD, $__url"
  data=$($CURL_CMD $__url)
  rateLimitRemaining=$(echo $data |  grep -P -o 'X-RateLimit-Remaining:\s?\K[0-9]+')
  rateLimitReset=$(echo $data |  grep -P -o 'X-RateLimit-Reset:\s?\K[0-9]+')
  secondsTillReset=$(($rateLimitReset-`date +%s`))

  #echo "RateLimitInfo $rateLimitRemaining, $rateLimitReset, $secondsTillReset"
  if [ $secondsTillReset -lt 1 ]; then
    #echo "[RATE LIMIT]    Waiting $secondsTillReset seconds"
    #echo "                -> $__url"
    sleep "$secondsTillReset"
    echo $(curl_do $__url)
  fi
  echo $data
}
export -f curl_do

function find_by_ext {
  local __treesfile=$1
  local __ext=$2
  echo $(grep -P -o "path\":\"\K[\w\/\-_]*${__ext}" $__treesfile)
}
export -f find_by_ext

function download {
  declare -a __shas=("${!1}")
  local __project=$2
  local __url=$3
  local __branch=$4
  local __to_file=$5

  for sha in ${__shas[@]}
  do
    #echo "    $sha"
    curl --silent https://raw.githubusercontent.com/${__project}/${__branch}/${sha}  >> "${__to_file}"
  done
}
export -f download

function fexists {
  local __file=$1
  COUNT=$(ls -A $__file 2> /dev/null | grep -c .)
  [ $COUNT -gt 0 ]
}
export -f fexists

function process {
  local __url=$1
  echo "[PROCESS]          $__url"
  DATA=$(curl_do ${__url})
  FOLDER=$(echo $DATA | grep -Po 'created_at":\s?"\K\d{4}\-\d{2}\-\d{2}')
  PROJECT=$(echo $__url | cut -c30-)
  NAME=$(echo $PROJECT | sed s:\/:_:g)
  BRANCH="master"
  if fexists "./data/${FOLDER}/${NAME}**"
  then
    echo "      -> Already downloaded, Skipping..."
  else
    mkdir ./data/${FOLDER}/ > /dev/null
    DATA=$(curl_do ${__url}/git/refs/heads/master)
    NF=$(echo $DATA | grep -o "Not Found")
    echo "refs data ::: $NF :::: -> $DATA"
    if [ "$NF" != "" ]; then
      DATA=$(curl_do ${__url}/git/refs/heads/trunk)
      NF=$(echo $DATA | grep -o "Not Found")
      BRANCH="trunk"
      if [ "$NF" == "Not Found" ]; then echo "      -> Unable to determine head branch!"; fi
    fi
    SHA=$(echo $DATA | grep -P -o '"sha":"\K[a-z0-9]{20,}' | head -n 1)

    echo $DATA > "./data/${FOLDER}/${NAME}.headsInfo"

    # download folder tree to file
    curl_do ${__url}/git/trees/${SHA}?recursive=1 > "./data/${FOLDER}/${NAME}.tree"

    PSHAS=($(find_by_ext "./data/${FOLDER}/${NAME}.tree" "pom.xml"))
    download PSHAS[@] $PROJECT "$__url" "$BRANCH" "./data/${FOLDER}/${NAME}.poms"

    GSHAS=($(find_by_ext "./data/${FOLDER}/${NAME}.tree" "build.gradle"))
    download GSHAS[@] $PROJECT "$__url" "$BRANCH" "./data/${FOLDER}/${NAME}.gradles"

    BSHAS=($(find_by_ext "./data/${FOLDER}/${NAME}.tree" "build.xml"))
    download BSHAS[@] $PROJECT "$__url" "$BRANCH" "./data/${FOLDER}/${NAME}.buildxmls"

    IFILES=($(find_by_ext "./data/${FOLDER}/${NAME}.tree" "ivy.xml"))
    download IFILES[@] $PROJECT "$__url" "$BRANCH" "./data/${FOLDER}/${NAME}.ivys"

    if [ ${#PSHAS[@]} -eq 0 ] && [ ${#GSHAS[@]} -eq 0 ] && [ ${#BSHAS[@]} -eq 0 ] && [ ${#IFILES[@]} -eq 0 ]
    then
      echo "      -> No build files found!"
      touch "./data/${FOLDER}/${NAME}.nobuild"
    fi
  fi
}
export -f process

function join { local IFS="$1"; shift; echo "$*"; }


_interval=$((2629743*6)) #initial optimistic interval: one month*6
_x=$DATE_S
while [ $_x -lt $DATE_E ]; do # loop through the date intervals, traverses time
  total=99999
  _e=0
  while [ $total -gt 1000 ]; do # find proper upper limit
    _e=$(($_x+$_interval))
    if [ $_e -gt $DATE_E ]; then #if computed end date is larger than requested
      _e=$DATE_E
    fi
    _range="$(date -d @$_x +%Y-%m-%d)..$(date -d @$_e +%Y-%m-%d)"
    echo "[RANGE]            request for range: $_range, interval: $(($_interval/60/60/24)) days"
    _url="https://api.github.com/search/repositories?q=created:$_range+$CRITERIA&per_page=100&page=1"
    DATA=$(curl_do $_url)
    total=$(echo $DATA | grep -Po 'total_count\":\s?\K[\d]+')

    # interval correction
    if [ $total -gt 1000 ]; then
      # reduce interval by half
      echo "      -> decreasing interval: too many results"; _interval=$(($_interval/2));
    elif [ $total -lt 500 ]; then
      # increase interval with half of current interval
      echo "      -> increasing interval"; _interval=$(($_interval+($_interval/2)))
    fi
  done

  processed=0
  page=2
  while [ $processed -lt $total ]; do
    urls=($(echo $DATA | grep -P -o '"url":"\Khttps://api.github.com/repos[\w\-_\/\.0-9]+'))
    urlcount=${#urls[@]}

    parallel -j 4 process ::: ${urls[@]}
    processed=$(($processed+$urlcount))

    # fetch next page
    _url="https://api.github.com/search/repositories?q=created:$_range+$CRITERIA&per_page=100&page=$page"
    DATA=$(curl_do $_url)
    page=$(($page+1))
  done

  _x=$_e
done
