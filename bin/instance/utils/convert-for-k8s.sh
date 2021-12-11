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
# -q    Optional. Disable any instructions/comments display. 
# -v    Optional. Enable verbose mode to display more debugging information.
# -e    Optional. Zowe External Port.
#       Default is 7554
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
item_in_list() {
  list=$1
  item=$2

  OLDIFS=$IFS
  IFS=,
  found=
  for one in ${list}; do
    if [ "${one}" = "${item}" ]; then
      found=true
    fi
  done
  IFS=$OLDIFS

  printf "${found}"
}
is_certificate_generated_by_zowe() {
  utils_dir="${ROOT_DIR}/bin/utils"
  zct="${utils_dir}/ncert/src/cli.js"

  if [ "${KEYSTORE_TYPE}" = "PKCS12" ]; then
    info=$(node "${zct}" pkcs12 info "${KEYSTORE}" -p "${KEYSTORE_PASSWORD}" -a "${KEY_ALIAS}" | grep "Issuer:")
    if [ -z "${info}" ]; then
      >&2 echo "Error: cannot find certificate ${KEY_ALIAS} in ${KEYSTORE}."
      exit 1
    fi
    found=$(echo "${info}" | grep "Zowe Development Instances")
    if [ -n "${found}" ]; then
      echo "true"
    fi
  elif [ "${KEYSTORE_TYPE}" = "JCERACFKS" ]; then
    info=$(tsocmd "RACDCERT LIST(LABEL('${KEY_ALIAS}')) ID(${KEYRING_OWNER})" | sed -n '/Issuer/{n;p;}')
    if [ -z "${info}" ]; then
      >&2 echo "Error: cannot find certificate ${KEY_ALIAS} in ${KEYSTORE}."
      exit 1
    fi
    found=$(echo "${info}" | grep "Zowe Development Instances")
    if [ -n "${found}" ]; then
      echo "true"
    fi
  fi
}
export_certificate_from_keyring_to_pkcs12() {
  owner=$1
  label=$2
  temp_hlq=$3
  uss_target=$4
  password=$5
  cert_only=$6

  if [ -n "${VERBOSE_MODE}" ]; then
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "> export ${label} (${owner}) from safkeyring:////${KEYRING_OWNER}/${KEYRING_NAME}"
  fi

  # QUESTION: is irrcerta a bug of keyring_js?
  if [ "${owner}" = "irrcerta" ]; then
    owner=CERTAUTH
  fi

  # delete hlq if it exists and ignore errors
  tsocmd DELETE "'${temp_hlq}'" 2>/dev/null 1>/dev/null || true

  if [ "${cert_only}" != "true" ]; then
    # export cert to p12 format
    if [ "${owner}" = "CERTAUTH" ]; then
      result=$(tsocmd "RACDCERT EXPORT(LABEL('${label}')) CERTAUTH DSN('${temp_hlq}') FORMAT(PKCS12DER) PASSWORD('${KEYSTORE_PASSWORD}')" 2>&1)
    else
      result=$(tsocmd "RACDCERT EXPORT(LABEL('${label}')) ID(${owner}) DSN('${temp_hlq}') FORMAT(PKCS12DER) PASSWORD('${KEYSTORE_PASSWORD}')" 2>&1)
    fi
    # IRRD147I EXPORT in PKCS12 format requires a certificate with an associated non-ICSF private key.  The request is not processed.
    no_private_key=$(echo "${result}" | grep IRRD147I)
    if [ -n "${no_private_key}" ]; then
      # we can only export cert
      cert_only=true
    fi
  fi
  if [ "${cert_only}" = "true" ]; then
    if [ -n "${VERBOSE_MODE}" ]; then
      echo "- certificate doesn't have private key"
    fi
    # export cert to PEM format
    if [ "${owner}" = "CERTAUTH" ]; then
      result=$(tsocmd "RACDCERT EXPORT(LABEL('${label}')) CERTAUTH DSN('${temp_hlq}') FORMAT(CERTB64)" 2>&1)
    else
      result=$(tsocmd "RACDCERT EXPORT(LABEL('${label}')) ID(${owner}) DSN('${temp_hlq}') FORMAT(CERTB64)" 2>&1)
    fi
    rm -f "${uss_target}-tmp"
    cp "//'${temp_hlq}'" "${uss_target}-tmp"
    rm -f "${uss_target}-850"
    iconv -f IBM-1047 -t IBM-850 "${uss_target}-tmp" > "${uss_target}-850"
    # if [ -n "${VERBOSE_MODE}" ]; then
    #   keytool -printcert -file "${uss_target}-850"
    #   echo
    # fi

    _cmd keytool -importcert ${VERBOSE_MODE} -noprompt -trustcacerts \
      -alias "${label}" \
      -file "${uss_target}-850" \
      -keypass "${password}" \
      -keystore "${uss_target}" \
      -storetype PKCS12 \
      -storepass "${password}"
    rm -f "${uss_target}-tmp"
    rm -f "${uss_target}-850"
  else
    rm -f "${uss_target}-tmp"
    cp -B "//'${temp_hlq}'" "${uss_target}-tmp"
    # if [ -n "${VERBOSE_MODE}" ]; then
    #   keytool -list -v -keystore "${uss_target}-tmp" -storepass "${password}" -storetype PKCS12
    # fi

    _cmd keytool -importkeystore ${VERBOSE_MODE} -noprompt \
      -srckeystore "${uss_target}-tmp" \
      -srcstoretype PKCS12 \
      -srcstorepass "${password}" \
      -keypass "${password}" \
      -destkeystore "${uss_target}" \
      -deststoretype PKCS12 \
      -deststorepass "${password}"
    rm -f "${uss_target}-tmp"
  fi
  if [ -n "${VERBOSE_MODE}" ]; then
    echo
  fi

  # delete hlq if it exists and ignore errors
  tsocmd DELETE "'${temp_hlq}'" 2>/dev/null 1>/dev/null || true
}
export_certificate_from_keyring_to_pem() {
  label=$1
  target=$2

  utils_dir="${ROOT_DIR}/bin/utils"
  zct="${utils_dir}/ncert/src/cli.js"

  if [ -n "${VERBOSE_MODE}" ]; then
    echo "> export certificate ${label} from safkeyring:////${KEYRING_OWNER}/${KEYRING_NAME} to ${target}"
  fi
  _cmd node "${zct}" keyring export "${KEYRING_OWNER}" "${KEYRING_NAME}" "${label}" -f "${target}"
  if [ -n "${VERBOSE_MODE}" ]; then
    echo
  fi
}
export_private_key_from_keyring_to_pem() {
  label=$1
  target=$2

  utils_dir="${ROOT_DIR}/bin/utils"
  zct="${utils_dir}/ncert/src/cli.js"

  if [ -n "${VERBOSE_MODE}" ]; then
    echo "> export private key ${label} from safkeyring:////${KEYRING_OWNER}/${KEYRING_NAME} to ${target}"
  fi
  _cmd node "${zct}" keyring export "${KEYRING_OWNER}" "${KEYRING_NAME}" "${label}" -k -f "${target}"
  if [ -n "${VERBOSE_MODE}" ]; then
    echo
  fi
}
export_certificates_from_keyring() {
  temp_hlq=$1
  temp_dir=$2

  utils_dir="${ROOT_DIR}/bin/utils"
  zct="${utils_dir}/ncert/src/cli.js"
  dummy_cert=convert-for-k8s-dummy

  certs=$(node "${zct}" keyring info "${KEYRING_OWNER}" "${KEYRING_NAME}" -u PERSONAL --label-only)
  keystore=${temp_dir}/keystore.p12
  rm -f "${keystore}"
  rm -f "${keystore}-cert"
  rm -f "${keystore}-key"
  # create keystore by generating a dummy key
   keytool -genkeypair \
    -alias "${dummy_cert}" \
    -dname "CN=Zowe Dummy Cert, OU=ZWELS, O=Zowe, C=US" \
    -keystore "${keystore}" \
    -storetype PKCS12 \
    -storepass "${KEYSTORE_PASSWORD}" \
    -validity 90 \
    -keyalg RSA -keysize 2048
  chtag -b "${keystore}"
  # import all certificates
  while read -r cert; do
    if [ -n "${cert}" ]; then
      owner=$(node "${zct}" keyring info "${KEYRING_OWNER}" "${KEYRING_NAME}" -l "${cert}" --owner-only)
      export_certificate_from_keyring_to_pkcs12 "${owner}" "${cert}" "${temp_hlq}" "${keystore}" "${KEYSTORE_PASSWORD}"

      if [ "${cert}" = "${KEY_ALIAS}" ]; then
        export_certificate_from_keyring_to_pem "${cert}" "${keystore}-cert"
        export_private_key_from_keyring_to_pem "${cert}" "${keystore}-key"
      fi
    fi
  done <<EOF
$(echo "${certs}")
EOF
  # delete dummy cert
   keytool -delete \
    -alias "${dummy_cert}" \
    -keystore "${keystore}" \
    -storetype PKCS12 \
    -storepass "${KEYSTORE_PASSWORD}"

  if [ -n "${VERBOSE_MODE}" ]; then
    # show content of the keystore
    echo "> Exported keystore information"
    chtag -b "${keystore}"
    _cmd node "${zct}" pkcs12 info "${keystore}" -p "${KEYSTORE_PASSWORD}" ${VERBOSE_MODE}
  fi

  cas=$(node "${zct}" keyring info "${KEYRING_OWNER}" "${KEYRING_NAME}" -u CERTAUTH --label-only)
  truststore=${temp_dir}/truststore.p12
  rm -f "${truststore}"
  rm -f "${truststore}-cert"
  rm -f "${truststore}-cert-tmp"
  # create truststore by generating a dummy key
   keytool -genkeypair \
    -alias "${dummy_cert}" \
    -dname "CN=Zowe Dummy Cert, OU=ZWELS, O=Zowe, C=US" \
    -keystore "${truststore}" \
    -storetype PKCS12 \
    -storepass "${KEYSTORE_PASSWORD}" \
    -validity 90 \
    -keyalg RSA -keysize 2048
  chtag -b "${truststore}"
  # import all CAs
  while read -r ca; do
    if [ -n "${ca}" ]; then
      owner=$(node "${zct}" keyring info "${KEYRING_OWNER}" "${KEYRING_NAME}" -l "${ca}" --owner-only)
      # always put it into keystore
      export_certificate_from_keyring_to_pkcs12 "${owner}" "${ca}" "${temp_hlq}" "${keystore}" "${KEYSTORE_PASSWORD}" "true"

      found=$(item_in_list "${EXTERNAL_CERTIFICATE_AUTHORITIES}" "${ca}")
      if [ "${found}" = "true" ]; then
        # this is Zowe CA, will try to export both cert and private key
        export_certificate_from_keyring_to_pkcs12 "${owner}" "${ca}" "${temp_hlq}" "${truststore}" "${KEYSTORE_PASSWORD}"

        export_certificate_from_keyring_to_pem "${ca}" "${truststore}-cert-tmp"
        cat "${truststore}-cert-tmp" >> "${truststore}-cert"
        echo >> "${truststore}-cert"
      else
        # Not Zowe CA, we only export cert without private key
        export_certificate_from_keyring_to_pkcs12 "${owner}" "${ca}" "${temp_hlq}" "${truststore}" "${KEYSTORE_PASSWORD}" "true"
      fi
    fi
  done <<EOF
$(echo "${cas}")
EOF
  # delete dummy cert
   keytool -delete \
    -alias "${dummy_cert}" \
    -keystore "${truststore}" \
    -storetype PKCS12 \
    -storepass "${KEYSTORE_PASSWORD}"

  if [ -n "${VERBOSE_MODE}" ]; then
    # show content of the keystore
    echo "> Exported truststore information"
    chtag -b "${truststore}"
    _cmd node "${zct}" pkcs12 info "${truststore}" -p "${KEYSTORE_PASSWORD}" ${VERBOSE_MODE}
  fi

  # convert variables
  # >>>>>> FROM
  # KEY_ALIAS="ZoweCert"
  # KEYSTORE_PASSWORD="password"
  # KEYRING_OWNER="ZWESVUSR"
  # KEYRING_NAME="ZoweKeyring"
  # KEYSTORE="safkeyring:////${KEYRING_OWNER}/${KEYRING_NAME}"
  # KEYSTORE_TYPE="JCERACFKS"
  # TRUSTSTORE="safkeyring:////${KEYRING_OWNER}/${KEYRING_NAME}"
  # EXTERNAL_ROOT_CA="localca"
  # EXTERNAL_CERTIFICATE_AUTHORITIES="localca,"
  # >>>>>> TO
  # KEY_ALIAS="localhost"
  # KEYSTORE_PASSWORD=password
  # KEYSTORE="/var/zowe/keystore/localhost/localhost.keystore.p12"
  # KEYSTORE_TYPE="PKCS12"
  # TRUSTSTORE="/var/zowe/keystore/localhost/localhost.truststore.p12"
  # KEYSTORE_KEY="/var/zowe/keystore/localhost/localhost.keystore.key"
  # KEYSTORE_CERTIFICATE="/var/zowe/keystore/localhost/localhost.keystore.cer-ebcdic"
  # KEYSTORE_CERTIFICATE_AUTHORITY="/var/zowe/keystore/local_ca/localca.cer-ebcdic"
  # EXTERNAL_ROOT_CA=""
  # EXTERNAL_CERTIFICATE_AUTHORITIES=""

  # CA is stored in truststore
  LOCAL_CA_KEYSTORE="${truststore}"
  LOCAL_CA_PASSWORD="${KEYSTORE_PASSWORD}"
  LOCAL_CA_ALIAS="${EXTERNAL_ROOT_CA}"
  # after exported, RACDCERT converts label to lowe case
  KEY_ALIAS=$(echo "${KEY_ALIAS}" | tr [A-Z] [a-z])
  KEYSTORE="${keystore}"
  KEYSTORE_TYPE="PKCS12"
  TRUSTSTORE="${truststore}"
  KEYSTORE_KEY="${keystore}-key"
  KEYSTORE_CERTIFICATE="${keystore}-cert"
  KEYSTORE_CERTIFICATE_AUTHORITY="${truststore}-cert"
  EXTERNAL_ROOT_CA=""
  EXTERNAL_CERTIFICATE_AUTHORITIES=""
  KEYRING_OWNER=
  KEYRING_NAME=
}
generate_k8s_certificate() {
  k8s_temp_keystore=$1

  utils_dir="${ROOT_DIR}/bin/utils"
  zct="${utils_dir}/ncert/src/cli.js"

  alt_names=
  for host in $(echo "${NEW_ZWE_EXTERNAL_HOSTS}" | sed 's#[,]# #g'); do
    alt_names="${alt_names} --alt ${host}"
  done
  alt_names="${alt_names} --alt localhost.localdomain"
  alt_names="${alt_names} --alt localhost"
  alt_names="${alt_names} --alt 127.0.0.1"
  alt_names="${alt_names} --alt '*.${ZWE_POD_NAMESPACE}.svc.${ZWE_POD_CLUSTERNAME}'"
  alt_names="${alt_names} --alt '*.${ZWE_POD_NAMESPACE}.pod.${ZWE_POD_CLUSTERNAME}'"
  alt_names="${alt_names} --alt '*.discovery-service.${ZWE_POD_NAMESPACE}.svc.${ZWE_POD_CLUSTERNAME}'"
  alt_names="${alt_names} --alt '*.gateway-service.${ZWE_POD_NAMESPACE}.svc.${ZWE_POD_CLUSTERNAME}'"

  new_k8s_keystore="${k8s_temp_keystore}-k8s"

  echo "> Generate new keystore suitable for Kubernetes - ${new_k8s_keystore}"
  _cmd node "${zct}" pkcs12 generate "${KEY_ALIAS}" \
    ${VERBOSE_MODE} \
    --ca "${LOCAL_CA_KEYSTORE}" \
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
ZWE_POD_NAMESPACE=zowe
ZWE_POD_CLUSTERNAME=cluster.local
LOCAL_CA_PASSWORD=local_ca_password
LOCAL_CA_ALIAS=localca
LOCAL_CA_FILENAME="local_ca/localca"
NEW_ZWE_EXTERNAL_HOSTS=localhost
NEW_ZWE_EXTERNAL_PORT=7554
VERBOSE_MODE=
SILENT_MODE=
# will be defined later
LOCAL_CA_KEYSTORE=
ZWELS_CONFIG_LOAD_METHOD=
# variables
rnd=$(echo $RANDOM)
userid=$(echo "${USER:-${USERNAME:-${LOGNAME}}}" | tr [a-z] [A-Z])

# command line parameters
OPTIND=1
while getopts "c:x:n:u:p:a:e:v:q" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    x) NEW_ZWE_EXTERNAL_HOSTS=${OPTARG};;
    n) ZWE_POD_NAMESPACE=${OPTARG};;
    u) ZWE_POD_CLUSTERNAME=${OPTARG};;
    p) LOCAL_CA_PASSWORD=${OPTARG};;
    a) LOCAL_CA_ALIAS=${OPTARG};;
    e) NEW_ZWE_EXTERNAL_PORT=${OPTARG};;
    v) VERBOSE_MODE="-v";;
    q) SILENT_MODE=true;;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

