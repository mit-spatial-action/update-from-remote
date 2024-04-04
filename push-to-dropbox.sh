#!/bin/sh

# This script pushes file with the most recent modified date to Dropbox.
# Requires a Dropbox Application Access Token.

DBTOKEN=''

while getopts "d:" flag; do
    case $flag in
        d)
        # Dropbox App Access Token
        DBTOKEN="$OPTARG"
        ;;
    esac
done

if [[ -z "$DBTOKEN" ]]; then
    echo "You must provide a Dropbox Application Access Token."
    exit 1
fi

LOG_CSV="log.csv"

MOD_LAST_EP=$(tail -1 "$LOG_CSV" | awk -F',' '{print $5}')

FILE=$(find . -type f -iname "$MOD_LAST_EP*")

MB=$(du -m "$FILE" | grep -o -E "^[0-9]+")

if [ MB > 150 ]; then
    split $FILE
fi

# echo "Pushing to Dropbox archive."
# curl -X POST https://content.dropboxapi.com/2/files/upload \
#     --header "Authorization: Bearer $DBTOKEN" \
#     --header "Dropbox-API-Arg: {\"path\": \"/Archive/$FILE\", \"mode\": \"overwrite\", \"strict_conflict\": false}" \
#     --header "Content-Type: application/octet-stream" \
#     --data-binary @"$FILE"