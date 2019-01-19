#!/bin/bash

NUM_THREADS=64
if [ $# -eq 1 ]; then
	re='^[0-9]+$'
	if [[ $1 =~ $re ]] ; then
	   NUM_THREADS=$1
	fi
fi

nohup ./monitor_timeout.bash $NUM_THREADS > ./logs/monitor_log.txt 2>&1&
for i in `seq $NUM_THREADS`; do ./start_delayed_process.sh $i > /dev/null 2>&1; done
