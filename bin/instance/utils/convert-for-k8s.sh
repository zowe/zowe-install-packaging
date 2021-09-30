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
# -c    Optional. Path to instance directory
# -x    Optional. Kubernetes cluster external domain names separated by comma.
#       Default is localhost.
# -n    Optional. Kubernetes cluster namespace where Zowe will run.
#       Default is zowe.
# -u    Optional. Kubernetes cluster name.
#       Default is cluster.local.
# -p    Optional. Password of local certificate authority PKCS#12 file.
#       Default is local_ca_password.
# -a    Optional. Certificate alias of local certificate authority.
#       Default is localca.
# -v    Optional. Enable verbose mode to display more debugging information.
#
# FIXME: to support keyring
# FIXME: to support external certificates
# FIXME: to support zowe.yaml
################################################################################

################################################################################
# Functions
_cmd() {
  cmd=$(echo $@)
  if [ -n "${VERBOSE_MODE}" ]; then
    echo "> Execute: ${cmd}"
  fi
  ${cmd}
}
base64() {
  uuencode -m "$1" dummy | sed '1d;$d' | tr -d '\n'
}
indent() {
  cat "$1" | sed "s/^/$2/"
}
generate_k8s_certificate() {
  k8s_temp_keystore=$1

  utils_dir="${ROOT_DIR}/bin/utils"
  zct="${utils_dir}/ncert/src/cli.js"

  alt_names=
  for host in $(echo "${ZWE_EXTERNAL_HOSTS}" | sed 's#[,]# #g'); do
    alt_names="${alt_names} --alt ${host}"
  done
  alt_names="${alt_names} --alt localhost.localdomain"
  alt_names="${alt_names} --alt localhost"
  alt_names="${alt_names} --alt 127.0.0.1"
  alt_names="${alt_names} --alt '*.${ZWE_KUBERNETES_NAMESPACE}.pod.${ZWE_KUBERNETES_CLUSTERNAME}'"
  alt_names="${alt_names} --alt '*.${ZWE_KUBERNETES_NAMESPACE}.svc.${ZWE_KUBERNETES_CLUSTERNAME}'"

  new_k8s_keystore="${k8s_temp_keystore}-k8s"

  echo "> Generate new keystore suitable for Kubernetes - ${new_k8s_keystore}"
  _cmd node "${zct}" pkcs12 generate "${KEY_ALIAS}" \
    ${VERBOSE_MODE} \
    --ca "${KEYSTORE_DIRECTORY}/${LOCAL_CA_FILENAME}.keystore.p12" \
    --cap "${LOCAL_CA_PASSWORD}" \
    --caa "${LOCAL_CA_ALIAS}" \
    -f "${new_k8s_keystore}" \
    -p "${KEYSTORE_PASSWORD}" \
    ${alt_names}

  if [ ! -f "${new_k8s_keystore}" ]; then
    >&2 echo "Error: failed to generate keystore for Kubernetes"
    exit 1
  fi
  # tag as binary to avoid node.js convert encoding
  chtag -b "${new_k8s_keystore}"

  # export new key and cert
  _cmd node "${zct}" pkcs12 export \
    "${new_k8s_keystore}" "${KEY_ALIAS}" -p "${KEYSTORE_PASSWORD}" -f "${k8s_temp_keystore}-cert"
  _cmd node "${zct}" pkcs12 export \
    "${new_k8s_keystore}" "${KEY_ALIAS}" -p "${KEYSTORE_PASSWORD}" -k -f "${k8s_temp_keystore}-key"

  # import to original keystore
  echo "> Merge new keystore with original, and store as ${k8s_temp_keystore}"
  _cmd keytool -importkeystore ${VERBOSE_MODE} -noprompt \
    -srckeystore "${new_k8s_keystore}" \
    -srcstoretype PKCS12 \
    -srcstorepass "${KEYSTORE_PASSWORD}" \
    -keypass "${KEYSTORE_PASSWORD}" \
    -destkeystore "${k8s_temp_keystore}" \
    -deststoretype PKCS12 \
    -deststorepass "${KEYSTORE_PASSWORD}"

  # remove the temporary keystore
  rm -f "${new_k8s_keystore}"

  if [ -n "${VERBOSE_MODE}" ]; then
    # show content of the keystore
    echo "> New keystore information"
    _cmd node "${zct}" pkcs12 info "${k8s_temp_keystore}" -p "${KEYSTORE_PASSWORD}" ${VERBOSE_MODE}
  fi

  echo
}

