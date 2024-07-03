#!/bin/bash

# if username and password were not provided, exit.
# otherwise, create the user, add to groups, and modify file system permissions
if [[ -z $CONTAINER_USER_USERNAME ]] || [[ -z $CONTAINER_USER_PASSWORD ]];
then
      exit 1
else
    useradd $CONTAINER_USER_USERNAME \
	&& echo "$CONTAINER_USER_USERNAME:$CONTAINER_USER_PASSWORD" | chpasswd \
	&& usermod -aG sudo $CONTAINER_USER_USERNAME \
	&& chsh -s /bin/bash ${CONTAINER_USER_USERNAME} \
	&& mkdir -p /home/${CONTAINER_USER_USERNAME} \
	&& chown -R ${CONTAINER_USER_USERNAME}:${CONTAINER_USER_USERNAME} /home/${CONTAINER_USER_USERNAME}
fi


# start sshd
/usr/sbin/sshd -D&

# # start the MariaDB services
#start-services

service postgresql start && sleep 5

# echo "Running /init script:"

# cat /init

# # delegate to rocker: start RStudio Server etc 
/init

