#!/bin/bash

#==============================================================================
# Iper_API.sh
#==============================================================================
# Version: 0.9
# Requires: tr, cut, awk, sort, md5sum, curl, hexdump
#==============================================================================

IPERAPIURL=http://api.ipernity.com/api
IPERAUTHURL=http://www.ipernity.com/apps/authorize

#==============================================================================
# Misc functions
#==============================================================================

# url_encode <STRING>
# Returns an URL encoded string

function url_encode() {
  echo -n $* | hexdump -v -e '1/1 "%02x\t"' -e '1/1 "%_c\n"' | awk '
    $1 == "20" { printf("%s", "+"); next }
    $2 ~ /^[a-zA-Z0-9.*()\/-]$/ { printf("%s", $2); next }
    { printf("%%%s", $1) } '
}

# sign_request <STRING>
# Returns an MD5 of <STRING>

function sign_request() {
  echo -n $* | md5sum | awk ' { print $1 } '
}

# post_request <URL> <POSTDATA>
# Returns an HTTP response

function post_request() {
  URL=$1
  DATA="$2"
  curl -d "$DATA" $URL 2>/dev/null
  if [ $? -ne 0 ]; then echo "curl error $?"; fi
}

# upload_file <URL> <POSTDATA> <FILE>
# Returns an HTTP response

function upload_file() {
  URL="$1"
  DATA="$2"
  FILE="$3"
  PARAMS="-F \"file=@$FILE\""
  IFS="&"
  for PARAM in $DATA
    do
    PARAMS="$PARAMS -F \"$PARAM\""
    done
  IFS=" "
  eval `echo curl $PARAMS $URL 2>/dev/null`
  if [ $? -ne 0 ]; then echo "curl error $?"; fi
}

#==============================================================================
# call_api_method <APIKEY> <APISECRET> <APIFORMAT> <METHOD> [<PARAMS>...]
#==============================================================================
# Generate a POST request for method <METHOD> with optional parameters 
# <PARAMS> and expect the response in format <APIFORMAT>
# For options that takes strings as parameters, url_encode them first
# eg. title=`url_encode "Hello World"`
#==============================================================================

function call_api_method() {

  APIKEY=$1; shift
  APISECRET=$1; shift
  APIFORMAT=$1; shift
  METHOD=$1; shift

  URL="${IPERAPIURL}/${METHOD}/${APIFORMAT}"

  # Sort the params, and urlencode the subparams (right of the '=')
  SORTED=`(echo api_key=${APIKEY}; for ((i=1; i<=$#; i++)); do eval echo \\\$$i; done) | sort |
    while read PARAM
      do
        LEFT=\`echo $PARAM= | cut -d= -f1\`
        RIGHT=\`echo $PARAM= | cut -d= -f2 | tr "+" " "\`
        if [ $METHOD = "upload.file" -a $LEFT = "file" ]; then continue; fi
        if [ -z "$RIGHT" ]; then
          echo $LEFT
        else
          echo -n $LEFT=
          IFS=","
          for p in $RIGHT 
            do
              echo -n \`url_encode "$p"\`,
            done | awk -F, '
              { for (i=1; i<NF-1; i++) printf("%s,", $i); print $(NF-1) } '
          IFS=" "
        fi
      done | tr "\n" " "`

  # Trim the params for the signing part and prepare them for the POST
  REQ_PARAMS=`echo -n "$SORTED" | tr -d "= " | tr "+" " "`
  URL_PARAMS=`echo -n "$SORTED" | tr " " "&"`

  # Sign the request
  SIGNATURE=`sign_request ${REQ_PARAMS}${METHOD}${APISECRET}`

  # Lauch the request
  if [ $METHOD = "upload.file" ]; then
    FILE=`for ((i=1; i<=$#; i++)); do eval echo \\\$$i; done | grep "^file=" | cut -d= -f2`
    upload_file "${URL}" "${URL_PARAMS}api_sig=${SIGNATURE}" "$FILE"
  else
    post_request "${URL}" "${URL_PARAMS}api_sig=${SIGNATURE}"
  fi

}

#==============================================================================
# get_user_auth <APIKEY> <APISECRET> <FROB> <PERMISSION> [<PERMISSION>...]
#==============================================================================
# Generate an URL where the user will be asked to grant these <PERMISSION>s
#==============================================================================

function get_user_auth() {

  APIKEY=$1; shift
  APISECRET=$1; shift
  FROB=$1; shift

  # Sort the permissions, trim them for the signing part and prepare them for
  # the POST
  PARAMS=`echo "api_key=${APIKEY} frob=$FROB $*" | tr " " "\n" | sort | tr "\n" " "`
  REQ_PARAMS=`echo -n "$PARAMS" | tr -d "= "`
  URL_PARAMS=`echo -n "$PARAMS" | tr " " "&"`

  # Sign the request
  SIGNATURE=`sign_request ${REQ_PARAMS}${APISECRET}`

  # Generate the URL
  echo "${IPERAUTHURL}?${URL_PARAMS}&api_sig=${SIGNATURE}"

}
