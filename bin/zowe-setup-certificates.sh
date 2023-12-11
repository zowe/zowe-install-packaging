#!/bin/sh

#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

# Variables to be supplied:
# - HOSTNAME - The hostname of the system running API Mediation
# - IPADDRESS - The IP Address of the system running API Mediation
# - VERIFY_CERTIFICATES - true/false - Should APIML verify certificates of services in strict mode (defaults to true)
# - NONSTRICT_VERIFY_CERTIFICATES - true/false - Should APIML verify certificates of services in non-strict mode (defaults to true)
# - EXTERNAL_CERTIFICATE - optional - Path to a PKCS12 keystore with a server certificate for APIML
# - EXTERNAL_CERTIFICATE_ALIAS - optional - Alias of the certificate in the keystore
# - EXTERNAL_CERTIFICATE_AUTHORITIES - optional - Public certificates of trusted CAs
# - ZOSMF_CERTIFICATE - Public certificates of z/OSMF - multiple certificates delimited with space has to be enclosed with quotes ("path/cer1 path/cer2")

# - KEYSTORE_DIRECTORY - Location for generated certificates (defaults to /global/zowe/keystore)
# - ZOWE_LOCALCA_LABEL - This variable has to be set to the LOCALCA variable's value specified in the ZWEKRING JCL.
# - KEYSTORE_PASSWORD - a password that is used to secure EXTERNAL_CERTIFICATE keystore and
#                       that will be also used to secure newly generated keystores for API Mediation.
# - ZOWE_USER_ID - zowe user id to set up ownership of the generated certificates
# - ZOWE_KEYRING - specify zowe keyring that keeps zowe certificates, if not specified USS keystore
#                  files will be created.
# - GENERATE_CERTS_FOR_KEYRING - If you used ZWEKRING jcl to configure certificates and the keyring
#                                then set this variable to false (defaults to false)
# - COMPONENT_LEVEL_CERTIFICATES - optional - if you want to generate dedicated certificates for certain components.
# - EXTERNAL_COMPONENT_CERTIFICATES - optional - external certificates for each of components listed in COMPONENT_LEVEL_CERTIFICATES
# - EXTERNAL_COMPONENT_CERTIFICATE_ALIASES - optional - external certificate aliases for each of components listed in COMPONENT_LEVEL_CERTIFICATES
function detectExternalCAs {
  echo "Detecting external CAs ... STARTED"
  EXTERNAL_ROOT_CA=
  if [[ -z "${ZOWE_KEYRING}" ]]; then
    for file in "${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}"/extca.*.cer-ebcdic; do
      if [[ ! -f ${file} ]]; then
        break;
      fi
      CERTIFICATE_OWNER=`keytool -printcert -file $file | grep -e Owner: | cut -d ":" -f 2-`
      CERTIFICATE_ISSUER=`keytool -printcert -file $file | grep -e Issuer: | cut -d ":" -f 2-`
      if [[ "${CERTIFICATE_OWNER}" == "${CERTIFICATE_ISSUER}" ]]; then
        EXTERNAL_ROOT_CA=$file;
        break;
      fi
    done
  else
    # Assumption: External certificate contains its chain of trust. The root certificate is the last one in the list
    #             that we get using the commands just below:
    var_key_chain=$(keytool -list -storetype JCERACFKS -keystore "safkeyring://${ZOWE_USER_ID}/${ZOWE_KEYRING}" -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider -alias "${KEYSTORE_ALIAS}" -v)
    var_CA_chain_length=$(echo "${var_key_chain}" | grep -c -e Owner:)
    if [[ $var_CA_chain_length -lt 2 ]]; then
      echo "The ${KEYSTORE_ALIAS} certificate is self-signed or does not contain its CA chain or the detection algorithm failed for other reason. If the certificate is externally signed \
and its root CA is connected to the same keyring then you can manually set the EXTERNAL_ROOT_CA env variable with the \
root CA label in the ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME} file."
    else
      EXTERNAL_CERTIFICATE_AUTHORITIES=
      var_all_cas=$(echo "${var_key_chain}" | grep -e Issuer: | uniq | cut -d ":" -f 2- | sed 's/^[ \t]*//')
      var_full_key_list=$(keytool -list -storetype JCERACFKS -keystore "safkeyring://${ZOWE_USER_ID}/${ZOWE_KEYRING}" -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider -v)
      while read -r one_ca; do
        var_ca_alias=$(echo "${var_full_key_list}" | grep -e "Owner: ${one_ca}" -P 5 | grep -e "Alias name:" | cut -d ":" -f 2- | sed 's/^[ \t]*//')
        if [ -n "${var_ca_alias}" ]; then
          EXTERNAL_CERTIFICATE_AUTHORITIES="${EXTERNAL_CERTIFICATE_AUTHORITIES}${var_ca_alias},"
          EXTERNAL_ROOT_CA="${var_ca_alias}"
        fi
      done <<EOF
$(echo "${var_all_cas}")
EOF
      if [ "${EXTERNAL_CERTIFICATE_AUTHORITIES}" = "," ]; then
        EXTERNAL_CERTIFICATE_AUTHORITIES=
      fi
      echo "Label of the external root CA in the keyring: ${EXTERNAL_ROOT_CA}"
      echo "Label(s) of all external CA(s) in the keyring: ${EXTERNAL_CERTIFICATE_AUTHORITIES}"
    fi
  fi
  echo "Detecting external CAs... DONE"
}

