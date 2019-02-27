#!/bin/sh


# Kill monitoring thread first so it doesn't restart download
ps ax | grep -q [m]onitor_timeout
if [ $? -eq 0 ]; then
    PIDS=`ps ax | grep [m]onitor_timeout | awk '{ print $1 }'`
    kill -9 $PIDS
fi

# Kill actual download processes next
ps ax | grep -q [d]ownload_nba_clips
if [ $? -eq 0 ]; then
    PIDS=`ps ax | grep [d]ownload_nba_clips | awk '{ print $1 }'`
    kill -9 $PIDS
fi


# Remove download filelock and exit successfully
rm -f /tmp/nba_pbp_lock.lock
exit 0
