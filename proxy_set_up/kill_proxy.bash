#!/bin/bash

LOCAL_SOCKS_PORT=9999
REMOTE_FORWARDING_PORT=9998

MAIN_SCRIPT_PID=`ps ax| grep [s]tart_and_monitor | awk '{print $1}'`
if [ "$MAIN_SCRIPT_PID" != "" ]; then
	kill -9 $MAIN_SCRIPT_PID
fi

REVERSE_PIDS=`ps ax | grep "[R] $REMOTE_FORWARDING_PORT:localhost:$LOCAL_SOCKS_PORT" | grep ssh | awk '{print $1}'`
if [ "$REVERSE_PIDS" != "" ]; then
	kill -9 $REVERSE_PIDS > /dev/null 2>&1
fi

LOCAL_PIDS=`ps ax | grep "[D] localhost:$LOCAL_SOCKS_PORT" | grep "ssh" | awk '{print $1}'`
if [ "$LOCAL_PIDS" != "" ]; then
	kill -9 $LOCAL_PIDS > /dev/null 2>&1
fi

exit 0
