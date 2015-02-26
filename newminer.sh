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
CURL_CMD="curl --silent -A \"MasterThesisMiner-2.0\" -u $AUTH"

#echo "s:$DATE_S, e:$DATE_E, diff:$DATE_DIFF"

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
  local __to_file=$4

  for sha in ${__shas[@]}
  do
    echo "    $sha"
    curl --silent https://raw.githubusercontent.com/${__project}/master/${sha}  >> "${__to_file}"
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
  local __curl=$1
  local __url=$2
  echo "PROCESS: $__url"
  DATA=$($__curl ${__url})
  FOLDER=$(echo $DATA | grep -Po 'created_at":\s?"\K\d{4}\-\d{2}\-\d{2}')
  PROJECT=$(echo $__url | cut -c30-)
  NAME=$(echo $PROJECT | sed s:\/:_:g)
  echo "${__url} - $NAME - $PROJECT"
  if fexists "./data/${FOLDER}/${NAME}**"
  then
    echo "    Skipping..."
  else
    mkdir ./data/${FOLDER}/ > /dev/null
    DATA=$($__curl ${__url}/git/refs/heads/master)
    NF=$(echo $DATA | grep -o "Not Found")
    if [ "$NF" == "Not Found" ]
    then
      DATA=$($__curl ${__url}/git/refs/heads/trunk)
      NF=$(echo $DATA | grep -o "Not Found")
      if [ "$NF" == "Not Found" ]; then echo "unable to determine head branch!"; fi
    fi
    SHA=$(echo $DATA | grep -P -o '[a-z0-9]{20,}' | head -n 1)
    $__curl ${__url}/git/trees/${SHA}?recursive=1 > "./data/${FOLDER}/${NAME}.trees"

    PSHAS=($(find_by_ext "./data/${FOLDER}/${NAME}.trees" "pom.xml"))
    download PSHAS[@] $PROJECT "$__url" "./data/${FOLDER}/${NAME}.poms"

    GSHAS=($(find_by_ext "./data/${FOLDER}/${NAME}.trees" "build.gradle"))
    download GSHAS[@] $PROJECT "$__url" "./data/${FOLDER}/${NAME}.gradles"

    BSHAS=($(find_by_ext "./data/${FOLDER}/${NAME}.trees" "build.xml"))
    download BSHAS[@] $PROJECT "$__url" "./data/${FOLDER}/${NAME}.buildxmls"

    IFILES=($(find_by_ext "./data/${FOLDER}/${NAME}.trees" "ivy.xml"))
    download IFILES[@] $PROJECT "$__url" "./data/${FOLDER}/${NAME}.ivys"

    if [ ${#PSHAS[@]} -eq 0 ] && [ ${#GSHAS[@]} -eq 0 ] && [ ${#BSHAS[@]} -eq 0 ] && [ ${#IFILES[@]} -eq 0 ]
    then
      echo "    No build files found!"
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
    echo "request for range: $_range, interval: $(($_interval/60/60/24)) days"
    _url="https://api.github.com/search/repositories?q=created:$_range+$CRITERIA&per_page=100&page=1"
    echo "request: $_url"
    DATA=$($CURL_CMD $_url)
    total=$(echo $DATA | grep -Po 'total_count\":\s?\K[\d]+')
    echo "results: $total"

    # interval correction
    if [ $total -gt 1000 ]; then
      # reduce interval by half
      echo "decreasing interval: too many results"; _interval=$(($_interval/2));
    elif [ $total -lt 500 ]; then
      # increase interval with half of current interval
      echo "increasing interval"; _interval=$(($_interval+($_interval/2)))
    fi
  done

  processed=0
  page=2
  while [ $processed -lt $total ]; do
    urls=($(echo $DATA | grep -P -o '"url":"\Khttps://api.github.com/repos[\w\-_\/\.0-9]+'))
    urlcount=${#urls[@]}
    echo "urls: $urlcount"

    parallel -j 4 process "'$CURL_CMD'" ::: ${urls[@]}

    #for url in ${urls[@]}; do
    #  process $url
    #done

    processed=$(($processed+$urlcount))

    # fetch next page
    _url="https://api.github.com/search/repositories?q=created:$_range+$CRITERIA&per_page=100&page=$page"
    echo "request: $_url"
    DATA=$($CURL_CMD $_url)
    page=$(($page+1))
  done

  _x=$_e
done
