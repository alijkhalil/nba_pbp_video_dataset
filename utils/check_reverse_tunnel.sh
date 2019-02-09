#!/bin/sh

# Check for an SSH connection on the SOCK port
PORT=$1

netstat -tnpa 2> /dev/null | grep $PORT | grep LISTEN > /dev/null
if [ $? -eq 0 ]; then
    exit 0
else
    exit 1
fi