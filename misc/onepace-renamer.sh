#!/bin/bash

DIR="$HOME/nfs/media/one_pace/04 Water Seven"
COUNTER=403

OIFS="$IFS"
IFS=$'\n'
cd "$DIR" || exit

for F in `find . -type f | sort`
do
    EPISODE_NUMBER=$(basename "$F" | cut -d "-" -f 2 | cut -d "x" -f 2)
    EPISODE_NAME=$(basename "$F" | awk -F" - " '{print $3}')
#   if [[ $EPISODE_NUMBER -gt 129 ]]; then
    mv -v "$F" "One Piece - 01x$((EPISODE_NUMBER-6)) - $EPISODE_NAME"
#   fi

#    EPISODE="${F#*"] "}"
#    EPISODE="${EPISODE%" ["*}"
#   mv -v "$F" "One Pace - 01x$COUNTER - $EPISODE $(basename "${F/\[One\ Pace\]/}" | cut -d " " -f 1).mkv"
#   ((COUNTER++))
done
IFS="$OIFS"
