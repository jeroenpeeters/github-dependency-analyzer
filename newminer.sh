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
  echo "   CRITERIA     Additional filtering criteria (https://developer.github.com/v3/search/#search-repositories)"
  exit 1
}
if [ $# -lt 4 ]; then
  usage
fi

DATE_S="$(date -d $1 +%s)"
DATE_E="$(date -d $2 +%s)"
DATE_DIFF=$(($DATE_E-$DATE_S))
AUTH=$3
CRITERIA=$4
CURL_CMD="curl --silent -A \"MasterThesisMiner-2.0\" -u $AUTH"

echo "s:$DATE_S, e:$DATE_E, diff:$DATE_DIFF"

# partition the time into parts of one month

_interval=2629743
_x=$DATE_S
while [ $_x -lt $DATE_E ]; do
  _e=$(($_x+$_interval))
  if [ $_e -gt $DATE_E ]; then
    _e=$DATE_E
  fi
  _range="$(date -d @$_x +%Y-%m-%d)..$(date -d @$_e +%Y-%m-%d)"
  echo "_x:$_x, _e:$_e, $_range"
  _url="https://api.github.com/search/repositories?q=created:$_range+$CRITERIA&per_page=100&page=$page"
  echo $_url
  DATA=$($CURL_CMD $_url)
  echo $(echo $DATA | grep -Po 'total_count\":\s?\K[\d]+')
  #echo $DATA > ./tmp
  _x=$_e
done
