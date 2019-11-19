#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019
################################################################################

while getopts "c:y" opt; do
  case $opt in
    c) INSTANCE_DIR=$OPTARG;;
    y) YAML_OVERRIDE=true;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

# TODO LATER - once not called from zowe-configure.sh remove if and keep the export
if [[ -z ${ZOWE_ROOT_DIR} ]]
then
	export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../;pwd)
fi

# Ensure that newly created files are in EBCDIC codepage
export _CEE_RUNOPTS=""
export _TAG_REDIR_IN=""
export _TAG_REDIR_OUT=""
export _TAG_REDIR_ERR=""
export _BPXK_AUTOCVT="OFF"

if [[ -z ${INSTANCE_DIR} ]]
then
  echo "-c parameter not set. Please re-run 'zowe-configure-instance.sh -c <Instance directory>' specifying the location of the new zowe instance directory you want to create"
  exit 1
fi

create_new_instance() {
    echo "Creating new zowe instance in ${INSTANCE_DIR}..."
    $(mkdir -p ${INSTANCE_DIR}/bin/internal)
    DIRECTORY_CREATE_RC=$?
    if [[ $DIRECTORY_CREATE_RC != "0" ]]
    then
      echo "We could not create the instance directory and sub-directories in ${INSTANCE_DIR}. Please check permissions and re-run."
      exit 1
    fi

    LOG_DIR=${INSTANCE_DIR}/logs
    mkdir -p ${LOG_DIR}
    export LOG_FILE=${LOG_DIR}/"configure-`date +%Y-%m-%d-%H-%M-%S`.log"
    echo "Created instance directory ${INSTANCE_DIR}" >> $LOG_FILE

    # Try and work out the variables that we can
    . ${ZOWE_ROOT_DIR}/bin/zowe-init.sh
    echo "Ran zowe-init.sh from ${ZOWE_ROOT_DIR}/bin/zowe-init.sh" >> $LOG_FILE

    sed \
        -e "s#{{root_dir}}#${ZOWE_ROOT_DIR}#" \
        -e "s#{{java_home}}#${ZOWE_JAVA_HOME}#" \
        -e "s#{{node_home}}#${ZOWE_NODE_HOME}#" \
        -e "s#{{zosmf_port}}#${ZOWE_ZOSMF_PORT}#" \
        -e "s#{{zosmf_host}}#${ZOWE_ZOSMF_HOST}#" \
        -e "s#{{zowe_explorer_host}}#${ZOWE_EXPLORER_HOST}#" \
        -e "s#{{zowe_ip_address}}#${ZOWE_IP_ADDRESS}#" \
        "${ZOWE_ROOT_DIR}/scripts/instance.template.env" \
        > "${INSTANCE_DIR}/instance.env"

      # TODO - remove overrides once we get rid of the yaml file
        if [[ ! -z ${YAML_OVERRIDE} ]]
        then
          sed \
            -e "s#ZOWE_PREFIX=ZOWE#ZOWE_PREFIX=${ZOWE_PREFIX}#" \
            -e "s#ZOWE_INSTANCE=1#ZOWE_INSTANCE=${ZOWE_INSTANCE}#" \
            -e "s#ZOSMF_USERID=IZUSVR#ZOSMF_USERID=${ZOWE_ZOSMF_USERID}#" \
            -e "s#ZOSMF_ADMIN_GROUP=IZUADMIN#ZOSMF_ADMIN_GROUP=${ZOWE_ZOSMF_ADMIN_GROUP}#" \
            -e "s#ZOSMF_KEYRING=IZUKeyring.IZUDFLT#ZOSMF_KEYRING=${ZOWE_ZOSMF_KEYRING}#" \
            -e "s#CATALOG_PORT=7552#CATALOG_PORT=${ZOWE_APIM_CATALOG_PORT}#" \
            -e "s#DISCOVERY_PORT=7553#DISCOVERY_PORT=${ZOWE_APIM_DISCOVERY_PORT}#" \
            -e "s#GATEWAY_PORT=7554#GATEWAY_PORT=${ZOWE_APIM_GATEWAY_PORT}#" \
            -e "s#ZOWE_APIM_VERIFY_CERTIFICATES=true#ZOWE_APIM_VERIFY_CERTIFICATES=${ZOWE_APIM_VERIFY_CERTIFICATES}#" \
            -e "s#APIML_ENABLE_SSO=false#APIML_ENABLE_SSO=${ZOWE_APIM_ENABLE_SSO}#" \
            -e "s#JOBS_API_PORT=8545#JOBS_API_PORT=${ZOWE_EXPLORER_SERVER_JOBS_PORT}#" \
            -e "s#FILES_API_PORT=8547#FILES_API_PORT=${ZOWE_EXPLORER_SERVER_DATASETS_PORT}#" \
            -e "s#JES_EXPLORER_UI_PORT=8546#JES_EXPLORER_UI_PORT=${ZOWE_EXPLORER_JES_UI_PORT}#" \
            -e "s#MVS_EXPLORER_UI_PORT=8548#MVS_EXPLORER_UI_PORT=${ZOWE_EXPLORER_MVS_UI_PORT}#" \
            -e "s#USS_EXPLORER_UI_PORT=8550#USS_EXPLORER_UI_PORT=${ZOWE_EXPLORER_USS_UI_PORT}#" \
            -e "s#ZOWE_ZLUX_SERVER_HTTPS_PORT=8544#ZOWE_ZLUX_SERVER_HTTPS_PORT=${ZOWE_ZLUX_SERVER_HTTPS_PORT}#" \
            -e "s#ZOWE_ZSS_SERVER_PORT=8542#ZOWE_ZSS_SERVER_PORT=${ZOWE_ZSS_SERVER_PORT}#" \
            -e "s#ZOWE_ZSS_XMEM_SERVER_NAME=ZWESIS_STD#ZOWE_ZSS_XMEM_SERVER_NAME=${ZOWE_ZSS_XMEM_SERVER_NAME}#" \
            -e "s#ZOWE_ZLUX_SSH_PORT=22#ZOWE_ZLUX_SSH_PORT=${ZOWE_ZLUX_SSH_PORT}#" \
            -e "s#ZOWE_ZLUX_TELNET_PORT=23#ZOWE_ZLUX_TELNET_PORT=${ZOWE_ZLUX_TELNET_PORT}#" \
            -e "s#ZOWE_ZLUX_SECURITY_TYPE=#ZOWE_ZLUX_SECURITY_TYPE=${ZOWE_ZLUX_SECURITY_TYPE}#" \
            -e "s#ZOWE_SERVER_PROCLIB_MEMBER=ZOWESVR#ZOWE_SERVER_PROCLIB_MEMBER=${ZOWE_SERVER_PROCLIB_MEMBER}#" \
            "${INSTANCE_DIR}/instance.env" \
            > "${INSTANCE_DIR}/instance.yaml.env"
            mv "${INSTANCE_DIR}/instance.yaml.env" "${INSTANCE_DIR}/instance.env"
        fi

        chmod -R 750 "${INSTANCE_DIR}/instance.env"
        echo "Created ${INSTANCE_DIR}/instance.env with injected content">> $LOG_FILE

cat <<EOF >${INSTANCE_DIR}/bin/read-instance.sh
# Requires INSTANCE_DIR to be set
# Read in properties by executing, then export all the keys so we don't need to shell share
. \${INSTANCE_DIR}/instance.env

while read -r line
do
    test -z "\${line%%#*}" && continue      # skip line if first char is #
    key=\${line%%=*}
    export \$key
done < \${INSTANCE_DIR}/instance.env
EOF
echo "Created ${INSTANCE_DIR}/bin/read-instance.sh">> $LOG_FILE

cat <<EOF >${INSTANCE_DIR}/bin/internal/run-zowe.sh
export INSTANCE_DIR=\$(cd \$(dirname \$0)/../../;pwd)
. \${INSTANCE_DIR}/bin/read-instance.sh
\${ROOT_DIR}/bin/internal/run-zowe.sh -c \${INSTANCE_DIR}
EOF
echo "Created ${INSTANCE_DIR}/bin/internal/run-zowe.sh">> $LOG_FILE

cat <<EOF >${INSTANCE_DIR}/bin/zowe-start.sh
set -e
export INSTANCE_DIR=\$(cd \$(dirname \$0)/../;pwd)
. \${INSTANCE_DIR}/bin/read-instance.sh

\${ROOT_DIR}/scripts/internal/opercmd \"S \${ZOWE_SERVER_PROCLIB_MEMBER},INSTANCE='"\${INSTANCE_DIR}"',JOBNAME=\${ZOWE_PREFIX}\${ZOWE_INSTANCE}SV\"
echo Start command issued, check SDSF job log ...
EOF
echo "Created ${INSTANCE_DIR}/bin/zowe-start.sh">> $LOG_FILE

cat <<EOF >${INSTANCE_DIR}/bin/zowe-stop.sh
set -e
export INSTANCE_DIR=\$(cd \$(dirname \$0)/../;pwd)
. \${INSTANCE_DIR}/bin/read-instance.sh

\${ROOT_DIR}/scripts/internal/opercmd "c \${ZOWE_PREFIX}\${ZOWE_INSTANCE}SV"
EOF
echo "Created ${INSTANCE_DIR}/bin/zowe-stop.sh">> $LOG_FILE

  # Make the instance directory writable by all so the zowe process can use it, but not the bin directory so people can't maliciously edit it
  chmod -R 777 ${INSTANCE_DIR}
  chmod -R 755 ${INSTANCE_DIR}/bin

  echo "zowe-configure-instance.sh completed">> $LOG_FILE
}

