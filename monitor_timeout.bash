#!/bin/bash

# Input/option/envirnoment variable checks
cd `dirname $0`

NO_SOCK_VAL="-1"

if [ $# -lt 1 ]; then
	echo "ERROR: Script requires the number of download threads and an optional port for the SOCKS proxy (in order)." >&2
	exit 1
fi

re='^[0-9]+$'
if ! [[ $1 =~ $re ]] ; then
	echo "ERROR: Number of download threads argument was not a number!" >&2
	exit 1
fi

if [ $2 != $NO_SOCK_VAL ]; then     # Ignore -1 bc it is the value for "do not use SOCKS"
    re='^[0-9]+$'
    if ! [[ $2 =~ $re ]] ; then
        echo "ERROR: the SOCKS port argument was not a number!" >&2
        exit 1
    fi
    
    ./utils/check_reverse_tunnel.sh $2
    if [ $? -eq 1 ]; then
        echo "ERROR: It does not appear that the SOCKS proxy on port $SOCKS_PORT_NUM is set up." >&2
        echo "Try port 9998 because that is the set-up script's default port." >&2
        exit 1                
    fi
fi

if [ -z $JAVA_HOME ]; then
    echo "ERROR: JAVA_HOME envirnoment variable  was not defined." >&2
    echo "(It should point to the directory containing the JAVA libraries/binaries used to build rhino.)" >&2
    exit 1
fi

if [ -z $RHINO_LIB_DIR ]; then
    echo "ERROR: RHINO_LIB_DIR envirnoment variable was not defined." >&2
    echo "(It should point to the location where the rhino jar and its 'rhino' symlink exists.)" >&2
    exit 1    
fi

which ffmpeg > /dev/null 2>&1
if [ $? -ne 0 ]; then 
    echo "ERROR: 'ffmpeg' needs to be installed on your machine." >&2
    exit 1    
fi


# Start script to detect stall in download of videos
NUM_THREADS=$1
SOCKS_PORT=$2

PREV_NUM_BYTES=0
SLEEP_SEC_PER_ITER=600
SLEEP_SEC_BEFORE_RESTART_DOWNLOAD=900

while true; do 
	DATE=`date +"%H:%M on %m-%d"`
	CUR_NUM_BYTES=`du -s ./game_events/ | awk '{print $1}'`
	
    # Detect and remove any new incomplete downloads
    ./utils/remove_partial_downloads.bash > /dev/null
    
    # Check to see if SOCKS still up
    if [ $SOCKS_PORT != $NO_SOCK_VAL ]; then
        ./utils/check_reverse_tunnel.sh $SOCKS_PORT
        if [ $? -eq 1 ]; then
            # Kill ongoing processes and connections
            kill -9 `ps ax | grep [d]ownload_nba_clips | awk '{print $1}'` > /dev/null 2>&1
            
            # Clean up log files
            rm -f ./logs/thread* 
            rm -f /tmp/nba_pbp_lock.lock
            
            # Print error message
            echo "Killed download monitor script because SOCKS proxy does not appear to be running."
            exit 1
        fi
    fi
    
    # Check to see if the downloading not halted or blocked
	if [ $CUR_NUM_BYTES -eq $PREV_NUM_BYTES ]; then
        # Get number of threads having finished their downloads
        NUM_DONE=$(grep "SCRIPT COMPLETE" `find ./logs/ -type f` | wc -l)
        if [ $NUM_DONE -eq $NUM_THREADS ]; then
            echo "All scripts seem to have completed successfully!"
            exit 0
        fi

		# Kill ongoing processes and connections
		kill -9 `ps ax | grep [d]ownload_nba_clips | awk '{print $1}'` > /dev/null 2>&1
		        
        # Sleep in case of rate limiting and clean up left-over files
		sleep $SLEEP_SEC_BEFORE_RESTART_DOWNLOAD        
        
        rm -f ./logs/thread*
        rm -f /tmp/nba_pbp_lock.lock
        
		# Gradually decreases number of threads if download has stopped working
		NUM_THREADS=`python -c "from math import ceil; print int(ceil($NUM_THREADS / 1.125))"`
		for i in `seq $NUM_THREADS`; do ./start_delayed_process.bash $i $SOCKS_PORT > /dev/null 2>&1; done
		
		echo -e "\n====\n\nRestarted download script  @  $DATE\n"
	
	elif [ $PREV_NUM_BYTES -ne 0 ]; then
		NUM_KB_PER_SEC=`echo "($CUR_NUM_BYTES - $PREV_NUM_BYTES) / $SLEEP_SEC_PER_ITER" | bc`
		echo "Going at $NUM_KB_PER_SEC KB/sec  @  $DATE"
	fi
	
	PREV_NUM_BYTES=$CUR_NUM_BYTES 
	sleep $SLEEP_SEC_PER_ITER
done