# process input parameters.
while getopts "l:p:" opt; do
  case $opt in
    l) LOG_DIRECTORY=$OPTARG;;
    p) CERTIFICATES_CONFIG_FILE=$OPTARG;;
    \?)
      echo "Invalid option: -$opt" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

umask 0027

if [[ -z ${ZOWE_ROOT_DIR} ]]
then
  export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../;pwd)
fi

. "${ZOWE_ROOT_DIR}/bin/utils/setup-log-dir.sh"
set_install_log_directory "${LOG_DIRECTORY}"
validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
set_install_log_file "zowe-setup-certificates"

echo "<zowe-setup-certificates.sh>" >> "${LOG_FILE}"


# Load default values
DEFAULT_CERTIFICATES_CONFIG_FILE="${ZOWE_ROOT_DIR}/bin/zowe-setup-certificates.env"
echo "Loading default variables from ${DEFAULT_CERTIFICATES_CONFIG_FILE} file."
. "${DEFAULT_CERTIFICATES_CONFIG_FILE}"

if [[ -z "${CERTIFICATES_CONFIG_FILE}" ]]
then
  echo "-p parameter not set. Using default ${DEFAULT_CERTIFICATES_CONFIG_FILE} file instead."
else
  if [[ -f "${CERTIFICATES_CONFIG_FILE}" ]]
  then
    echo "Loading ${CERTIFICATES_CONFIG_FILE} file and overriding default variables."
    # Load custom values
    . "${CERTIFICATES_CONFIG_FILE}"
  else
    echo "${CERTIFICATES_CONFIG_FILE} file does not exist."
    exit 1
  fi
fi

# Set a default value if the variable is not defined
if [[ -z "${ZOWE_LOCALCA_LABEL}" ]];
then
  ZOWE_LOCALCA_LABEL=localca
fi

# Backwards compatible overloading of KEYSTORE_ALIAS to be ZOWE_CERTIFICATE_LABEL
if [[ -n "${ZOWE_CERTIFICATE_LABEL}" ]];
then
  KEYSTORE_ALIAS="${ZOWE_CERTIFICATE_LABEL}"
fi

# tolerate HOSTNAME, IPADDRESS to have multiple values
HOSTNAME_FIRST=$(echo ${HOSTNAME}  | tr "," "\n" | sed '/^[[:space:]]*$/d' | head -1)
IPADDRESS_FIRST=$(echo ${IPADDRESS}  | tr "," "\n" | sed '/^[[:space:]]*$/d' | head -1)
# ZOWE_EXPLORER_HOST only accept one domain name
ZOWE_EXPLORER_HOST=${HOSTNAME_FIRST}
ZOWE_IP_ADDRESS=${IPADDRESS_FIRST}
. "${ZOWE_ROOT_DIR}/bin/zowe-init.sh" -s
. "${ZOWE_ROOT_DIR}/scripts/utils/configure-java.sh"

ZOWE_CERT_ENV_NAME=zowe-certificates.env
LOCAL_KEYSTORE_SUBDIR=local_ca

# create keystore directories
if [ ! -d "${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}" ]; then
  if ! mkdir -p "${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}"; then
    echo "Unable to create ${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR} directory."
    exit 1;
  fi
fi

if [ ! -d "${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}" ]; then
  if ! mkdir -p "${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}"; then
    echo "Unable to create ${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS} directory."
    exit 1;
  fi
fi

