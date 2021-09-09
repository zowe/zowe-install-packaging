#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
################################################################################

################################################################################
# This utility script will convert current keystore directory to YAML
# configurations you can use in Kubernetes deployment.
#
# parameter(s):
# - c    Optional. Path to instance directory
# - x    Optional. Kubernetes cluster external domain names separated by comma.
#        Default is localhost.
#
# FIXME: to support keyring
# FIXME: to support external certificates
# FIXME: to support zowe.yaml
################################################################################

################################################################################
# Functions
base64() {
  uuencode -m "$1" dummy | sed '1d;$d' | tr -d '\n'
}
indent() {
  cat "$1" | sed "s/^/$2/"
}

################################################################################
# Constants and variables
INSTANCE_DIR=$(cd $(dirname $0)/../../;pwd)

# command line parameters
OPTIND=1
while getopts "c:x:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    x) ZWE_EXTERNAL_HOSTS=${OPTARG};;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

# validate INSTANCE_DIR
if [ ! -f "${INSTANCE_DIR}/instance.env" ]; then
  echo "Error: instance directory doesn't have instance.env."
  exit 1
fi

# import instance configuration
. ${INSTANCE_DIR}/bin/internal/utils.sh
read_essential_vars

# validate ROOT_DIR
if [ -z "${ROOT_DIR}" ]; then
  echo "Error: cannot determine runtime root directory."
  exit 1
fi

# import common environment variables to make sure node runs properly
. "${ROOT_DIR}/bin/internal/zowe-set-env.sh"

# validate KEYSTORE_DIRECTORY
if [ -z "${KEYSTORE_DIRECTORY}" ]; then
  echo "Error: cannot determine keystore directory. Please supply with parameter of this script."
  exit 1
fi
if [ ! -f "${KEYSTORE_DIRECTORY}/zowe-certificates.env" ]; then
  echo "Error: keystore directory doesn't have zowe-certificates.env."
  exit 1
fi

# import keystore configs
. "${KEYSTORE_DIRECTORY}/zowe-certificates.env"

if [ "${KEYSTORE_TYPE}" != "PKCS12" ]; then
  echo "Error: keystore type ${KEYSTORE_TYPE} is not supported yet."
  exit 1
fi

