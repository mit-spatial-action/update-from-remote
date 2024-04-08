#!/bin/sh

# Checks the last modified date of a remote file and
# compares it to previous downloads in order to determine
# whether there has been an update on the remote. If the remote has
# been updated, downloads the updated file and moves the outdated
# local copy to an archive folder.

url=''

set -a            
source .env
set +a

while getopts "u:a" flag; do
 case $flag in
   u)
   # URL of remote file.
   url="$OPTARG"
   ;;
   a)
   # URL of remote file.
   archive_dir="$OPTARG"
   ;;
 esac
done

if [[ -z "$url" ]]; then
    echo "You must provide a remote file URL."
    exit 1
fi

if [[ -z "$archive_dir" ]]; then
    archive_dir='archive/'
fi


echo "Grabbing modified dates from remote file using HEAD request."

filename=$(basename "$url")
filename_only="${filename%.*}"
extension="${filename##*.}"

curl=$(curl -s -v -X HEAD "$url" 2>&1)

# Break and log on 404 error.
if [[ $curl = *'404 Not Found'* ]]; then
    echo '404 Error! Check your URL.'
    exit 1
fi

date=$("$curl" 2>&1 | sed -n -e 's/< Date\: .*\, //p'  | tr -d "\t\n\r")
mod=$("$curl" 2>&1 | sed -n -e 's/< Last-Modified\: .*\, //p' | tr -d "\t\n\r")

if [ "$(uname)" == "Darwin" ]; then
    date_ep=$(date -ju -f "%d %b %Y %H:%M:%S %Z" "$date" "+%Y%m%d-%H%M%S")
    mod_ep=$(date -ju -f "%d %b %Y %H:%M:%S %Z" "$mod" "+%Y%m%d-%H%M%S")
else
    date_ep=$(date -d "$date" "+%Y%m%d-%H%M%S")
    mod_ep=$(date -d "$mod" "+%Y%m%d-%H%M%S")
fi

new_file=${filename_only}_${mod_ep}.${extension}

if ! [ -f "$new_file" ]; then
    echo "There was an update to the file on $mod. Downloading updated file."
    {
        # Move outdated file to archive folder.
        if [ -f "${filename_only}"* ]; then
            mkdir -p 'archive'
            mv "${filename_only}"* $archive_dir
        fi
        curl -o "${new_file}" "$url"
    }
else
    echo "No update to the file since last run."
    exit 0
fi