# validate INSTANCE_DIR
if [ -f "${INSTANCE_DIR}/instance.env" ]; then
  ZWELS_CONFIG_LOAD_METHOD="instance.env"
elif [ -f "${INSTANCE_DIR}/zowe.yaml" ]; then
  ZWELS_CONFIG_LOAD_METHOD="zowe.yaml"
else
  >&2 echo "Error: instance directory doesn't have instance.env or zowe.yaml."
  exit 1
fi

# source utility scripts
. ${INSTANCE_DIR}/bin/internal/utils.sh
read_essential_vars
# validate ROOT_DIR
if [ -z "${ROOT_DIR}" ]; then
  >&2 echo "Error: cannot determine runtime root directory."
  exit 1
fi
. ${ROOT_DIR}/bin/utils/utils.sh

# temp data sets and files
temp_dir="$(get_tmp_dir)/zowe-convert-for-k8s-$(echo ${rnd})"
rm -fr "${temp_dir}"
mkdir -p "${temp_dir}"
k8s_temp_keystore="${temp_dir}/${KEY_ALIAS}.keystore.p12"
temp_hlq=${userid}.K8S${rnd}

if [ "${SILENT_MODE}" != "true" ]; then
  echo "SECURITY WARNING: This script may generate information including sensitive private"
  echo "                  keys. Please make sure the content will not be left on any devices"
  echo "                  after the process is done."
  echo "                  During the process, this utility script may generate temporary"
  echo "                  files under ${temp_dir}/."
  echo "                  Normally those files will be automatically deleted after the script"
  echo "                  exits. If the scipt exits with error, please double check if any of"
  echo "                  those files are left on the system and they MUST be manually"
  echo "                  deleted for security reason."
  echo
