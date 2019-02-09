#!/bin/sh

if [ $# -ne 1 ]; then
	echo "Must supply a GAME ID to the script."
	exit 1
fi


# Returns 1 if GAMEID is noted as having already been downloaded in the log file
CUR_DIR=`dirname $0`
THREAD_LOG_FILES=`ls $CUR_DIR/logs/thread* 2>/dev/null`

if [ "x$THREAD_LOG_FILES" != "x" ]; then
	cat $THREAD_LOG_FILES | grep -q $1
	if [ $? -eq 0 ]; then
		exit 1
	else
		exit 0
	fi
fi


exit 0
