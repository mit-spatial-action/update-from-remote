#!/bin/sh

# This script pushes file with the most recent modified date to Dropbox.
# Requires a Dropbox Application Access Token.

dbtoken=''
out_path=''

while getopts "d:o:" flag; do
    case $flag in
        d)
        # Dropbox App Access Token
        dbtoken="$OPTARG"
        ;;
        o)
        out_path="$OPTARG"
        ;;
    esac
done

if [[ -z "$dbtoken" ]]; then
    echo "You must provide a Dropbox Application Access Token."
    exit 1
fi

if [[ -z "$out_path" ]]; then
    echo "You must provide an output path."
    exit 1
fi

log_csv="log.csv"

mod_last_ep=$(tail -1 "$log_csv" | awk -F',' '{print $5}')

file=$(find . -type f -iname "$mod_last_ep*")
filename=$(basename "$file")

mb=$(du -m "$file" | grep -o -E "^[0-9]+")

if [ mb -ge 150 ]; then
    echo "File is larger than Dropbox's payload limit for upload endpoint. Splitting file and starting upload session." 

    split --bytes=150M "$file" chunk
    # Open an upload session with first chunk...
    content=$(curl -X POST https://content.dropboxapi.com/2/files/upload_session/start \
        --header "Authorization: Bearer $dbtoken" \
        --header "Dropbox-API-Arg: {\"close\":false}" \
        --header "Content-Type: application/octet-stream")
    session_id=$(echo "$content" | grep -oP '(?<="session_id": ").*(?=")')

    # Iterate over chunks and cumulatively offset.
    offset=0
    for chunk in ./chunk*; do
    echo "Pushing $chunk"
    curl -X POST https://content.dropboxapi.com/2/files/upload_session/append_v2 \
        --header "Authorization: Bearer $dbtoken" \
        --header "Dropbox-API-Arg: {\"close\":false,\"cursor\":{\"offset\":$offset,\"session_id\":\"$session_id\"}}" \
        --header "Content-Type: application/octet-stream" \
        --data-binary @"$chunk"
    chunk_size=$(du -b "$chunk" | grep -o -E "^[0-9]+")
    offset=$((offset+chunk_size))
    done

    # Close upload session with final chunk.
    curl -X POST https://content.dropboxapi.com/2/files/upload_session/finish \
        --header "Authorization: Bearer $dbtoken" \
        --header "Dropbox-API-Arg: {\"commit\":{\"autorename\":true,\"mode\":\"add\",\"mute\":false,\"path\":\"/$out_path/$filename\",\"strict_conflict\":false},\"cursor\":{\"offset\":$offset,\"session_id\":\"$session_id\"}}" \
        --header "Content-Type: application/octet-stream"
    echo "Cleaning up split file."
    rm chunk*
else
    echo "Pushing to Dropbox archive."
    curl -X POST https://content.dropboxapi.com/2/files/upload \
        --header "Authorization: Bearer $dbtoken" \
        --header "Dropbox-API-Arg: {\"path\": \"/$out_path/$filename\", \"mode\": \"overwrite\", \"strict_conflict\": false}" \
        --header "Content-Type: application/octet-stream" \
        --data-binary @"$file"
fi