################################################################################
# Constants and variables
INSTANCE_DIR=$(cd $(dirname $0)/../../;pwd)
ZWE_KUBERNETES_NAMESPACE=zowe
ZWE_KUBERNETES_CLUSTERNAME=cluster.local
LOCAL_CA_PASSWORD=local_ca_password
LOCAL_CA_ALIAS=localca
LOCAL_CA_FILENAME="local_ca/localca"
ZWE_EXTERNAL_HOSTS=localhost
VERBOSE_MODE=

# command line parameters
OPTIND=1
while getopts "c:x:n:u:p:a:v" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    x) ZWE_EXTERNAL_HOSTS=${OPTARG};;
    n) ZWE_KUBERNETES_NAMESPACE=${OPTARG};;
    u) ZWE_KUBERNETES_CLUSTERNAME=${OPTARG};;
    p) LOCAL_CA_PASSWORD=${OPTARG};;
    a) LOCAL_CA_ALIAS=${OPTARG};;
    v) VERBOSE_MODE="-v";;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

# validate INSTANCE_DIR
if [ ! -f "${INSTANCE_DIR}/instance.env" ]; then
  >&2 echo "Error: instance directory doesn't have instance.env."
  exit 1
fi

# source utility scripts
[ -z "$(is_instance_utils_sourced 2>/dev/null || true)" ] && . ${INSTANCE_DIR}/bin/internal/utils.sh
read_essential_vars
[ -z "$(is_runtime_utils_sourced 2>/dev/null || true)" ] && . ${ROOT_DIR}/bin/utils/utils.sh

# validate ROOT_DIR
if [ -z "${ROOT_DIR}" ]; then
  >&2 echo "Error: cannot determine runtime root directory."
  exit 1
fi

# import common environment variables to make sure node runs properly
. "${ROOT_DIR}/bin/internal/zowe-set-env.sh"

# validate KEYSTORE_DIRECTORY
if [ -z "${KEYSTORE_DIRECTORY}" ]; then
  >&2 echo "Error: cannot determine keystore directory. Please supply with parameter of this script."
  exit 1
fi
if [ ! -f "${KEYSTORE_DIRECTORY}/zowe-certificates.env" ]; then
  >&2 echo "Error: keystore directory doesn't have zowe-certificates.env."
  exit 1
fi

# import keystore configs
. "${KEYSTORE_DIRECTORY}/zowe-certificates.env"

if [ "${KEYSTORE_TYPE}" != "PKCS12" ]; then
  >&2 echo "Error: keystore type ${KEYSTORE_TYPE} is not supported yet."
  exit 1
fi

if [ "${ZOWE_APIM_VERIFY_CERTIFICATES}" != "true" -a "${ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES}" != "true" ]; then
  >&2 echo "!WARNING!: it's not recommended to turn both VERIFY_CERTIFICATES and NONSTRICT_VERIFY_CERTIFICATES off for security reasons."
  >&2 echo
fi

tmp_dir=$(get_tmp_dir)
prefix=zowe-convert-for-k8s-$(echo $RANDOM)-
k8s_temp_keystore="${tmp_dir}/${prefix}${KEY_ALIAS}.keystore.p12"
if [ -n "${EXTERNAL_CERTIFICATE_AUTHORITIES}" ]; then
  echo "It seems you are using certficates NOT generated by Zowe."
  echo

  if [ "${ZOWE_APIM_VERIFY_CERTIFICATES}" = "true" ]; then
    echo "To make certificates working in Kubernetes, the certficate you are using should have"
    echo "these domains defined in Subject Alt Name (SAN):"
    echo
    echo "- ${ZWE_EXTERNAL_HOSTS}"
    echo "- *.${ZWE_KUBERNETES_NAMESPACE}.svc.${ZWE_KUBERNETES_CLUSTERNAME}"
    echo "- *.${ZWE_KUBERNETES_NAMESPACE}.pod.${ZWE_KUBERNETES_CLUSTERNAME}"
    echo
    echo "Otherwise you may see warnings/errors related to certificate validation."
    echo
    echo "If you cannot add those domains into certificate Subject Alt Name (SAN), you can turn"
    echo "off VERIFY_CERTIFICATES but keep NONSTRICT_VERIFY_CERTIFICATES on. Zowe components"
    echo "will not validate domain names but will continue to validate certificate chain,"
    echo "validity and whether it's trusted in Zowe truststore. It's not recommended to turn"
    echo "off NONSTRICT_VERIFY_CERTIFICATES."
    echo
  fi
