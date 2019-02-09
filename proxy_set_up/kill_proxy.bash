#!/bin/bash

LOCAL_SOCKS_PORT=9999
REMOTE_FORWARDING_PORT=9998

REVERSE_PIDS=`ps ax | grep "[R] $REMOTE_FORWARDING_PORT:localhost:$LOCAL_SOCKS_PORT" | grep ssh | awk '{print $1}'`
kill -9 $REVERSE_PIDS > /dev/null 2>&1

LOCAL_PIDS=`ps ax | grep "[D] localhost:$LOCAL_SOCKS_PORT" | grep "ssh" | awk '{print $1}'`
kill -9 $LOCAL_PIDS > /dev/null 2>&1

exit 0