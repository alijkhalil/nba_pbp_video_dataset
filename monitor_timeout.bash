#!/bin/bash


# Error checking
if [ $# -ne 1 ]; then
	echo "Script requires the number of threads to restart in case of a stall."
	exit 1
fi

re='^[0-9]+$'
if ! [[ $1 =~ $re ]] ; then
	echo "ERROR: Agurment was not a number!" >&2
	exit 1
fi


# Start script to detect stall in download of videos
LOG_DIR="logs"

PREV_NUM_BYTES=0
NUM_THREADS=64
SLEEP_SEC_PER_ITER=450
SLEEP_SEC_BEFORE_NEXT_COMMAND=45
SLEEP_SEC_BEFORE_RESTART_DOWNLOAD=900

cd `dirname $0`

while true; do 
	DATE=`date +"%H:%M on %m-%d"`
	CUR_NUM_BYTES=`du -s ./game_events/ | awk '{print $1}'`
	
	if [ $CUR_NUM_BYTES -eq $PREV_NUM_BYTES ]; then
		# Kill ongoing processes and connections
		kill -9 `ps -ax | grep [d]ownload_nba_clips | awk '{print $1}'` 2>&1
        sleep $SLEEP_SEC_BEFORE_NEXT_COMMAND
		
        sudo tcpkill -9 port 80 or port 443 > /dev/null 2>&1&
        sleep $SLEEP_SEC_BEFORE_NEXT_COMMAND
		sudo kill -9 `ps -ax | grep [t]cpkill | awk '{print $1}'` 2>&1
        
        # Sleep in case of rate limiting and remove locking/logging files
		sleep $SLEEP_SEC_BEFORE_RESTART_DOWNLOAD
		rm -f ./$LOG_DIR/thread*
		for i in `seq $NUM_THREADS`; do lockfile-remove /tmp/lock.lock; done

		# Gradually decreases number of threads if download has stopped working
		NUM_THREADS=`python -c "from math import ceil; print int(ceil($NUM_THREADS / 1.125))"`
		for i in `seq $NUM_THREADS`; do ./start_delayed_process.sh $i > /dev/null 2>&1; done
		
		echo -e "\n====\n\nRestarted download script  @  $DATE\n"
	
	elif [ $PREV_NUM_BYTES -ne 0 ]; then
		NUM_KB_PER_SEC=`echo "($CUR_NUM_BYTES - $PREV_NUM_BYTES) / $SLEEP_SEC_PER_ITER" | bc`
		echo "Going at $NUM_KB_PER_SEC KB/sec  @  $DATE"
	fi
	
	PREV_NUM_BYTES=$CUR_NUM_BYTES 
	sleep $SLEEP_SEC_PER_ITER
done
