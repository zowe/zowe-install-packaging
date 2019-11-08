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

# TODO NOW - think about how/where logging is done
while getopts "c:" opt; do
  case $opt in
    c) INSTANCE_DIR=$OPTARG;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $OPTIND-1

export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../../;pwd)

# Ensure that newly created files are in EBCDIC codepage
export _CEE_RUNOPTS=""
export _TAG_REDIR_IN=""
export _TAG_REDIR_OUT=""
export _TAG_REDIR_ERR=""
export _BPXK_AUTOCVT="OFF"

#TODO NOW - allow user to interactively set via prompt?
if [[ -z ${INSTANCE_DIR} ]]
then
  "-c parameter not set. Defaulting instance directory to /global/zowe"
  INSTANCE_DIR="/global/zowe"
fi

 # TODO NOW - Check if directory isn't writable - what happens
create_new_instance() {
    echo "Creating new zowe instance in ${INSTANCE_DIR}..."
    mkdir -p ${INSTANCE_DIR}/bin/internal

    # Try and work out the variables that we can
    ${ZOWE_ROOT_DIR}/bin/zowe-init.sh

    # TODO - remove some of these overrides once we get rid of the yaml file
    sed \
        -e "s#{{root_dir}}#${ZOWE_ROOT_DIR}#" \
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
        -e "s#{{external_certificate_authorities}}#${ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES}#" \
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
        -e "s#ZOWE_EXPLORER_JES_UI_PORT=8546#ZOWE_EXPLORER_JES_UI_PORT=${ZOWE_EXPLORER_JES_UI_PORT}#" \
        -e "s#ZOWE_EXPLORER_MVS_UI_PORT=8548#ZOWE_EXPLORER_MVS_UI_PORT=${ZOWE_EXPLORER_MVS_UI_PORT}#" \
        -e "s#ZOWE_EXPLORER_USS_UI_PORT=8550#ZOWE_EXPLORER_USS_UI_PORT=${ZOWE_EXPLORER_USS_UI_PORT}#" \
        -e "s#ZOWE_ZLUX_SERVER_HTTPS_PORT=8544#ZOWE_ZLUX_SERVER_HTTPS_PORT=${ZOWE_ZLUX_SERVER_HTTPS_PORT}#" \
        -e "s#ZOWE_ZSS_SERVER_PORT=8542#ZOWE_ZSS_SERVER_PORT=${ZOWE_ZSS_SERVER_PORT}#" \
        -e "s#ZOWE_ZSS_XMEM_SERVER_NAME=ZWESIS_STD#ZOWE_ZSS_XMEM_SERVER_NAME=${ZOWE_ZSS_XMEM_SERVER_NAME}#" \
        -e "s#ZOWE_ZLUX_SSH_PORT=22#ZOWE_ZLUX_SSH_PORT=${ZOWE_ZLUX_SSH_PORT}#" \
        -e "s#ZOWE_ZLUX_TELNET_PORT=23#ZOWE_ZLUX_TELNET_PORT=${ZOWE_ZLUX_TELNET_PORT}#" \
        -e "s#ZOWE_ZLUX_SECURITY_TYPE=#ZOWE_ZLUX_SECURITY_TYPE=${ZOWE_ZLUX_SECURITY_TYPE}#" \
        -e "s#ZOWE_SERVER_PROCLIB_MEMBER=ZOWESVR#ZOWE_SERVER_PROCLIB_MEMBER=${ZOWE_SERVER_PROCLIB_MEMBER}#" \
        "${ZOWE_ROOT_DIR}/scripts/instance.template.env" \
        > "${INSTANCE_DIR}/instance.env"
        chmod -R 750 "${INSTANCE_DIR}/instance.env"

cat <<EOF >${INSTANCE_DIR}/bin/read-instance.sh
export INSTANCE_DIR=\$(cd \$(dirname \$0)/../;pwd)
# Read in properties by executing, then export all the keys so we don't need to shell share
. \${INSTANCE_DIR}/instance.env

while read -r line
do
    test -z "\${line%%#*}" && continue      # skip line if first char is #
    key=\${line%%=*}
    export $key
done < \${INSTANCE_DIR}/instance.env
EOF

cat <<EOF >${INSTANCE_DIR}/bin/zowe-start.sh
export INSTANCE_DIR=\$(cd \$(dirname \$0)/../;pwd)
\${INSTANCE_DIR}/bin/read-instance.sh

\$ZOWE_ROOT_DIR/scripts/internal/opercmd \
    "S \${ZOWE_SERVER_PROCLIB_MEMBER},INSTANCE='"\${INSTANCE_DIR}"'",JOBNAME=\${ZOWE_PREFIX}\${ZOWE_INSTANCE}SV
echo Start command issued, check SDSF job log ...
EOF

cat <<EOF >${INSTANCE_DIR}/bin/internal/run-zowe.sh
export INSTANCE_DIR=\$(cd \$(dirname \$0)/../;pwd)
\${INSTANCE_DIR}/bin/read-instance.sh
\${ZOWE_ROOT_DIR}/bin/internal/run-zowe.sh -c \${INSTANCE_DIR}
EOF

cat <<EOF >${INSTANCE_DIR}/bin/zowe-stop.sh
export INSTANCE_DIR=\$(cd \$(dirname \$0)/../;pwd)
\${INSTANCE_DIR}/bin/read-instance.sh

\$ZOWE_ROOT_DIR/scripts/internal/opercmd "c \${ZOWE_PREFIX}\${ZOWE_INSTANCE}SV"
EOF

  # Make the instance directory writable by all so the zowe process can use it, but not the bin directory so people can't maliciously edit it
  chmod -R 777 ${INSTANCE_DIR}
  chmod -R 751 ${INSTANCE_DIR}/bin

  $(chgrp -R ${ZOWE_ZOSMF_ADMIN_GROUP} ${INSTANCE_DIR})
  AUTH_RETURN_CODE=$?
  if [[ $AUTH_RETURN_CODE != "0" ]]; then
      chmod -R 755 ${INSTANCE_DIR}/bin
  fi
}

check_existing_instance_for_updates() {
    # TODO NOW
    echo "Going to check existing instance ${INSTANCE_DIR} for updates"
}

#Check if instance directory already exists
if [[ -d ${INSTANCE_DIR} ]]
then
  check_existing_instance_for_updates
else 
  create_new_instance
fi