echo "Creating certificates and keystores... STARTED"
# set up parameters for apiml_cm.sh script
KEYSTORE_PREFIX="${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}/${KEYSTORE_ALIAS}.keystore"
TRUSTSTORE_PREFIX="${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}/${KEYSTORE_ALIAS}.truststore"
EXTERNAL_CA_PREFIX="${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}/extca"
LOCAL_CA_PREFIX="${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}/localca"
# we may get domain name from ZOWE_EXPLORER_HOST if HOSTNAME is not defined
# compare and copy it back to HOSTNAME if needed
HOSTNAME_LC=$(echo ${HOSTNAME} | tr '[:upper:]' '[:lower:]')
ZOWE_EXPLORER_HOST_LC=$(echo ${ZOWE_EXPLORER_HOST} | tr '[:upper:]' '[:lower:]')
if [[ ",$HOSTNAME_LC," != *",${ZOWE_EXPLORER_HOST_LC},"* ]]; then
  HOSTNAME_LC="${HOSTNAME_LC},${ZOWE_EXPLORER_HOST_LC}"
fi
IPADDRESS_LC=$(echo ${IPADDRESS} | tr '[:upper:]' '[:lower:]')
ZOWE_IP_ADDRESS_LC=$(echo ${ZOWE_IP_ADDRESS} | tr '[:upper:]' '[:lower:]')
if [[ ",$IPADDRESS_LC," != *",${ZOWE_IP_ADDRESS_LC},"* ]]; then
  IPADDRESS_LC="${IPADDRESS_LC},${ZOWE_IP_ADDRESS_LC}"
fi
# add all domains/ips to SAN
SAN="SAN="
HOSTNAME_ARRAY=$(echo ${HOSTNAME_LC}  | tr "," "\n" | sed '/^[[:space:]]*$/d')
for item in ${HOSTNAME_ARRAY}; do
  SAN="${SAN}dns:${item},"
done
IPADDRESS_ARRAY=$(echo ${IPADDRESS_LC}  | tr "," "\n" | sed '/^[[:space:]]*$/d')
for item in ${IPADDRESS_ARRAY}; do
  SAN="${SAN}ip:${item},"
done
SAN="${SAN}dns:localhost.localdomain,dns:localhost,ip:127.0.0.1"

# If any external certificate fields are zero [blank], do not use the external setup method.
# If all external certificate fields are zero [blank], create everything from scratch.
# If all external fields are not zero [valid string], use external setup method.

if [[ -z "${EXTERNAL_CERTIFICATE}" ]] || [[ -z "${EXTERNAL_CERTIFICATE_ALIAS}" ]] || [[ -z "${EXTERNAL_CERTIFICATE_AUTHORITIES}" ]]; then
  if [[ -z "${EXTERNAL_CERTIFICATE}" ]] && [[ -z "${EXTERNAL_CERTIFICATE_ALIAS}" ]] && [[ -z "${EXTERNAL_CERTIFICATE_AUTHORITIES}" ]]; then
    if [[ -z "${ZOWE_KEYRING}" ]]; then
      "${ZOWE_ROOT_DIR}/bin/apiml_cm.sh" --verbose --log "${LOG_FILE}" --action setup --service-ext "${SAN}" --service-password "${KEYSTORE_PASSWORD}" \
        --service-alias "${KEYSTORE_ALIAS}" --service-keystore "${KEYSTORE_PREFIX}" --service-truststore "${TRUSTSTORE_PREFIX}" --local-ca-filename "${LOCAL_CA_PREFIX}" \
        --component-level-certs "${COMPONENT_LEVEL_CERTIFICATES}"
      RC=$?
      echo "apiml_cm.sh --action setup returned: ${RC}" >> "${LOG_FILE}"
    elif [[ "${GENERATE_CERTS_FOR_KEYRING}" != "false" ]]; then
      "${ZOWE_ROOT_DIR}/bin/apiml_cm.sh" --verbose --log "${LOG_FILE}" --action setup --service-ext "${SAN}" --service-keystore "${KEYSTORE_PREFIX}" \
        --service-alias "${KEYSTORE_ALIAS}" --zowe-userid "${ZOWE_USER_ID}" --zowe-keyring "${ZOWE_KEYRING}" --service-storetype "JCERACFKS" --local-ca-filename "${LOCAL_CA_PREFIX}" \
        --component-level-certs "${COMPONENT_LEVEL_CERTIFICATES}"
      RC=$?
      echo "apiml_cm.sh --action setup returned: ${RC}" >> "${LOG_FILE}"
    else
      echo "Generating certificates for the keyring is skipped."
    fi
  else
    (>&2 echo "Zowe Install setup configuration is invalid; check your zowe-setup-certificates.env file.")
    (>&2 echo "Some external apiml certificate fields are supplied...Fields must be filled out in full or left completely blank.")
    (>&2 echo "See ${LOG_FILE} for more details.")
    echo "</zowe-setup-certificates.sh>" >> "${LOG_FILE}"
    rm "${KEYSTORE_PREFIX}"* "${TRUSTSTORE_PREFIX}"* "${EXTERNAL_CA_PREFIX}"* "${LOCAL_CA_PREFIX}"* 2> /dev/null
    exit 1
  fi
