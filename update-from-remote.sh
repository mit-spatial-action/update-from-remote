#!/bin/sh

# Checks the last modified date of a remote file and
# compares it to previously logged downloads in order to determine
# whether there has been an update on the remote. If the remote has
# been updated, downloads the updated file and moves the outdated
# local copy to an archive folder.

while getopts "u:" flag; do
 case $flag in
   u)
   # URL of remote file.
   URL="$OPTARG"
   ;;
 esac
done

echo "Grabbing modified dates from remote file using HEAD request."

FILENAME=$(basename "$URL")
LOG_CSV="log.csv"

# Create CSV if it doesn't exist.
if [ ! -f "$LOG_CSV" ]; then
    UPDATE=1
    FIRSTRUN=1
    echo "$LOG_CSV does not exist. Creating...";
    echo "url,date,date_ep,mod,mod_ep,update" >> $LOG_CSV
fi

CURL=$(curl -s -v -X HEAD "$URL" 2>&1)
DATE=$("$CURL" 2>&1 | sed -n -e 's/< Date\: .*\, //p'  | tr -d "\t\n\r")
# date -d "27 Mar 2024 15:10:59 GMT" "+%s"
DATE_EP=$(date -d "$DATE" "+%s")

# Break and log on 404 error.
if [[ $CURL = *'404 Not Found'* ]]; then
    echo '404 Error! Check your URL.'
    exit 1
fi

MOD=$("$CURL" 2>&1 | sed -n -e 's/< Last-Modified\: .*\, //p' | tr -d "\t\n\r")
MOD_EP=$(date -d "$MOD" "+%s")

CSV_LINES=$(wc -l < "$LOG_CSV" | xargs)
MOD_LAST_EP=$(tail -1 "$LOG_CSV" | awk -F',' '{print $5}')

if [ "$CSV_LINES" -eq 1 ]; then
    echo "No prior successful runs. Downloading file, modified on $MOD."
    UPDATE=1
elif [ "$MOD_EP" -gt "$MOD_LAST_EP" ]; then
    echo "There was an update to the file on $MOD."
    UPDATE=1
else
    echo "No update to the file since last run."
    UPDATE=0
fi

if [ "$UPDATE" -eq 1 ]; then
    echo "Downloading updated file."
    { 
        curl -o "$MOD_EP-$FILENAME" "$URL"
        # Move outdated file to archive folder.
        if [ -f "$MOD_LAST_EP-$FILENAME" ]; then
            mkdir -p 'archive'
            mv "$MOD_LAST_EP-$FILENAME" "archive/$MOD_LAST_EP-$FILENAME"
        fi
    }
fi

echo "$URL,$DATE,$DATE_EP,$MOD,$MOD_EP,$UPDATE" >> $LOG_CSV