fi

# we need node and keytool for following commands
ensure_node_is_on_path 1>/dev/null 2>&1
ensure_java_is_on_path 1>/dev/null 2>&1

# import common environment variables to make sure node runs properly
. "${ROOT_DIR}/bin/internal/zowe-set-env.sh"

if [ "${ZWELS_CONFIG_LOAD_METHOD}" = "zowe.yaml" ]; then
  ZWELS_INSTANCE_ENV_DIR="${temp_dir}/.env"
  mkdir -p "${ZWELS_INSTANCE_ENV_DIR}"
  cp "${INSTANCE_DIR}/zowe.yaml" "${temp_dir}/zowe.yaml"
  # convert to instance.env
  generate_instance_env_from_yaml_config convert-for-k8s
  . "${ZWELS_INSTANCE_ENV_DIR}/.instance-convert-for-k8s.env"
  LOCAL_CA_KEYSTORE="${KEYSTORE_DIRECTORY}/${LOCAL_CA_FILENAME}.keystore.p12"
else
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
  LOCAL_CA_KEYSTORE="${KEYSTORE_DIRECTORY}/${LOCAL_CA_FILENAME}.keystore.p12"
fi

# make sure p12 file are tagged as binary to avoid node.js tries to convert encoding
if [ -n "${KEYSTORE_DIRECTORY}" -a -d "${KEYSTORE_DIRECTORY}" ]; then
  find "${KEYSTORE_DIRECTORY}" -name '*.p12' 2>/dev/null | xargs chtag -b