else
  EXT_CA_PARM=""
  for CA in ${EXTERNAL_CERTIFICATE_AUTHORITIES}; do
      EXT_CA_PARM="${EXT_CA_PARM} --external-ca ${CA} "
  done

  if [[ -z "${ZOWE_KEYRING}" ]]; then
    "${ZOWE_ROOT_DIR}/bin/apiml_cm.sh" --verbose --log "${LOG_FILE}" --action setup --service-ext "${SAN}" --service-password "${KEYSTORE_PASSWORD}" \
      --external-certificate "${EXTERNAL_CERTIFICATE}" --external-certificate-alias "${EXTERNAL_CERTIFICATE_ALIAS}" ${EXT_CA_PARM} \
      --service-alias "${KEYSTORE_ALIAS}" --service-keystore "${KEYSTORE_PREFIX}" --service-truststore "${TRUSTSTORE_PREFIX}" --local-ca-filename "${LOCAL_CA_PREFIX}" \
      --external-ca-filename ${EXTERNAL_CA_PREFIX} --component-level-certs "${COMPONENT_LEVEL_CERTIFICATES}" \
      --external-component-certificates "${EXTERNAL_COMPONENT_CERTIFICATES}" --external-component-certificate-aliases "${EXTERNAL_COMPONENT_CERTIFICATE_ALIASES}"
    RC=$?
    echo "apiml_cm.sh --action setup returned: $RC" >> $LOG_FILE
  elif [[ "${GENERATE_CERTS_FOR_KEYRING}" != "false" ]]; then
    "${ZOWE_ROOT_DIR}/bin/apiml_cm.sh" --verbose --log "${LOG_FILE}" --action setup --service-ext "${SAN}" --zowe-userid "${ZOWE_USER_ID}" --zowe-keyring ${ZOWE_KEYRING} \
      --service-storetype "JCERACFKS" --external-certificate "${EXTERNAL_CERTIFICATE}" --external-certificate-alias "${EXTERNAL_CERTIFICATE_ALIAS}" \
      --service-alias "${KEYSTORE_ALIAS}" --service-keystore "${KEYSTORE_PREFIX}" --local-ca-filename "${LOCAL_CA_PREFIX}" --component-level-certs "${COMPONENT_LEVEL_CERTIFICATES}" \
      --external-component-certificates "${EXTERNAL_COMPONENT_CERTIFICATES}" --external-component-certificate-aliases "${EXTERNAL_COMPONENT_CERTIFICATE_ALIASES}"
    RC=$?
    echo "apiml_cm.sh --action setup returned: $RC" >> "${LOG_FILE}"
  else
    echo "Generating certificates for the keyring is skipped."
  fi
fi

if [ "$RC" -ne "0" ]; then
    (>&2 echo "apiml_cm.sh --action setup has failed. See ${LOG_FILE} for more details")
    echo "</zowe-setup-certificates.sh>" >> "${LOG_FILE}"
    rm "${KEYSTORE_PREFIX}"* "${TRUSTSTORE_PREFIX}"* "${EXTERNAL_CA_PREFIX}"* "${LOCAL_CA_PREFIX}"* 2> /dev/null
    exit 1
fi

