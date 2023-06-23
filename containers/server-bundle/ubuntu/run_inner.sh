#!/bin/bash

if [ -d "${apps_dir}" ]; then
  export ZLUX_ROOT=/home/zowe/install/components/app-server/share
  cd ${apps_dir}
  for D in */;
   do
    if test -f "$D/autoinstall.sh"; then
      app=$(cd $D && pwd)
      ZLUX_ROOT=$ZLUX_ROOT APP_PLUGIN_DIR=app ./$D/autoinstall.sh
    elif test -f "$D/pluginDefinition.json"; then
        $INSTANCE_DIR/bin/install-app.sh ${apps_dir}/$D
    elif test -f "$D/manifest.yaml"; then
        $ROOT_DIR/bin/zowe-install-component.sh -o ${apps_dir}/$D -i $INSTANCE_DIR
    elif test -f "$D/manifest.yml"; then
        $ROOT_DIR/bin/zowe-install-component.sh -o ${apps_dir}/$D -i $INSTANCE_DIR
    elif test -f "$D/manifest.json"; then
        $ROOT_DIR/bin/zowe-install-component.sh -o ${apps_dir}/$D -i $INSTANCE_DIR
    fi
  done
fi

if [ ! -d "${certs_dir}" ]; then
    input1="/home/zowe/install/bin/zowe-setup-certificates.env.bkp"
    while read -r line
    do
        test -z "${line%%#*}" && continue      # skip line if first char is #
        key=${line%%=*}
        if [ -n "${!key}" ]
        then
            echo "Replacing key=${key} with val=${!key}"
            sed -i 's@'${key}'=.*@'${key}'='"${!key}"'@g' /home/zowe/install/bin/zowe-setup-certificates.env
        fi
    done < "$input1"

#correct the replacements for the few env vars we dont want the user to override simply by env var alone
    sed -i 's/ZOWE_USER_ID=ZWESVUSR/ZOWE_USER_ID=zowe/g' /home/zowe/install/bin/zowe-setup-certificates.env
    sed -i 's/ZOWE_GROUP_ID=ZWEADMIN/ZOWE_GROUP_ID=zowe/g' /home/zowe/install/bin/zowe-setup-certificates.env

    if [ -z "$VERIFY_CERTIFICATES" ]; then
        sed -i 's/VERIFY_CERTIFICATES=true/VERIFY_CERTIFICATES=false/g' /home/zowe/install/bin/zowe-setup-certificates.env
    fi
    if [ -z "$NONSTRICT_VERIFY_CERTIFICATES" ]; then
        sed -i 's/NONSTRICT_VERIFY_CERTIFICATES=true/NONSTRICT_VERIFY_CERTIFICATES=false/g' /home/zowe/install/bin/zowe-setup-certificates.env
    fi
    sed -i 's/HOSTNAME=.*/HOSTNAME='"${ZOWE_EXPLORER_HOST}"'/g' /home/zowe/install/bin/zowe-setup-certificates.env
    sed -i 's/IPADDRESS=.*/IPADDRESS='"${ZOWE_IP_ADDRESS}"'/g' /home/zowe/install/bin/zowe-setup-certificates.env

#cat /home/zowe/install/bin/zowe-setup-certificates.env

    /home/zowe/install/bin/zowe-setup-certificates.sh
    sed -i 's/-ebcdic//' /global/zowe/keystore/zowe-certificates.env
fi


if [ ! -d "/home/zowe/external_instance" ]; then
    cp /home/zowe/instance/instance.env.bkp /home/zowe/instance/instance.env

    input2="/home/zowe/instance/instance.env.bkp"
    while read -r line
    do
        test -z "${line%%#*}" && continue      # skip line if first char is #
        key=${line%%=*}
        if [ -n "${!key}" ]
        then
            echo "Replacing key=${key} with val=${!key}"
            sed -i 's@'${key}'=.*@'${key}'='"${!key}"'@g' /home/zowe/instance/instance.env
        fi
    done < "$input2"
fi

bash /home/zowe/instance/bin/internal/run-zowe.sh
sleep infinity