fi
if [ -f "${KEYSTORE}" ]; then
  chtag -b "${KEYSTORE}"
fi
if [ -f "${TRUSTSTORE}" ]; then
  chtag -b "${TRUSTSTORE}"
fi

# ZOWE_APIM_VERIFY_CERTIFICATES=true

if [ "${ZOWE_APIM_VERIFY_CERTIFICATES}" != "true" -a "${ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES}" != "true" ]; then
  >&2 echo "SECURITY WARNING: It's not recommended to turn both VERIFY_CERTIFICATES and "
  >&2 echo "                  NONSTRICT_VERIFY_CERTIFICATES off for security reasons."
  >&2 echo
fi

if [ "${KEYSTORE_TYPE}" = "JCERACFKS" ]; then
  # export keyring to PKCS#12 format
  echo "You are using z/OS Keyring. All certificates used by Zowe will be exported."
  export_certificates_from_keyring "${temp_hlq}" "${temp_dir}"
  echo
fi

if [ "$(is_certificate_generated_by_zowe)" != "true" ]; then
  echo "It seems you are using certificates NOT generated by Zowe."
  echo

  if [ "${ZOWE_APIM_VERIFY_CERTIFICATES}" = "true" ]; then
    echo "To make certificates working in Kubernetes, the certificate you are using should have"
    echo "these domains defined in Subject Alt Name (SAN):"
    echo
    for host in $(echo "${NEW_ZWE_EXTERNAL_HOSTS}" | sed 's#[,]# #g'); do
      echo "- ${host}"
    done
    echo "- *.${ZWE_POD_NAMESPACE}.svc.${ZWE_POD_CLUSTERNAME}"
    echo "- *.discovery-service.${ZWE_POD_NAMESPACE}.svc.${ZWE_POD_CLUSTERNAME}"
    echo "- *.gateway-service.${ZWE_POD_NAMESPACE}.svc.${ZWE_POD_CLUSTERNAME}"
    echo "- *.${ZWE_POD_NAMESPACE}.pod.${ZWE_POD_CLUSTERNAME}"
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
  if [ "${SILENT_MODE}" != "true" ]; then
    echo "It seems you are using Zowe generated certificates."
    echo
  fi

  if [ "${ZOWE_APIM_VERIFY_CERTIFICATES}" = "true" ]; then
    echo "To make the certificates working properly in Kubernetes, we need to generate"
    echo "a new certificate with proper domains."
    echo "You can customize domains by passing -x option to this utility script."
    echo

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
  elif [ "${ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES}" = "true" -a "${SILENT_MODE}" != "true" ]; then
    echo "You are using Non-Strict verify certificate mode. You existing certificates"
    echo "should work in Kubernetes without change."
    echo
  fi
