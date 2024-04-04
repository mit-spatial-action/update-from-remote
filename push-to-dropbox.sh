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

log_csv="log.csv"

mod_last_ep=$(tail -1 "$log_csv" | awk -F',' '{print $5}')

file=$(find . -type f -iname "$mod_last_ep*")

mb=$(du -m "$file" | grep -o -E "^[0-9]+")

if [ mb > 150 ]; then
    echo "File is larger than Dropbox's payload limit for upload endpoint. Splitting file and starting upload session." 
    split --bytes=150M "$file" chunk
    chunklist=($(ls chunk* | sort -d))

    # Open an upload session with first chunk...
    content=$(curl -X POST https://content.dropboxapi.com/2/files/upload_session/start \
        --header "Authorization: Bearer $dbtoken" \
        --header "Dropbox-API-Arg: {\"close\":false}" \
        --header "Content-Type: application/octet-stream" \
        --data-binary @"${chunklist[0]}")
    session_id=$(echo "$content" | grep -oP '(?<="session_id":)(?<= )?.*(?=")' | tr -cd '[:alnum:]:')
    echo "$session_id"
    for item in ${chunklist[@]:1:${#chunklist[@]}-1}
    do
    curl -X POST https://content.dropboxapi.com/2/files/upload_session/append_v2 \
        --header "Authorization: Bearer $dbtoken" \
        --header "Dropbox-API-Arg: {\"close\":false,\"cursor\":{\"offset\":0,\"session_id\":\"$session_id\"}}" \
        --header "Content-Type: application/octet-stream" \
        --data-binary @"$item"
    done
    # Close upload session with final chunk.
    curl -X POST https://content.dropboxapi.com/2/files/upload_session/finish \
        --header "Authorization: Bearer $dbtoken" \
        --header "Dropbox-API-Arg: {\"commit\":{\"autorename\":true,\"mode\":\"add\",\"mute\":false,\"path\":\"/$out_path/$file\",\"strict_conflict\":false},\"cursor\":{\"offset\":0,\"session_id\":\"$session_id\"}}" \
        --header "Content-Type: application/octet-stream" \
        --data-binary @"${chunklist[-1]}"
else
    echo "Pushing to Dropbox archive."
    curl -X POST https://content.dropboxapi.com/2/files/upload \
        --header "Authorization: Bearer $dbtoken" \
        --header "Dropbox-API-Arg: {\"path\": \"/$out_path/$file\", \"mode\": \"overwrite\", \"strict_conflict\": false}" \
        --header "Content-Type: application/octet-stream" \
        --data-binary @"$file"
fi





