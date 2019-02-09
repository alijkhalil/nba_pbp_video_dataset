#!/bin/bash

# Starts a new thread after a 10 second delay
SCRIPT_DIR=`dirname $0`

THREAD_ID=$1
SOCKS_PORT=$2

sleep 10
nohup $JAVA_HOME/bin/java -jar $RHINO_LIB_DIR/rhino.jar ./download_nba_clips.js $SOCKS_PORT $SCRIPT_DIR  > $SCRIPT_DIR/logs/thread$THREAD_ID.txt 2>&1 &


exit 0 