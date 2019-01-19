#!/bin/sh

# Starts a new thread after a 10 second delay
sleep 10
nohup rhino ./download_nba_clips.js > ./logs/thread$1.txt 2>&1 &


exit 0 
