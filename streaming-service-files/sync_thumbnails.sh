#!/bin/bash

# Load the .env file
set -a # automatically export all variables
source .env
set +a

# Convert space-separated SERVERS to an array
IFS=' ' read -r -a Servers <<< "$SERVERS"

# Using correct variable names from .env
for i in `ls $LOCAL_PATH | grep flv`; do
    success=0
    for ((retry=0; retry<MAX_RETRIES; retry++)); do
        if docker run --rm -v $LOCAL_PATH:/thumbnails -w /thumbnails --cpus="1.5" jrottenberg/ffmpeg -i "${i%.*}.flv" -c:v libx264 -s 960x540 -aspect 16:9 "${i%.*}.mp4" -y; then
            success=1
            break
        else
            echo "Retry $retry for ${i%.*}.mp4"
            sleep 1
        fi
    done

    if [ $success -eq 0 ]; then
        echo "Max retries reached for ${i}. Deleting file."
        rm -f "${LOCAL_PATH}/${i}"
        continue
    fi

    success=0
    for ((retry=0; retry<MAX_RETRIES; retry++)); do
        if docker run --rm -v $LOCAL_PATH:/thumbnails -w /thumbnails --cpus="1.5" jrottenberg/ffmpeg -i "${i%.*}.flv" -s 960x540 -aspect 16:9 -vframes 1 "${i%.*}.jpg" -y; then
            success=1
            break
        else
            echo "Retry $retry for ${i%.*}.jpg"
            sleep 1
        fi
    done

    if [ $success -eq 0 ]; then
        echo "Max retries reached for ${i}. Deleting file."
        rm -f "${LOCAL_PATH}/${i}"
    fi
done

# Correct variable names and quotes around the variable to prevent globbing and word splitting
for Server in "${Servers[@]}"; do
    rsync -avz -e "ssh -o ConnectTimeout=5" "$LOCAL_PATH/" "$Server:$REMOTE_PATH/"
done

# Correct variable name
rm -f "$LOCAL_PATH/"*.flv
