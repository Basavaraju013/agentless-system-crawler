#!/bin/bash

# Returns 1 if success, 0 otherwise

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# The docker log link will be created here:
# /var/log/crawler_container_logs/<HOST_IP>/<CONTAINER_NAME>/docker.log
# I have some python code to get the local host IP. XXX replace it with bash
read -d '' GET_HOST_IP_PY <<"EOF"
import socket
def get_host_ipaddr():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('www.ibm.com', 9))
        return s.getsockname()[0]
    except socket.error:
        return socket.gethostname()
    finally: 
        del s
print get_host_ipaddr()
EOF

HOST_IP=`python2.7 -c "$GET_HOST_IP_PY" 2> /dev/null`
NAME=test_create_destroy_container_with_input_logfiles

# Cleanup
rm -f /tmp/$NAME*
rm -rf /var/log/crawler_container_logs/$HOST_IP/$NAME/
docker rm -f $NAME 2> /dev/null > /dev/null

python2.7 ../../crawler/containers_logs_linker.py --frequency 1 &
PID=$!

MSG=`uuidgen`
docker run -d -e LOG_LOCATIONS=/var/log/input_file_name.log --name $NAME ubuntu bash -c "echo $MSG >> /var/log/input_file_name.log; sleep 5" 2> /dev/null > /dev/null
ID1=`docker ps | grep $NAME | awk '{print $1}'`

sleep 2

# By now the log should be there
COUNT=`grep -c $MSG /var/log/crawler_container_logs/$HOST_IP/$NAME/var/log/input_file_name.log`

# after this, the log will disappear
sleep 5

# By now the container should be dead, and the link should be deleted
if [ $COUNT == "1" ] && [ ! -f /var/log/crawler_container_logs/$HOST_IP/$NAME/var/log/input_file_name.log ]
then
	:
	#echo 1
else
	echo 0
	exec 2> /dev/null
	kill -9 $PID > /dev/null 2> /dev/null
	exit
fi

sleep 3

# Now start a container with the same name
MSG=`uuidgen`
# As the --ephemeral option to docker might not be available, let's make sure
# the container is removed (even if it already exited)
docker rm -f $NAME 2> /dev/null > /dev/null
docker run -d -e LOG_LOCATIONS=/var/log/input_file_name.log --name $NAME ubuntu bash -c "echo $MSG >> /var/log/input_file_name.log; sleep 5" 2> /dev/null > /dev/null
# Although this is a container with teh same name, the ID is not the same
ID2=`docker ps | grep $NAME | awk '{print $1}'`

sleep 2

# By now the log should be there
COUNT=`grep -c $MSG /var/log/crawler_container_logs/$HOST_IP/$NAME/var/log/input_file_name.log`

# after this, the log will disappear
sleep 5

# By now the container should be dead, and the link should be deleted
if [ $COUNT == "1" ] && [ ! -f /var/log/crawler_container_logs/$HOST_IP/$NAME/var/log/input_file_name.log  ]
then
	echo 1
else
	echo 0
fi

# Just avoid having the "Terminated ..." error showing up
exec 2> /dev/null
kill -9 $PID > /dev/null 2> /dev/null

docker rm -f $NAME > /dev/null
