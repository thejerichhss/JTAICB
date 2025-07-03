#!/bin/bash

ffmpeg -f pulse -i default -t 10 -ac 1 -ar 16000 output.wav -loglevel quiet -y

whisper output.wav --model base --output_format txt --output_dir . > /dev/null 2>&1
  