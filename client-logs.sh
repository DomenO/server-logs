#!/bin/bash

# Run background
# nohup ./client-logs.sh &> /dev/null &

# Autorun
# crontab -e
# @reboot ~/client-logs.sh

SERVER="127.0.0.1"
PORT=34092
NAME="Test" # Streamlive-Kick-1
CONTAINER_NAME="streamlive-kick-5731"
INTERVAL=10 # Update interval


command_exists () {
	type "$1" &> /dev/null ;
}

if command_exists netcat; then
	NETBIN="netcat"
elif command_exists nc; then
	NETBIN="nc"
else
	echo "netcat not found, install it."
	exit 1
fi

RUNNING=true
clean_up () {
	echo "Quit." >&2
	RUNNING=false
	rm -f /tmp/fuckbash
}

trap clean_up SIGINT SIGTERM EXIT
STRING=""

while $RUNNING; do
	rm -f /tmp/fuckbash
	PREV_TOTAL=0
	PREV_IDLE=0
	AUTH=true
	TIMER=0

	while $RUNNING; do
		if $AUTH; then
			echo -e "{\"type\":\"auth\",\"name\":\"$NAME\"}"
			AUTH=false
		fi
		sleep $INTERVAL
		if ! $RUNNING; then
			exit 0
		fi

		# Connectivity
		if [ $TIMER -le 0 ]; then
			if [ -f /tmp/fuckbash ]; then
				CHECK_IP=$(</tmp/fuckbash)
				IP6_ADDR="2001:4860:4860::8888"
				IP4_ADDR="8.8.8.8"
				if [ "$CHECK_IP" == "4" ]; then
					if ping -i 0.2 -c 3 -w 3 $IP4_ADDR &> /dev/null; then
						Online="\"online4\": true, "
					else
						Online="\"online4\": false, "
					fi
					TIMER=10
				elif [ "$CHECK_IP" == "6" ]; then
					if ping6 -i 0.2 -c 3 -w 3 $IP6_ADDR &> /dev/null; then
						Online="\"online6\": true, "
					else
						Online="\"online6\": false, "
					fi
					TIMER=10
				fi
			fi
		else
			let TIMER-=1*INTERVAL
		fi


        JSON_LOGS=`docker logs -t --since=${INTERVAL}s --details $CONTAINER_NAME |& awk '{time=$1; $1=""; gsub(/\\|\$|\"/, "\\\\&"); print "{\"time\": \""time"\", \"log\": \""substr($0,2)"\"},"}'`

        if [ -n "$JSON_LOGS" ]; then
            echo -e "{\"type\": \"add\", \"data\": ["$(echo $JSON_LOGS | awk '{print substr($0, 1, length($0)-1)}')"]}"
        fi

	done | $NETBIN $SERVER $PORT | while IFS= read -r -d $'\0' x; do
		if [ ! -f /tmp/fuckbash ]; then
			if grep -q "IPv6" <<< "$x"; then
				echo "Connected." >&2
				echo 4 > /tmp/fuckbash
				exit 0
			elif grep -q "IPv4" <<< "$x"; then
				echo "Connected." >&2
				echo 6 > /tmp/fuckbash
				exit 0
			fi
		fi
	done

	wait
	if ! $RUNNING; then
		echo "Exiting"
		rm -f /tmp/fuckbash
		exit 0
	fi

	# keep on trying after a disconnect
	echo "Disconnected." >&2
	sleep 3
	echo "Reconnecting..." >&2
done