if [ -n "${ZOWE_ZOSMF_HOST}" -a -n "${ZOWE_ZOSMF_PORT}" ]; then
  if [ "${VERIFY_CERTIFICATES}" = "true" -o "${NONSTRICT_VERIFY_CERTIFICATES}" = "true" ]; then
    if [[ -z "${ZOWE_KEYRING}" ]]; then
      "${ZOWE_ROOT_DIR}/bin/apiml_cm.sh" --verbose --log "${LOG_FILE}" --action trust-zosmf \
        --service-password "${KEYSTORE_PASSWORD}" --service-truststore "${TRUSTSTORE_PREFIX}" --zosmf-certificate "${ZOSMF_CERTIFICATE}" \
        --service-keystore "${KEYSTORE_PREFIX}" --local-ca-filename "${LOCAL_CA_PREFIX}" \
        --verify-certificates "${VERIFY_CERTIFICATES}" --nonstrict-verify-certificates "${NONSTRICT_VERIFY_CERTIFICATES}"
    else
      export GENERATE_CERTS_FOR_KEYRING;
      "${ZOWE_ROOT_DIR}/bin/apiml_cm.sh" --verbose --log "${LOG_FILE}" --action trust-zosmf --zowe-userid "${ZOWE_USER_ID}" \
        --zowe-keyring "${ZOWE_KEYRING}" --service-storetype "JCERACFKS" --zosmf-certificate "${ZOSMF_CERTIFICATE}" \
        --service-keystore "${KEYSTORE_PREFIX}" --service-password "${KEYSTORE_PASSWORD}" \
        --service-truststore "${TRUSTSTORE_PREFIX}" --local-ca-filename "${LOCAL_CA_PREFIX}" \
        --verify-certificates "${VERIFY_CERTIFICATES}" --nonstrict-verify-certificates "${NONSTRICT_VERIFY_CERTIFICATES}"
    fi
    RC=$?

    echo "apiml_cm.sh --action trust-zosmf returned: $RC" >> "${LOG_FILE}"
    if [ "$RC" -ne "0" ]; then
        # import z/OSMF public key failed
        (>&2 echo "apiml_cm.sh --action trust-zosmf has failed. See ${LOG_FILE} for more details")
        (>&2 echo "ERROR: z/OSMF is not trusted by the API Mediation Layer. Make sure ZOWE_ZOSMF_HOST and ZOWE_ZOSMF_PORT variables define the desired z/OSMF instance.")
        (>&2 echo "ZOWE_ZOSMF_HOST=${ZOWE_ZOSMF_HOST}   ZOWE_ZOSMF_PORT=${ZOWE_ZOSMF_PORT}")
        (>&2 echo "You can also specify z/OSMF certificate explicitly in the ZOSMF_CERTIFICATE environmental variable in the zowe-setup-certificates.env file.")
        echo "</zowe-setup-certificates.sh>" >> "${LOG_FILE}"
        rm "${KEYSTORE_PREFIX}"* "${TRUSTSTORE_PREFIX}"* "${EXTERNAL_CA_PREFIX}"* "${LOCAL_CA_PREFIX}"* 2> /dev/null
        exit 1
    fi
  fi
fi

echo "Creating certificates and keystores... DONE"

# If a keyring is used to hold certificates then make sure the local_ca directory doesn't contain
# any "localca" certificates.
if [ -n "${ZOWE_KEYRING}" ]; then
  rm -f "${LOCAL_CA_PREFIX}"*
fi

# detect external CAs
detectExternalCAs

# re-create and populate the zowe-certificates.env file.
ZOWE_CERTIFICATES_ENV=${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
rm ${ZOWE_CERTIFICATES_ENV} 2> /dev/null

if [[ -z "${ZOWE_KEYRING}" ]]; then
  cat >${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME} <<EOF
KEY_ALIAS="${KEYSTORE_ALIAS}"
KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD}
KEYSTORE="${KEYSTORE_PREFIX}.p12"
KEYSTORE_TYPE="PKCS12"
TRUSTSTORE="${TRUSTSTORE_PREFIX}.p12"
KEYSTORE_KEY="${KEYSTORE_PREFIX}.key"
KEYSTORE_CERTIFICATE="${KEYSTORE_PREFIX}.cer-ebcdic"
KEYSTORE_CERTIFICATE_AUTHORITY="${LOCAL_CA_PREFIX}.cer-ebcdic"
EXTERNAL_ROOT_CA="${EXTERNAL_ROOT_CA}"
EXTERNAL_CERTIFICATE_AUTHORITIES="${EXTERNAL_CERTIFICATE_AUTHORITIES}"
ZOWE_APIM_VERIFY_CERTIFICATES=${VERIFY_CERTIFICATES}
ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES=${NONSTRICT_VERIFY_CERTIFICATES}
SSO_FALLBACK_TO_NATIVE_AUTH=${SSO_FALLBACK_TO_NATIVE_AUTH}
EOF

  if [ -n "${COMPONENT_LEVEL_CERTIFICATES}" ]; then
    echo "" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
    for service_id in $(echo "${COMPONENT_LEVEL_CERTIFICATES}" | sed -e 's#,# #g'); do
      echo "# To configure certificate for ${service_id}, you can add these entries to \"components.${service_id}\" of your YAML configuration:" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
      echo "# certificate:" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
      echo "#   keystore:" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
      echo "#     alias: ${service_id}" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
      echo "#   pem:" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
      echo "#     key: ${KEYSTORE_PREFIX}.${service_id}.key" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
      echo "#     certificate: ${KEYSTORE_PREFIX}.${service_id}.cer-ebcdic" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
    done
  fi
