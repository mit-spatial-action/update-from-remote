#!/bin/sh

# Checks the last modified date of a remote file and
# compares it to previously logged downloads in order to determine
# whether there has been an update on the remote. If the remote has
# been updated, downloads the updated file and moves the outdated
# local copy to an archive folder.

url=''

while getopts "u:" flag; do
 case $flag in
   u)
   # URL of remote file.
   url="$OPTARG"
   ;;
 esac
done

if [[ -z "$url" ]]; then
    echo "You must provide a remote file URL."
    exit 1
fi

echo "Grabbing modified dates from remote file using HEAD request."

filename=$(basename "$url")
log_csv="log.csv"

# Create CSV if it doesn't exist.
if [ ! -f "$log_csv" ]; then
    update=1
    echo "$log_csv does not exist. Creating...";
    echo "url,date,mod,update" >> $log_csv
fi

curl=$(curl -s -v -X HEAD "$url" 2>&1)

# Break and log on 404 error.
if [[ $curl = *'404 Not Found'* ]]; then
    echo '404 Error! Check your URL.'
    exit 1
fi

date=$("$curl" 2>&1 | sed -n -e 's/< Date\: .*\, //p'  | tr -d "\t\n\r")
mod=$("$curl" 2>&1 | sed -n -e 's/< Last-Modified\: .*\, //p' | tr -d "\t\n\r")

if [ "$(uname)" == "Darwin" ]; then
    date_ep=$(date -j -fu "%d %b %Y %H:%M:%S %Z" "$date" "+%Y%m%d-%H%M%S")
    mod_ep=$(date -j -fu "%d %b %Y %H:%M:%S %Z" "$mod" "+%Y%m%d-%H%M%S")
else
    date_ep=$(date -d "$date" "+%Y%m%d-%H%M%S")
    mod_ep=$(date -d "$mod" "+%Y%m%d-%H%M%S")
fi

csv_lines=$(wc -l < "$log_csv" | xargs)
mod_last_ep=$(tail -1 "$log_csv" | awk -F',' '{print $3}')

if [ "$csv_lines" -eq 1 ]; then
    echo "No prior successful runs. Downloading file, modified on $mod."
    update=1
elif [ "$mod_ep" -gt "$mod_last_ep" ]; then
    echo "There was an update to the file on $mod."
    update=1
else
    echo "No update to the file since last run."
    update=0
fi

if [ "$update" -eq 1 ]; then
    echo "Downloading updated file."
    { 
        filename_only="${filename%.*}"
        extension="${filename##*.}"

        curl -o "${filename_only}_${mod_ep}.${extension}" "$url"
        # Move outdated file to archive folder.
        if [ -f "${filename_only}_${mod_last_ep}.${extension}" ]; then
            mkdir -p 'archive'
            mv "${filename_only}_${mod_last_ep}.${extension}" "archive/${filename_only}_${mod_last_ep}.${extension}"
        fi
    }
fi

echo "$url,$date_ep,$mod_ep,$update" >> $log_csv

