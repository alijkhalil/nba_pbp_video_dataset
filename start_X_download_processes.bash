#!/bin/bash

# Input/envirnoment variable validation
SCRIPT_DIR=`dirname $0`

NUM_THREADS=64
SOCKS_PORT_NUM=-1

if [ $# -ge 1 ]; then
	re='^[0-9]+$'
	if [[ $1 =~ $re ]] ; then
	   NUM_THREADS=$1
    else
        echo "ERROR: Invalid desired number of download process threads passed as first parameter." >&2
        exit 1        
	fi
    
    if [ $# -eq 2 ]; then 
        if [[ $2 =~ $re ]] ; then
            SOCKS_PORT_NUM=$2
            
            sh $SCRIPT_DIR/utils/check_reverse_tunnel.sh $SOCKS_PORT_NUM
            if [ $? -eq 1 ]; then
                echo "ERROR: It does not appear that the SOCKS proxy on port $SOCKS_PORT_NUM is set up." >&2
                echo "Try port 9998 because that is the set-up script's default port." >&2                
                exit 1                
            fi
        else
            echo "ERROR: Invalid optional SOCKS proxy port number passed as second parameter." >&2
            exit 1
        fi
    fi
fi

if [ -z $JAVA_HOME ]; then
    echo "ERROR: JAVA_HOME envirnoment variable  was not defined." >&2
    echo "(It should point to the directory containing the JAVA libraries/binaries used to build rhino.)" >&2
    exit 1
fi

if [ -z $RHINO_LIB_DIR ]; then
    echo "ERROR: RHINO_LIB_DIR envirnoment variable was not defined." >&2
    echo "(It should point to the location where the rhino jar and/or its 'rhino' symlink exists.)" >&2
    exit 1    
fi

which ffmpeg > /dev/null 2>&1
if [ $? -ne 0 ]; then 
    echo "ERROR: 'ffmpeg' needs to be installed on your machine." >&2
    exit 1    
fi    


# Clean old files from any download routines
rm -f /tmp/nba_pbp_lock.lock
rm -f $SCRIPT_DIR/logs/thread*


# Start download processes and script to monitor them
# NOTE:  Comment out the line below if you don't want progress monitoring for whatever reason
nohup ./monitor_timeout.bash $NUM_THREADS $SOCKS_PORT_NUM > ./logs/monitor_log.txt 2>&1&

for i in `seq $NUM_THREADS`; do 
    ./start_delayed_process.bash $i $SOCKS_PORT_NUM > /dev/null 2>&1;
done


# Exit successfully
exit 0