else
  echo "It seems you are using Zowe generated certficates."
  echo

  if [ "${ZOWE_APIM_VERIFY_CERTIFICATES}" = "true" ]; then
    echo "To make the certficates working properly in Kubernetes, we need to generate"
    echo "a new certificate with proper domains."
    echo "You can customize domains by passing -x option to this utility script."
    echo

    echo "Info: NODE_HOME and JAVA_HOME are required to generate new certificate"
    echo

    # we need node and keytool for following commands
    ensure_node_is_on_path 1>/dev/null 2>&1
    ensure_java_is_on_path 1>/dev/null 2>&1

    # PKCS#12 keystores should be tagged as binary to avoid node.js tries to convert encoding
    find "${KEYSTORE_DIRECTORY}" -name '*.p12' | xargs chtag -b

    cp "${KEYSTORE}" "${k8s_temp_keystore}"
    if [ ! -f "${k8s_temp_keystore}" ]; then
      >&2 echo "Error: failed to copy original keystore to temporary directory"
      exit 1
    fi

    generate_k8s_certificate "${k8s_temp_keystore}"

    # this is our new keystore for k8s
    KEYSTORE="${k8s_temp_keystore}"
    KEYSTORE_KEY="${k8s_temp_keystore}-key"
    KEYSTORE_CERTIFICATE="${k8s_temp_keystore}-cert"
  elif [ "${ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES}" = "true" ]; then
    echo "You are using Non-Strict verify certificate mode. You existing certificates"
    echo "should work in Kubernetes without change."
    echo
  fi
fi

ORIGINAL_ZOWE_EXPLORER_HOST=$(. "${INSTANCE_DIR}/instance.env" && echo $ZOWE_EXPLORER_HOST)
NEW_INSATNCE_ENV_CONTENT=$(cat "${INSTANCE_DIR}"/instance.env | \
  grep -v -E "(ZWE_EXTERNAL_HOSTS=|ZOWE_EXTERNAL_HOST=|ZOWE_ZOS_HOST=|ZOWE_IP_ADDRESS=|ZWE_LAUNCH_COMPONENTS=|JAVA_HOME=|NODE_HOME=|SKIP_NODE=|skip using nodejs)" | \
  sed -e "/ZOWE_EXPLORER_HOST=.*/a\\
  ZWE_EXTERNAL_HOSTS=${ZWE_EXTERNAL_HOSTS}" | \
  sed -e "/ZWE_EXTERNAL_HOSTS=.*/a\\
  ZOWE_EXTERNAL_HOST=\$(echo \"\${ZWE_EXTERNAL_HOSTS}\" | awk -F, '{print \$1}' | tr -d '[[:space:]]')" | \
  sed -e "/ZOWE_EXPLORER_HOST=.*/a\\
  ZOWE_ZOS_HOST=${ORIGINAL_ZOWE_EXPLORER_HOST}" | \
  grep -v -E "ZOWE_EXPLORER_HOST=" | \
  sed -e "s#ROOT_DIR=.\+\$#ROOT_DIR=/home/zowe/runtime#" | \
  sed -e "s#KEYSTORE_DIRECTORY=.\+\$#KEYSTORE_DIRECTORY=/home/zowe/keystore#" | \
  sed -e "s#CATALOG_PORT=.\+\$#CATALOG_PORT=7552#" | \
  sed -e "s#DISCOVERY_PORT=.\+\$#DISCOVERY_PORT=7553#" | \
  sed -e "s#GATEWAY_PORT=.\+\$#GATEWAY_PORT=7554#" | \
  sed -e "s#ZWE_CACHING_SERVICE_PORT=.\+\$#ZWE_CACHING_SERVICE_PORT=7555#" | \
  sed -e "s#JOBS_API_PORT=.\+\$#JOBS_API_PORT=7558#" | \
  sed -e "s#FILES_API_PORT=.\+\$#FILES_API_PORT=7559#" | \
  sed -e "s#JES_EXPLORER_UI_PORT=.\+\$#JES_EXPLORER_UI_PORT=8546#" | \
  sed -e "s#MVS_EXPLORER_UI_PORT=.\+\$#MVS_EXPLORER_UI_PORT=8548#" | \
  sed -e "s#USS_EXPLORER_UI_PORT=.\+\$#USS_EXPLORER_UI_PORT=8550#" | \
  sed -e "s#ZOWE_ZLUX_SERVER_HTTPS_PORT=.\+\$#ZOWE_ZLUX_SERVER_HTTPS_PORT=7556#" | \
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
# start official output
echo "Please copy all output below, save them as a YAML file on your local computer,"
echo "then apply it to your Kubernetes cluster."
echo
echo "  Example: kubectl apply -f /path/to/my/local-saved.yaml"
echo

################################################################################
# Prepare configs
cat << EOF
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: zowe-config
  namespace: ${ZWE_KUBERNETES_NAMESPACE}
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
  namespace: ${ZWE_KUBERNETES_NAMESPACE}
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
  namespace: ${ZWE_KUBERNETES_NAMESPACE}
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

# remove temporary keystore
if [ -f "${k8s_temp_keystore}" ]; then
  rm -f "${tmp_dir}/${prefix}"*
fi
