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
# - optional, path to keystore directory. By default it will use the keystore
#             and certificates used by current instance.
#
# Note: this utility requires node.js.
#
# FIXME: to support keyring
# FIXME: to support external certificates
# FIXME: to support zowe.yaml
################################################################################

################################################################################
# Functions
base64() {
  node -e "const fs=require('fs');console.log(Buffer.from(fs.readFileSync('$1'), 'utf8').toString('base64'));"
}
indent() {
  cat "$1" | sed "s/^/$2/"
}

################################################################################
# Constants and variables
INSTANCE_DIR=$(cd $(dirname $0)/../../;pwd)
KEYSTORE_DIRECTORY_PARM=$1

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
if [ -n "${KEYSTORE_DIRECTORY_PARM}" ]; then
  KEYSTORE_DIRECTORY=${KEYSTORE_DIRECTORY_PARM}
fi
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

################################################################################
# Prepare configs
cat << EOF
---
kind: ConfigMap 
apiVersion: v1 
metadata:
  name: zowe-config
  namespace: zowe
data:
  instance.env: |
$(cat "${INSTANCE_DIR}"/instance.env | grep -v -E "(ZOWE_EXPLORER_HOST=|ZOWE_IP_ADDRESS=|JAVA_HOME=|NODE_HOME=|SKIP_NODE=|skip using nodejs)" | sed -e 's#ROOT_DIR=.\+$#ROOT_DIR=/home/zowe/runtime#' -e 's#KEYSTORE_DIRECTORY=.\+$#KEYSTORE_DIRECTORY=/home/zowe/keystore#' | indent - "    ")
EOF

cat << EOF
---
kind: ConfigMap 
apiVersion: v1 
metadata:
  name: zowe-certificates-cm
  namespace: zowe
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
