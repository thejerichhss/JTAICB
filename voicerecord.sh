#!/bin/bash

OUTPUT="output.wav"
THRESHOLD_DB="-6"  # Adjust this based on your environment

rm -f "$OUTPUT"

ffmpeg -f pulse -i default -ac 1 -ar 16000 "$OUTPUT" -loglevel quiet -y &
FFMPEG_PID=$!
echo "Recording... Clap or say 'stop' loudly to terminate."

while true; do
  TEMP_SNIP=$(mktemp --suffix=.wav)
  
  ffmpeg -f pulse -i default -t 0.5 -ac 1 -ar 16000 "$TEMP_SNIP" -loglevel quiet -y
  
  PEAK_DB=$(sox "$TEMP_SNIP" -n stat 2>&1 | awk '/Maximum amplitude/ {amp=$3} END {printf "%.0f", 20*log(amp)/log(10)}')

  rm -f "$TEMP_SNIP"

  if [ "$PEAK_DB" -gt "$THRESHOLD_DB" ]; then
    echo "Stopping..."
    kill -INT $FFMPEG_PID
    break
  fi
  
  sleep 0.3
done

wait $FFMPEG_PID

whisper output.wav --model base --output_format txt --output_dir . > /dev/null 2>&1
  
