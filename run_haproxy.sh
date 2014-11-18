#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset


if [ $# -ne 2 ]
then
	echo "Usage: $0 <interval> <configfile>"
	exit 1
fi


## file helper functions
file_wait() {
	while [ ! -f "$1" ]
	do
		echo "missing config file $1; waiting..."
		sleep $INTERVAL
	done
}

file_hash() {
	md5sum "$1" | sed -r 's/^([^ ]*).*/\1/'
}

file_mtime() {
	stat -c %Y "$1"
}


## helper functions
do_update_hash() {
	CONFIG_HASH=$(file_hash "$CONFIG")
}

do_update_mtime() {
	CONFIG_MTIME=$(file_mtime "$CONFIG")
}

is_haproxy_running() {
	test -f $PIDFILE && (pgrep -F "$PIDFILE" > /dev/null)
}


## global state
INTERVAL=$1
CONFIG=$2
CONFIG_HASH=
CONFIG_MTIME=
PIDFILE=/var/run/haproxy.pid


## mail loop
file_wait "$CONFIG"
while true
do
	## refresh config state
	do_update_hash
	do_update_mtime

	## start or restart haproxy
	if is_haproxy_running
	then
		echo "restarting haproxy..."
		haproxy -f "$CONFIG" -p "$PIDFILE" -sf $(cat "$PIDFILE")
	else 
		echo "starting haproxy..."
		haproxy -f "$CONFIG" -p "$PIDFILE"
	fi
			
	## wait until config has changed
	while [ "$CONFIG_HASH" = "$(file_hash $CONFIG)" ]
	do
		while [ "$CONFIG_MTIME" = "$(file_mtime $CONFIG)" ]
		do
			## delay next round
			sleep $INTERVAL

			## keep an eye on haproxy
			if ! is_haproxy_running
			then
				echo "ouch, haproxy died!"
				exit 1
			fi
		done
		echo "timestamp of config file $CONFIG changed..."
		do_update_mtime
	done
	echo "hash of config file $CONFIG changed..."
done
