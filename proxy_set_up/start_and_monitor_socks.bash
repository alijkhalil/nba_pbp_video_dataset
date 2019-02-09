#!/bin/bash

# Get inputs
if [ $# -ne 3 ]; then
	echo "Must supply path to SSH keys and AWS instance IP address."
	echo "Usage: $0 <path_to_local_ssh_key> <path_to_aws_ssh_key> <ip_addr_of_aws_instance>"
	
    echo ""
	echo "Also, you should note that the default port for the local SOCKS proxy is 9999,"
	echo "and the default port for the reverse tunnel on the remote machine will be 9998."
	echo ""
	exit 1
fi

if [ ! -f $1 ]; then
	echo "$1 is not a valid file path to local SSH key."
	exit 1
fi

if [ ! -f $2 ]; then
	echo "$2 is not a valid file path to AWS instance SSH key."
	exit 1
fi

LOCAL_KEY_PATH=$1
AWS_KEY_PATH=$2
AWS_IP_ADDR=$3

LOCAL_SOCKS_PORT=9999
REMOTE_FORWARDING_PORT=9998
SLEEP_SEC=150


# Do SSH commands
SSH_OPTIONS="-tnN -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

while true; do 
    # Monitor which components of reverse proxy are running
    REVERSE_PID="-1"
    ps ax | grep "[R] $REMOTE_FORWARDING_PORT:localhost:$LOCAL_SOCKS_PORT" | grep "ssh" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        REVERSE_PID=`ps ax | grep "[R] $REMOTE_FORWARDING_PORT:localhost:$LOCAL_SOCKS_PORT" | grep ssh | awk '{print $1}'`
        
        netstat -tnpa 2> /dev/null | grep "22" | grep $AWS_IP_ADDR | grep "ESTABLISHED" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            kill -9 $REVERSE_PID
            REVERSE_PID="-1"
        fi
    fi    
    
    LOCAL_PID="-1"
    ps ax | grep "[D] localhost:$LOCAL_SOCKS_PORT" | grep "ssh" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        LOCAL_PID=`ps ax | grep "[D] localhost:$LOCAL_SOCKS_PORT" | grep "ssh" | awk '{print $1}'`
        
        netstat -tnpa 2> /dev/null | grep $LOCAL_SOCKS_PORT | grep "LISTEN" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            kill -9 $LOCAL_PID
            LOCAL_PID="-1"    
        fi
    fi

    
    # Restart neccessary components
    if [ $LOCAL_PID == "-1" ]; then
        nohup ssh $SSH_OPTIONS -D localhost:$LOCAL_SOCKS_PORT -i $LOCAL_KEY_PATH `whoami`@localhost > /dev/null 2>&1 &

        sleep 15
        netstat -tnpa 2> /dev/null | grep $LOCAL_SOCKS_PORT | grep "LISTEN" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Initial SOCKS proxy command (with SSH) was not successful." 
            exit 1
        fi
    fi
    
    if [ $REVERSE_PID == "-1" ]; then
        nohup ssh $SSH_OPTIONS -R $REMOTE_FORWARDING_PORT:localhost:$LOCAL_SOCKS_PORT -i $AWS_KEY_PATH ec2-user@$AWS_IP_ADDR > /dev/null 2>&1 &

        sleep 15
        netstat -tnpa 2> /dev/null | grep "22" | grep $AWS_IP_ADDR | grep "ESTABLISHED" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Reverse tunnel command (with SSH) was not successful." 
            exit 1
        fi
    fi
    
    
    # Sleep for a couple minutes until the next check
    sleep $SLEEP_SEC
done