else
  cat >${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME} <<EOF
KEY_ALIAS="${KEYSTORE_ALIAS}"
KEYSTORE_PASSWORD="password"
KEYRING_OWNER="${ZOWE_USER_ID}"
KEYRING_NAME="${ZOWE_KEYRING}"
KEYSTORE="safkeyring:////\${KEYRING_OWNER}/\${KEYRING_NAME}"
KEYSTORE_TYPE="JCERACFKS"
TRUSTSTORE="safkeyring:////\${KEYRING_OWNER}/\${KEYRING_NAME}"
EXTERNAL_ROOT_CA="${EXTERNAL_ROOT_CA}"
EXTERNAL_CERTIFICATE_AUTHORITIES="${EXTERNAL_CERTIFICATE_AUTHORITIES}"
LOCAL_CA="${ZOWE_LOCALCA_LABEL}"
ZOWE_APIM_VERIFY_CERTIFICATES=${VERIFY_CERTIFICATES}
ZOWE_APIM_NONSTRICT_VERIFY_CERTIFICATES=${NONSTRICT_VERIFY_CERTIFICATES}
SSO_FALLBACK_TO_NATIVE_AUTH=${SSO_FALLBACK_TO_NATIVE_AUTH}
EOF

  if [ -n "${COMPONENT_LEVEL_CERTIFICATES}" ]; then
    echo "" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
    for service_id in $(echo "${COMPONENT_LEVEL_CERTIFICATES}" | sed -e 's#,# #g'); do
      echo "# To configure certificate for ${service_id}, you can add these entries to \"components.${service_id}\" of your YAML configuration:" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
      echo "# certificate:" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
      echo "#   keystore:" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
      echo "#     alias: ${service_id}" >> ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
    done
  fi
fi

if [[ "${ZOWE_LOCK_KEYSTORE}" == "true" ]]; then
  permissions=500
else
  permissions=570
fi

# set up privileges and ownership
chmod -R $permissions ${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}/* ${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}/* 2> /dev/null # In some keystore scenarios these directories might be empty, so suppress error
echo "Trying to change an owner of the ${KEYSTORE_DIRECTORY}."

if ! chown -R "${ZOWE_USER_ID}" "${KEYSTORE_DIRECTORY}" >> "${LOG_FILE}" 2>&1 ; then
  echo "Unable to change the current owner of the ${KEYSTORE_DIRECTORY} directory to the ${ZOWE_USER_ID} owner. See $LOG_FILE for more details."
  echo "Trying to change a group of the ${KEYSTORE_DIRECTORY}."
  if [[ "${ZOWE_LOCK_KEYSTORE}" == "true" ]]; then
    permissions=550
  else
    permissions=750
  fi
  chmod -R ${permissions} "${KEYSTORE_DIRECTORY}"
  if ! chgrp -R "${ZOWE_GROUP_ID}" "${KEYSTORE_DIRECTORY}" >> "${LOG_FILE}" 2>&1 ; then
    echo "Unable to change the group of the ${KEYSTORE_DIRECTORY} directory to the ${ZOWE_GROUP_ID} group. See $LOG_FILE for more details."
    echo "Please change the owner or the group of the ${KEYSTORE_DIRECTORY} manually so that keystores are protected correctly!"
    echo "Ideally, only ${ZOWE_USER_ID} should have access to the ${KEYSTORE_DIRECTORY}."
  else
    echo "Group of the ${KEYSTORE_DIRECTORY} changed successfully to the ${ZOWE_GROUP_ID} owner."
  fi
else
  echo "Owner of the ${KEYSTORE_DIRECTORY} changed successfully to the ${ZOWE_USER_ID} owner."
fi

echo "</zowe-setup-certificates.sh>" >> "${LOG_FILE}"
