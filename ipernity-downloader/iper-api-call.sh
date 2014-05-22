#!/bin/bash

self=$(basename $0)


usage() {
    echo "Usage: $self -k KEY -s SECRET [-t TOKEN] [-f FROB] CALL [PARAM...]"
}

if (( $# < 2 )); then
    usage
    exit 1
fi

while getopts k:s:t:f: OPT; do
    case $OPT in
        k)
            KEY=$OPTARG
            ;;
        s)
            SECRET=$OPTARG
            ;;
        t)
            TOKEN=$OPTARG
            ;;
        f)
            FROB=$OPTARG
            ;;
        ?)
            usage
            exit 1
            ;;
    esac
done

shift $(( OPTIND - 1 ))

. ./Iper_API.sh

APIKEY="$KEY"
APISECRET="$SECRET"
APIFORMAT="json"

if [ -z "$APIKEY" ]; then
    echo "$self: No API key specified"
    usage
    exit 1
elif [ -z "$APISECRET" ]; then
    echo "$self: No API secret specified"
    usage
    exit 1
fi



CALL="$1"
shift

if [ -z "$CALL" ]; then
    echo "$self: Error: no call given"
    usage
    exit 1
fi

case $CALL in
    get-frob)
        call_api_method $APIKEY $APISECRET $APIFORMAT auth.getFrob
        echo
        ;;
    get-user-auth)
        if [ -z "$FROB" ]; then
            echo "$self: get-user-auth requires a frob"
            usage
            exit 1
        fi
        get_user_auth $APIKEY $APISECRET $FROB perm_doc=read
        echo
        ;;
    get-token)
        if [ -z "$FROB" ]; then
            echo "$self: get-token requires a frob"
            usage
            exit 1
        fi
        call_api_method $APIKEY $APISECRET $APIFORMAT auth.getToken frob=$FROB
        echo
        ;;
    *)
        if [ -z "$TOKEN" ]; then
            echo "$self: $CALL requires a token"
            usage
            exit 1
        fi
        call_api_method $APIKEY $APISECRET $APIFORMAT \
            $CALL auth_token=$TOKEN $*
        echo
        ;;
esac