ORIGINAL_ZOWE_EXPLORER_HOST=$(. "${INSTANCE_DIR}/instance.env" && echo $ZOWE_EXPLORER_HOST)
NEW_INSATNCE_ENV_CONTENT=$(cat "${INSTANCE_DIR}"/instance.env | \
  grep -v -E "(ZWE_EXTERNAL_HOSTS=|ZOWE_EXTERNAL_HOST=|ZOWE_ZOS_HOST=|ZOWE_IP_ADDRESS=|ZWE_LAUNCH_COMPONENTS=|JAVA_HOME=|NODE_HOME=|SKIP_NODE=|skip using nodejs)" | \
  sed -e "/ZOWE_EXPLORER_HOST=.*/a\\
  ZWE_EXTERNAL_HOSTS=${ZWE_EXTERNAL_HOSTS:-localhost}" | \
  sed -e "/ZWE_EXTERNAL_HOSTS=.*/a\\
  ZOWE_EXTERNAL_HOST=\$(echo \"\${ZWE_EXTERNAL_HOSTS}\" | awk -F, '{print \$1}' | tr -d '[[:space:]]')" | \
  sed -e "/ZOWE_EXPLORER_HOST=.*/a\\
  ZOWE_ZOS_HOST=${ORIGINAL_ZOWE_EXPLORER_HOST}" | \
  grep -v -E "ZOWE_EXPLORER_HOST=" | \
  sed -e "s#ROOT_DIR=.\+\$#ROOT_DIR=/home/zowe/runtime#" | \
  sed -e "s#KEYSTORE_DIRECTORY=.\+\$#KEYSTORE_DIRECTORY=/home/zowe/keystore#" | \
  sed -e "s#ZWE_DISCOVERY_SERVICES_LIST=.\+\$#ZWE_DISCOVERY_SERVICES_REPLICAS=1#" | \
  sed -e "s#APIML_GATEWAY_EXTERNAL_MAPPER=.\+\$#APIML_GATEWAY_EXTERNAL_MAPPER=https://\${GATEWAY_HOST}:\${GATEWAY_PORT}/zss/api/v1/certificate/x509/map#" | \
  sed -e "s#APIML_SECURITY_AUTHORIZATION_ENDPOINT_URL=.\+\$#APIML_SECURITY_AUTHORIZATION_ENDPOINT_URL=https://\${GATEWAY_HOST}:\${GATEWAY_PORT}/zss/api/v1/saf-auth#" | \
  sed -e "s#ZOWE_EXPLORER_FRAME_ANCESTORS=.\+\$#ZOWE_EXPLORER_FRAME_ANCESTORS=\${ZOWE_EXTERNAL_HOST}:*,\${ZOWE_EXPLORER_HOST}:*,\${ZOWE_IP_ADDRESS}:*#" | \
  sed -e "s#ZWE_CACHING_SERVICE_PERSISTENT=.\+\$#ZWE_CACHING_SERVICE_PERSISTENT=#" | \
  sed -e "\$a\\
  \\
  ZWED_agent_host=\${ZOWE_ZOS_HOST}\\
  ZWED_agent_https_port=\${ZOWE_ZSS_SERVER_PORT}")

################################################################################
# Prepare configs
cat << EOF
---
kind: ConfigMap 
apiVersion: v1 
metadata:
  name: zowe-config
  namespace: zowe
  labels:
    app.kubernetes.io/name: zowe
    app.kubernetes.io/instance: zowe
    app.kubernetes.io/managed-by: manual
data:
  instance.env: |
$(echo "${NEW_INSATNCE_ENV_CONTENT}" | indent - "    ")
EOF

cat << EOF
---
kind: ConfigMap 
apiVersion: v1 
metadata:
  name: zowe-certificates-cm
  namespace: zowe
  labels:
    app.kubernetes.io/name: zowe
    app.kubernetes.io/instance: zowe
    app.kubernetes.io/managed-by: manual
data:
  zowe-certificates.env: |
    KEY_ALIAS="${KEY_ALIAS}"
    KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD}"
    KEYSTORE="/home/zowe/keystore/keystore.p12"
    KEYSTORE_TYPE="${KEYSTORE_TYPE}"
    TRUSTSTORE="/home/zowe/keystore/truststore.p12"
    KEYSTORE_KEY="/home/zowe/keystore/keystore.key"
    KEYSTORE_CERTIFICATE="/home/zowe/keystore/keystore.cert"
    KEYSTORE_CERTIFICATE_AUTHORITY="/home/zowe/keystore/localca.cert"
    EXTERNAL_ROOT_CA="${EXTERNAL_ROOT_CA}"
    EXTERNAL_CERTIFICATE_AUTHORITIES="${EXTERNAL_CERTIFICATE_AUTHORITIES}"
    ZOWE_APIM_VERIFY_CERTIFICATES=${ZOWE_APIM_VERIFY_CERTIFICATES}
    ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES=${ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES}
    SSO_FALLBACK_TO_NATIVE_AUTH=${SSO_FALLBACK_TO_NATIVE_AUTH}
    PKCS11_TOKEN_NAME="${PKCS11_TOKEN_NAME}"
    PKCS11_TOKEN_LABEL="${PKCS11_TOKEN_LABEL}"
EOF

cat << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: zowe-certificates-secret
  namespace: zowe
  labels:
    app.kubernetes.io/name: zowe
    app.kubernetes.io/instance: zowe
    app.kubernetes.io/managed-by: manual
type: Opaque
data:
  keystore.p12: $(base64 "${KEYSTORE}")
  truststore.p12: $(base64 "${TRUSTSTORE}")
stringData:
  keystore.key: |
$(indent "${KEYSTORE_KEY}" "    ")
  keystore.cert: |
$(indent "${KEYSTORE_CERTIFICATE}" "    ")
  localca.cert: |
$(indent "${KEYSTORE_CERTIFICATE_AUTHORITY}" "    ")
EOF