fi

ORIGINAL_ZOWE_EXPLORER_HOST=$ZOWE_EXPLORER_HOST
if [ "${ZWELS_CONFIG_LOAD_METHOD}" = "zowe.yaml" ]; then
  delete_yaml_variable "${temp_dir}/zowe.yaml" "java.home"
  delete_yaml_variable "${temp_dir}/zowe.yaml" "node.home"
  delete_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.SKIP_NODE"
  delete_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.ZOWE_ZOS_HOST"
  delete_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.ZOWE_EXTERNAL_HOST"
  delete_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.ZWE_EXTERNAL_HOSTS"

  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.runtimeDirectory" "/home/zowe/runtime"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.KEYSTORE_DIRECTORY" "/home/zowe/keystore"

  iterator_index=0
  frame_ancestors=
  for host in $(echo "${NEW_ZWE_EXTERNAL_HOSTS}" | sed 's#[,]# #g'); do
    update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.externalDomains[${iterator_index}]" "${host}"
    if [ -n "${frame_ancestors}" ]; then
      frame_ancestors=${frame_ancestors},
    fi
    frame_ancestors="${frame_ancestors}${host}:*"
    if [ "${iterator_index}" = "0" ]; then
      ZOWE_EXTERNAL_HOST="${host}"
      update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.ZOWE_EXTERNAL_HOST" "${ZOWE_EXTERNAL_HOST}"
    fi
    iterator_index=`expr $iterator_index + 1`
  done

  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.externalPort" "7554"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.gateway.port" "7554"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.discovery.port" "7553"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.api-catalog.port" "7552"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.caching-service.port" "7555"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.app-server.port" "8544"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.jobs-api.port" "8545"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.files-api.port" "8547"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.explorer-jes.port" "8546"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.explorer-mvs.port" "8548"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.explorer-uss.port" "8550"

  update_yaml_variable "${temp_dir}/zowe.yaml" "components.gateway.enabled" "true"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.discovery.enabled" "true"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.api-catalog.enabled" "true"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.caching-service.enabled" "true"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.app-server.enabled" "true"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.jobs-api.enabled" "true"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.files-api.enabled" "true"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.explorer-jes.enabled" "true"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.explorer-mvs.enabled" "true"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.explorer-uss.enabled" "true"

  update_yaml_variable "${temp_dir}/zowe.yaml" "components.gateway.apiml.security.x509.externalMapperUrl" "https://\${GATEWAY_HOST}:\${GATEWAY_PORT}/zss/api/v1/certificate/x509/map"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.gateway.apiml.security.authorization.endpoint.url" "https://\${GATEWAY_HOST}:\${GATEWAY_PORT}/zss/api/v1/saf-auth"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.discovery.replicas" "1"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.caching-service.storage.mode" ""
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.explorer-jes.frameAncestors" "${frame_ancestors}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.explorer-mvs.frameAncestors" "${frame_ancestors}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.explorer-uss.frameAncestors" "${frame_ancestors}"

  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.ZOWE_ZOS_HOST" "${ORIGINAL_ZOWE_EXPLORER_HOST}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.ZWED_agent_host" "${ORIGINAL_ZOWE_EXPLORER_HOST}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.ZWED_agent_https_port" "${ZOWE_ZSS_SERVER_PORT}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.ZOWE_ZLUX_TELNET_HOST" "${ORIGINAL_ZOWE_EXPLORER_HOST}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.ZOWE_ZLUX_SSH_HOST" "${ORIGINAL_ZOWE_EXPLORER_HOST}"

  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.externalCertificate.keystore.alias" "${KEY_ALIAS}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.externalCertificate.keystore.password" "${KEYSTORE_PASSWORD}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.externalCertificate.keystore.file" "/home/zowe/keystore/keystore.p12"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.externalCertificate.keystore.type" "${KEYSTORE_TYPE}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.externalCertificate.trustStore.file" "/home/zowe/keystore/truststore.p1"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.externalCertificate.trustStore.certificateAuthorities" ""
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.externalCertificate.pem.key" "/home/zowe/keystore/keystore.key"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.externalCertificate.pem.certificate" "/home/zowe/keystore/keystore.cert"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.externalCertificate.pem.certificateAuthority" "/home/zowe/keystore/localca.cert"

  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.internalCertificate.keystore.alias" "${KEY_ALIAS}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.internalCertificate.keystore.password" "${KEYSTORE_PASSWORD}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.internalCertificate.keystore.file" "/home/zowe/keystore/keystore.p12"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.internalCertificate.keystore.type" "${KEYSTORE_TYPE}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.internalCertificate.trustStore.file" "/home/zowe/keystore/truststore.p12"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.internalCertificate.trustStore.certificateAuthorities" ""
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.internalCertificate.pem.key" "/home/zowe/keystore/keystore.key"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.internalCertificate.pem.certificate" "/home/zowe/keystore/keystore.cert"
  update_yaml_variable "${temp_dir}/zowe.yaml" "zowe.internalCertificate.pem.certificateAuthority" "/home/zowe/keystore/localca.cert"

  update_yaml_variable "${temp_dir}/zowe.yaml" "components.gateway.apiml.security.ssl.verifySslCertificatesOfServices" "${ZOWE_APIM_VERIFY_CERTIFICATES}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.gateway.apiml.security.ssl.nonStrictVerifySslCertificatesOfServices" "${ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.discovery.apiml.security.ssl.verifySslCertificatesOfServices" "${ZOWE_APIM_VERIFY_CERTIFICATES}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.discovery.apiml.security.ssl.nonStrictVerifySslCertificatesOfServices" "${ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.api-catalog.apiml.security.ssl.verifySslCertificatesOfServices" "${ZOWE_APIM_VERIFY_CERTIFICATES}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.api-catalog.apiml.security.ssl.nonStrictVerifySslCertificatesOfServices" "${ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.caching-service.apiml.security.ssl.verifySslCertificatesOfServices" "${ZOWE_APIM_VERIFY_CERTIFICATES}"
  update_yaml_variable "${temp_dir}/zowe.yaml" "components.caching-service.apiml.security.ssl.nonStrictVerifySslCertificatesOfServices" "${ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES}"

  delete_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.KEYRING_OWNER"
  delete_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.KEYRING_NAME"
  delete_yaml_variable "${temp_dir}/zowe.yaml" "zowe.environments.LOCAL_CA"

  if [ "${SILENT_MODE}" != "true" ]; then
    echo "Please note that depending on how you choose to Zowe Kubernetes gateway service,"
    echo "you need to match \"zowe.externalPort\" to be the port you are using. For example:"
    echo
    echo "zowe:"
    echo "  externalPort: \"32554\""
    echo
  fi