check_existing_instance_for_updates() {
    LOG_DIR=${INSTANCE_DIR}/logs
    mkdir -p ${LOG_DIR}
    export LOG_FILE=${LOG_DIR}/"configure-`date +%Y-%m-%d-%H-%M-%S`.log"

    echo "Checking existing instance ${INSTANCE_DIR} for updated properties" | tee -a ${LOG_FILE}

    # get a list of variables, from the template instance and the existing config to see which ones are missing and add them to the instance
    TEMPLATE=${ZOWE_ROOT_DIR}/scripts/instance.template.env
    INSTANCE=${INSTANCE_DIR}/instance.env

    while read -r line
    do
        test -z "${line%%#*}" && continue      # skip line if first char is #
        key=${line%%=*}
        PROP_VALUE=`cat $INSTANCE | grep ^$key=`
        if [[ -z $PROP_VALUE ]]
        then
          LINES_TO_APPEND=${LINES_TO_APPEND}"${line}\n"
      fi
    done < ${TEMPLATE}

    if [[ -n $LINES_TO_APPEND ]]
    then
      if [[ $LINES_TO_APPEND == *"{{"* ]]
	    then
      	. ${ZOWE_ROOT_DIR}/bin/zowe-init.sh
    
        LINES_TO_APPEND=$(echo "$LINES_TO_APPEND" | sed \
          -e "s#{{java_home}}#${ZOWE_JAVA_HOME}#" \
          -e "s#{{node_home}}#${NODE_HOME}#" \
          -e "s#{{zosmf_port}}#${ZOWE_ZOSMF_PORT}#" \
          -e "s#{{zosmf_host}}#${ZOWE_ZOSMF_HOST}#" \
          -e "s#{{zowe_explorer_host}}#${ZOWE_EXPLORER_HOST}#" \
          -e "s#{{zowe_ip_address}}#${ZOWE_IP_ADDRESS}#" \
          -e "s#{{key_alias}}#localhost#" \
          -e "s#{{keystore}}#${ZOWE_ROOT_DIR}/components/api-mediation/keystore/localhost/localhost.keystore.p12#" \
          -e "s#{{keystore_password}}#password#" \
          -e "s#{{keystore_key}}#${ZOWE_ROOT_DIR}/components/api-mediation/keystore/localhost/localhost.keystore.key#" \
          -e "s#{{keystore_certificate}}#${ZOWE_ROOT_DIR}/components/api-mediation/keystore/localhost/localhost.keystore.cer-ebcdic#" \
          -e "s#{{truststore}}#${ZOWE_ROOT_DIR}/components/api-mediation/keystore/localhost/localhost.truststore.p12#" \
          -e "s#{{external_certificate}}#${ZOWE_APIM_EXTERNAL_CERTIFICATE}#" \
          -e "s#{{external_certificate_alias}}#${ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS}#" \
          -e "s#{{external_certificate_authorities}}#${ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES}#" )
      fi
    
      echo "Missing properties that will be appended to $INSTANCE:\n$LINES_TO_APPEND" | tee -a ${LOG_FILE}
      echo "\n$LINES_TO_APPEND" >> $INSTANCE
      echo "Properties added, please review these before starting zowe."
    else 
      echo "No updates required" | tee -a ${LOG_FILE}
    fi
}

# Check if instance directory already exists
if [[ -d ${INSTANCE_DIR} ]]
then
  check_existing_instance_for_updates
else 
  create_new_instance
fi