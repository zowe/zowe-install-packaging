#!/bin/bash

if [[ "$ZOWE_START" == "0" ]]
then
    su zowe
    sleep infinity
else

ROOT_DIR="/home/zowe/install"

if [ -d "/root/zowe/apps" ]; then
    apps_dir="/root/zowe/apps"
else
    apps_dir="/home/zowe/apps"
fi
if [ -d "/root/zowe/certs" ]; then
    certs_dir="/root/zowe/certs"
else
    certs_dir="/home/zowe/certs"
fi


if [ -n "$HOSTNAME" ]; then
  if [ -z "$ZOWE_EXPLORER_HOST" ]; then
    export ZOWE_EXPLORER_HOST=$HOSTNAME
  fi
fi

if [ -z "${EXTERNAL_INSTANCE}" ]; then
  if [ -d "/home/zowe/external_instance" ]; then
    export EXTERNAL_INSTANCE="/home/zowe/external_instance"
    export INSTANCE_DIR="/home/zowe/external_instance"
  elif [ -d "/root/zowe/external_instance" ]; then
    export EXTERNAL_INSTANCE="/root/zowe/external_instance"
    export INSTANCE_DIR="/root/zowe/external_instance"
  elif [ -z "${INSTANCE_DIR}" ]; then
		export INSTANCE_DIR=/home/zowe/instance
	fi
else
	export INSTANCE_DIR=$EXTERNAL_INSTANCE
fi

#Sync user 'zowe' to be in the same groups as the first file seen in each mounted config dir
for D in "$certs_dir" "$apps_dir" "$EXTERNAL_INSTANCE"
do
    # echo "Acting on $D if exists"
    if [ -d "$D" ]; then
        ls -ltr $D
        group=$(ls -g $D | cut -d " " -f 3 | sed '2!d')
        # echo "Group in $D is $group"
        if [ "$group" != "root" ]; then
            exists=$(grep $group /etc/group | cut -f 1 -d ':')
            # echo "Matching group? Found: $exists"
            if [ "$group" != "$exists" ]; then
                echo "Adding missing container group"
                groupadd -g $group zowe_${group}
            fi
            ingid=$(id zowe | grep "gid=${group}(")
            ingroup=$(id zowe | grep "(${group})")
            if [ -z "$ingid" -a -z "$ingroup" ]; then 
                echo "Added zowe to container group, zowe now in groups:"
                usermod --groups zowe_${group} zowe
                id zowe
            fi
        fi
    fi
done

su -c "/home/zowe/.run_inner.sh" zowe
fi