else
  NEW_INSATNCE_ENV_CONTENT=$(cat "${INSTANCE_DIR}"/instance.env | \
    grep -v -E "(ZWE_EXTERNAL_HOSTS=|ZOWE_EXTERNAL_HOST=|ZOWE_ZOS_HOST=|ZOWE_IP_ADDRESS=|ZWE_LAUNCH_COMPONENTS=|JAVA_HOME=|NODE_HOME=|SKIP_NODE=|skip using nodejs)" | \
    sed -e "/ZOWE_EXPLORER_HOST=.*/a\\
    ZWE_EXTERNAL_HOSTS=${NEW_ZWE_EXTERNAL_HOSTS}" | \
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
    sed -e "s#JOBS_API_PORT=.\+\$#JOBS_API_PORT=8545#" | \
    sed -e "s#FILES_API_PORT=.\+\$#FILES_API_PORT=8547#" | \
    sed -e "s#JES_EXPLORER_UI_PORT=.\+\$#JES_EXPLORER_UI_PORT=8546#" | \
    sed -e "s#MVS_EXPLORER_UI_PORT=.\+\$#MVS_EXPLORER_UI_PORT=8548#" | \
    sed -e "s#USS_EXPLORER_UI_PORT=.\+\$#USS_EXPLORER_UI_PORT=8550#" | \
    sed -e "s#ZOWE_ZLUX_SERVER_HTTPS_PORT=.\+\$#ZOWE_ZLUX_SERVER_HTTPS_PORT=8544#" | \
    sed -e "s#ZWE_DISCOVERY_SERVICES_LIST=.\+\$#ZWE_DISCOVERY_SERVICES_REPLICAS=1#" | \
    sed -e "s#APIML_GATEWAY_EXTERNAL_MAPPER=.\+\$#APIML_GATEWAY_EXTERNAL_MAPPER=https://\${GATEWAY_HOST}:\${GATEWAY_PORT}/zss/api/v1/certificate/x509/map#" | \
    sed -e "s#APIML_SECURITY_AUTHORIZATION_ENDPOINT_URL=.\+\$#APIML_SECURITY_AUTHORIZATION_ENDPOINT_URL=https://\${GATEWAY_HOST}:\${GATEWAY_PORT}/zss/api/v1/saf-auth#" | \
    sed -e "s#ZOWE_EXPLORER_FRAME_ANCESTORS=.\+\$#ZOWE_EXPLORER_FRAME_ANCESTORS=\${ZOWE_EXTERNAL_HOST}:*,\${ZOWE_EXPLORER_HOST}:*,\${ZOWE_IP_ADDRESS}:*#" | \
    sed -e "s#ZWE_CACHING_SERVICE_PERSISTENT=.\+\$#ZWE_CACHING_SERVICE_PERSISTENT=#" | \
    sed -e "\$a\\
    \\
    ZWE_EXTERNAL_PORT=${NEW_ZWE_EXTERNAL_PORT}\\
    ZWED_agent_host=\${ZOWE_ZOS_HOST}\\
    ZWED_agent_https_port=\${ZOWE_ZSS_SERVER_PORT}\\
    ZOWE_ZLUX_TELNET_HOST=\${ZWED_agent_host}\\
    ZOWE_ZLUX_SSH_HOST=\${ZWED_agent_host}")

  if [ "${SILENT_MODE}" != "true" ]; then
    echo "Please note that depending on how you choose to Zowe Kubernetes gateway service,"
    echo "you need to match \"ZWE_EXTERNAL_PORT\" to be the port you are using. For example:"
    echo
    echo "ZWE_EXTERNAL_PORT=32554"
    echo
  fi
fi

################################################################################
# start official output
if [ "${SILENT_MODE}" != "true" ]; then
  echo "Please copy all output below, save them as a YAML file on your local computer,"
  echo "then apply it to your Kubernetes cluster. After apply, you MUST delete and"
  echo "destroy the temporary file from your local computer."
  echo
  echo "  Example: kubectl apply -f /path/to/my/local-saved.yaml"
  echo
fi

################################################################################
# Prepare configs
if [ "${ZWELS_CONFIG_LOAD_METHOD}" = "zowe.yaml" ]; then
  cat << EOF
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: zowe-config
  namespace: ${ZWE_POD_NAMESPACE}
  labels:
    app.kubernetes.io/name: zowe
    app.kubernetes.io/instance: zowe
    app.kubernetes.io/managed-by: manual
data:
  zowe.yaml: |
$(cat "${temp_dir}/zowe.yaml" | indent - "    ")
EOF
else
  cat << EOF
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: zowe-config
  namespace: ${ZWE_POD_NAMESPACE}
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
  namespace: ${ZWE_POD_NAMESPACE}
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
fi

cat << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: zowe-certificates-secret
  namespace: ${ZWE_POD_NAMESPACE}
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

# remove temporary directory
rm -fr "${temp_dir}"
