#!/bin/sh

# This script pushes file with the most recent modified date to Dropbox.
# Requires a Dropbox Application Access Token.

set -a            
source .env
set +a

if [[ -z "$dbox_refresh_token" ]]; then
    echo "You must provide a Dropbox Refresh Token (dbox_refresh_token) in .env."
    exit 1
fi

if [[ -z "$dbox_app_key" ]]; then
    echo "You must provide a Dropbox Application Key (dbox_app_key) in .env."
    exit 1
fi

if [[ -z "$dbox_app_secret" ]]; then
    echo "You must provide a Dropbox Application Secret (dbox_app_secret) in .env."
    exit 1
fi

if [[ -z "$dbox_out_path" ]]; then
    echo "You must provide an output path."
    exit 1
fi

if [ "$(uname)" == "Darwin" ]; then
    file=$(find -E . -maxdepth 1 -type f  -regex "./.*[0-9]+-[0-9]+.*")
else
    file=$(find . -maxdepth 1 -type f  -regex "./.*[0-9]+-[0-9]+.*")
fi

if [ -z "$file" ]; then
    echo "No file to push to Dropbox."
    exit 0
fi

filename=$(basename "$file")

mb=$(du -m "$file" | grep -o -E "^[0-9]+")

# Refresh Dropbox token
token_content=$(curl https://api.dropbox.com/oauth2/token \
   -d refresh_token="$dbox_refresh_token" \
   -d grant_type=refresh_token \
   -d client_id="$dbox_app_key" \
   -d client_secret="$dbox_app_secret")

dbox_token=$(echo "$token_content" | grep -o '"access_token": "[^"]*' | grep -o '[^"]*' | tail -n1)

ext_files=$(curl -X POST https://api.dropboxapi.com/2/files/search_v2 \
    --header "Authorization: Bearer $dbox_token" \
    --header "Content-Type: application/json" \
    --data "{
        \"match_field_options\":{
            \"include_highlights\":false
        },
        \"options\":{
            \"file_status\":\"active\",
            \"filename_only\":true,
            \"max_results\":20,
            \"path\":\"$dbox_out_path\"
        },
        \"query\":\"${filename}\"
        }")

if ! [[ -z "$files" ]]; then
    echo "File $filename already exists"
    exit 0
else
    if [ "$mb" -ge 150 ]; then
        echo "File is larger than Dropbox's payload limit for upload endpoint. Splitting file and starting upload session." 

        split -b150M "$file" chunk
        # Open an upload session with first chunk...
        content=$(curl -X POST https://content.dropboxapi.com/2/files/upload_session/start \
            --header "Authorization: Bearer $dbox_token" \
            --header "Dropbox-API-Arg: {\"close\":false}" \
            --header "Content-Type: application/octet-stream")
        session_id=$(echo "$content" | grep -o '"session_id": "[^"]*' | grep -o '[^"]*' | tail -n1)

        # Iterate over chunks and cumulatively offset.
        offset=0
        for chunk in ./chunk*; do
        echo "Pushing $chunk"
        curl -X POST https://content.dropboxapi.com/2/files/upload_session/append_v2 \
            --header "Authorization: Bearer $dbox_token" \
            --header "Dropbox-API-Arg: {
                \"close\":false,
                \"cursor\":{
                    \"offset\":$offset,
                    \"session_id\":\"$session_id\"
                }
                }" \
            --header "Content-Type: application/octet-stream" \
            --data-binary @"$chunk" &>/dev/null
        
        if [ "$(uname)" == "Darwin" ]; then
            chunk_size=$(stat -f %z $chunk)
        else
            chunk_size=$(du -b "$chunk" | grep -o -E "^[0-9]+")
        fi
        offset=$((offset+chunk_size))
        done

        # Close upload session with final chunk.
        curl -X POST https://content.dropboxapi.com/2/files/upload_session/finish \
            --header "Authorization: Bearer $dbox_token" \
            --header "Dropbox-API-Arg: {
                \"commit\":{
                    \"autorename\":true,
                    \"mode\":\"add\",
                    \"mute\":false,
                    \"path\":\"$dbox_out_path/$filename\",
                    \"strict_conflict\":false
                },
                \"cursor\":{
                    \"offset\":$offset,
                    \"session_id\":\"$session_id\"
                    }
                }" \
            --header "Content-Type: application/octet-stream"
        echo "Cleaning up split file."
        rm chunk*
    else
        echo "Pushing to Dropbox archive."
        curl -X POST https://content.dropboxapi.com/2/files/upload \
            --header "Authorization: Bearer $dbox_token" \
            --header "Dropbox-API-Arg: {
                \"path\": \"$dbox_out_path/$filename\", 
                \"mode\": \"overwrite\", 
                \"strict_conflict\": false
                }" \
            --header "Content-Type: application/octet-stream" \
            --data-binary @"$file"
    fi
fi
