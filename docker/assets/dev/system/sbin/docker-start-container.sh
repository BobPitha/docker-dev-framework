#!/bin/bash -x

# Use the following lines to specify the development user and group
# export SERVER_USER=username
# export SERVER_TROUP=groupname

/sbin/docker-setup-user.sh
/sbin/docker-start-sleep-loop.sh