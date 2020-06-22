#!/bin/sh

# Variables to be supplied:
# - HOSTNAME - The hostname of the system running API Mediation
# - IPADDRESS - The IP Address of the system running API Mediation
# - VERIFY_CERTIFICATES - true/false - Should APIML verify certificates of services (defaults to true)
# - EXTERNAL_CERTIFICATE - optional - Path to a PKCS12 keystore with a server certificate for APIML
# - EXTERNAL_CERTIFICATE_ALIAS - optional - Alias of the certificate in the keystore
# - EXTERNAL_CERTIFICATE_AUTHORITIES - optional - Public certificates of trusted CAs
# - ZOSMF_CERTIFICATE - Public certificates of z/OSMF - multiple certificates delimited with space has to be enclosed with quotes ("path/cer1 path/cer2")

# - KEYSTORE_DIRECTORY - Location for generated certificates (defaults to /global/zowe/keystore)
# - KEYSTORE_PASSWORD - a password that is used to secure EXTERNAL_CERTIFICATE keystore and
#                       that will be also used to secure newly generated keystores for API Mediation.
# - ZOWE_USER_ID - zowe user id to set up ownership of the generated certificates
# - ZOWE_KEYRING - specify zowe keyring that keeps zowe certificates, if not specified USS keystore
#                  files will be created.
# - GENERATE_CERTS_FOR_KEYRING - If you used ZWEKRING jcl to configure certificates and the keyring
#                                then set this variable to false (defaults to false)

function detectExternalRootCA {
  echo "Detecting external root CA... STARTED"
  if [[ -z "${ZOWE_KEYRING}" ]]; then
    for file in ${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}/extca.*.cer-ebcdic; do
      if [[ ! -f $file ]]; then
        break;
      fi
      CERTIFICATE_OWNER=`keytool -printcert -file $file | grep -e Owner: | cut -d ":" -f 2-`
      CERTIFICATE_ISSUER=`keytool -printcert -file $file | grep -e Issuer: | cut -d ":" -f 2-`
      if [[ $CERTIFICATE_OWNER == $CERTIFICATE_ISSUER ]]; then
        EXTERNAL_ROOT_CA=$file;
        break;
      fi
    done
  else
    # Assumption: External certificate contains its chain of trust. The root certificate is the last one in the list
    #             that we get using the commands just below:
    var_keytool_cmd="keytool -list -storetype JCERACFKS -keystore safkeyring://${ZOWE_USER_ID}/${ZOWE_KEYRING} \
      -J-Djava.protocol.handler.pkgs=com.ibm.crypto.provider"
    var_CA_chain_length=`$var_keytool_cmd -alias $KEYSTORE_ALIAS -v | grep -c -e Owner:`
    if [[ $var_CA_chain_length -lt 2 ]]; then
      echo "The $KEYSTORE_ALIAS certificate is self-signed or does not contain its CA chain. If the certificate is externally signed \
and its root CA is connected to the same keyring then you can manually set the EXTERNAL_ROOT_CA env variable with the \
root CA label in the ${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME} file."
    else
      var_root_CA_DN=`$var_keytool_cmd -alias $KEYSTORE_ALIAS -v | grep -e Issuer: | tail -n 1 | cut -d ":" -f 2-`
      var_root_CA_alias=`$var_keytool_cmd -v | grep -e "Owner:$var_root_CA_DN" -P 5 | grep -e "Alias name:" | cut -d ":" -f 2-`
      EXTERNAL_ROOT_CA=`echo ${var_root_CA_alias} | tr -d '[:space:]'`
      echo "A label of the external root CA in the keyring: $EXTERNAL_ROOT_CA"
    fi
  fi
  echo "Detecting external root CA... DONE"
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

. ${ZOWE_ROOT_DIR}/bin/utils/setup-log-dir.sh
set_install_log_directory "${LOG_DIRECTORY}"
validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
set_install_log_file "zowe-setup-certificates"

echo "<zowe-setup-certificates.sh>" >> $LOG_FILE

# Load default values
DEFAULT_CERTIFICATES_CONFIG_FILE=${ZOWE_ROOT_DIR}/bin/zowe-setup-certificates.env
echo "Loading default variables from ${DEFAULT_CERTIFICATES_CONFIG_FILE} file."
. ${DEFAULT_CERTIFICATES_CONFIG_FILE}

if [[ -z ${CERTIFICATES_CONFIG_FILE} ]]
then
  echo "-p parameter not set. Using default ${DEFAULT_CERTIFICATES_CONFIG_FILE} file instead."
else
  if [[ -f ${CERTIFICATES_CONFIG_FILE} ]]
  then
    echo "Loading ${CERTIFICATES_CONFIG_FILE} file and overriding default variables."
    # Load custom values
    . ${CERTIFICATES_CONFIG_FILE}
  else
    echo "${CERTIFICATES_CONFIG_FILE} file does not exist."
    exit 1
  fi
fi

ZOWE_EXPLORER_HOST=${HOSTNAME}
ZOWE_IP_ADDRESS=${IPADDRESS}
. ${ZOWE_ROOT_DIR}/bin/zowe-init.sh -s
. ${ZOWE_ROOT_DIR}/scripts/utils/configure-java.sh

ZOWE_CERT_ENV_NAME=zowe-certificates.env
LOCAL_KEYSTORE_SUBDIR=local_ca

# create keystore directories
if [ ! -d ${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR} ]; then
  if ! mkdir -p ${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}; then
    echo "Unable to create ${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR} directory."
    exit 1;
  fi
fi

if [ ! -d ${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS} ]; then
  if ! mkdir -p ${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}; then
    echo "Unable to create ${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS} directory."
    exit 1;
  fi
fi

echo "Creating certificates and keystores... STARTED"
# set up parameters for apiml_cm.sh script
KEYSTORE_PREFIX="${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}/${KEYSTORE_ALIAS}.keystore"
TRUSTSTORE_PREFIX="${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}/${KEYSTORE_ALIAS}.truststore"
EXTERNAL_CA_PREFIX=${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}/extca
LOCAL_CA_PREFIX=${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}/localca
SAN="SAN=dns:${ZOWE_EXPLORER_HOST},ip:${ZOWE_IP_ADDRESS},dns:localhost.localdomain,dns:localhost,ip:127.0.0.1"

# If any external certificate fields are zero [blank], do not use the external setup method.
# If all external certificate fields are zero [blank], create everything from scratch.
# If all external fields are not zero [valid string], use external setup method.

if [[ -z "${EXTERNAL_CERTIFICATE}" ]] || [[ -z "${EXTERNAL_CERTIFICATE_ALIAS}" ]] || [[ -z "${EXTERNAL_CERTIFICATE_AUTHORITIES}" ]]; then
  if [[ -z "${EXTERNAL_CERTIFICATE}" ]] && [[ -z "${EXTERNAL_CERTIFICATE_ALIAS}" ]] && [[ -z "${EXTERNAL_CERTIFICATE_AUTHORITIES}" ]]; then
    if [[ -z "${ZOWE_KEYRING}" ]]; then
      ${ZOWE_ROOT_DIR}/bin/apiml_cm.sh --verbose --log $LOG_FILE --action setup --service-ext ${SAN} --service-password ${KEYSTORE_PASSWORD} \
        --service-alias ${KEYSTORE_ALIAS} --service-keystore ${KEYSTORE_PREFIX} --service-truststore ${TRUSTSTORE_PREFIX} --local-ca-filename ${LOCAL_CA_PREFIX}
      RC=$?
      echo "apiml_cm.sh --action setup returned: $RC" >> $LOG_FILE
    elif [[ "${GENERATE_CERTS_FOR_KEYRING}" != "false" ]]; then
      ${ZOWE_ROOT_DIR}/bin/apiml_cm.sh --verbose --log $LOG_FILE --action setup --service-ext ${SAN} --service-keystore ${KEYSTORE_PREFIX} \
        --service-alias ${KEYSTORE_ALIAS} --zowe-userid ${ZOWE_USER_ID} --zowe-keyring ${ZOWE_KEYRING} --service-storetype "JCERACFKS" --local-ca-filename ${LOCAL_CA_PREFIX}
      RC=$?
      echo "apiml_cm.sh --action setup returned: $RC" >> $LOG_FILE
    else
      echo "Generating certificates for the keyring is skipped."
    fi
  else
    (>&2 echo "Zowe Install setup configuration is invalid; check your zowe-setup-certificates.env file.")
    (>&2 echo "Some external apiml certificate fields are supplied...Fields must be filled out in full or left completely blank.")
    (>&2 echo "See $LOG_FILE for more details.")
    echo "</zowe-setup-certificates.sh>" >> $LOG_FILE
    rm ${KEYSTORE_PREFIX}* ${TRUSTSTORE_PREFIX}* ${EXTERNAL_CA_PREFIX}* ${LOCAL_CA_PREFIX}* 2> /dev/null
    exit 1
  fi
else
  EXT_CA_PARM=""
  for CA in ${EXTERNAL_CERTIFICATE_AUTHORITIES}; do
      EXT_CA_PARM="${EXT_CA_PARM} --external-ca ${CA} "
  done

  if [[ -z "${ZOWE_KEYRING}" ]]; then
    ${ZOWE_ROOT_DIR}/bin/apiml_cm.sh --verbose --log $LOG_FILE --action setup --service-ext ${SAN} --service-password ${KEYSTORE_PASSWORD} \
      --external-certificate ${EXTERNAL_CERTIFICATE} --external-certificate-alias ${EXTERNAL_CERTIFICATE_ALIAS} ${EXT_CA_PARM} \
      --service-alias ${KEYSTORE_ALIAS} --service-keystore ${KEYSTORE_PREFIX} --service-truststore ${TRUSTSTORE_PREFIX} --local-ca-filename ${LOCAL_CA_PREFIX} \
      --external-ca-filename ${EXTERNAL_CA_PREFIX}
    RC=$?
    echo "apiml_cm.sh --action setup returned: $RC" >> $LOG_FILE
  elif [[ "${GENERATE_CERTS_FOR_KEYRING}" != "false" ]]; then
    ${ZOWE_ROOT_DIR}/bin/apiml_cm.sh --verbose --log $LOG_FILE --action setup --service-ext ${SAN} --zowe-userid ${ZOWE_USER_ID} --zowe-keyring ${ZOWE_KEYRING} \
      --service-storetype "JCERACFKS" --external-certificate ${EXTERNAL_CERTIFICATE} --external-certificate-alias ${EXTERNAL_CERTIFICATE_ALIAS} \
      --service-alias ${KEYSTORE_ALIAS} --service-keystore ${KEYSTORE_PREFIX}  --local-ca-filename ${LOCAL_CA_PREFIX}
    RC=$?
    echo "apiml_cm.sh --action setup returned: $RC" >> $LOG_FILE
  else
    echo "Generating certificates for the keyring is skipped."
  fi
fi

if [ "$RC" -ne "0" ]; then
    (>&2 echo "apiml_cm.sh --action setup has failed. See $LOG_FILE for more details")
    echo "</zowe-setup-certificates.sh>" >> $LOG_FILE
    rm ${KEYSTORE_PREFIX}* ${TRUSTSTORE_PREFIX}* ${EXTERNAL_CA_PREFIX}* ${LOCAL_CA_PREFIX}* 2> /dev/null
    exit 1
fi

if [[ "${VERIFY_CERTIFICATES}" == "true" ]]; then
  if [[ -z "${ZOWE_KEYRING}" ]]; then
    ${ZOWE_ROOT_DIR}/bin/apiml_cm.sh --verbose --log $LOG_FILE --action trust-zosmf \
      --service-password ${KEYSTORE_PASSWORD} --service-truststore ${TRUSTSTORE_PREFIX} --zosmf-certificate "${ZOSMF_CERTIFICATE}" \
      --service-keystore ${KEYSTORE_PREFIX} --local-ca-filename ${LOCAL_CA_PREFIX}
  else
    export GENERATE_CERTS_FOR_KEYRING;
    ${ZOWE_ROOT_DIR}/bin/apiml_cm.sh --verbose --log $LOG_FILE --action trust-zosmf --zowe-userid ${ZOWE_USER_ID} \
      --zowe-keyring ${ZOWE_KEYRING} --service-storetype "JCERACFKS" --zosmf-certificate "${ZOSMF_CERTIFICATE}" \
      --service-keystore ${KEYSTORE_PREFIX} --service-password ${KEYSTORE_PASSWORD} \
      --service-truststore ${TRUSTSTORE_PREFIX} --local-ca-filename ${LOCAL_CA_PREFIX}
  fi
  RC=$?

  echo "apiml_cm.sh --action trust-zosmf returned: $RC" >> $LOG_FILE
  if [ "$RC" -ne "0" ]; then
      (>&2 echo "apiml_cm.sh --action trust-zosmf has failed. See $LOG_FILE for more details")
      (>&2 echo "ERROR: z/OSMF is not trusted by the API Mediation Layer. Make sure ZOWE_ZOSMF_HOST and ZOWE_ZOSMF_PORT variables define the desired z/OSMF instance.")
      (>&2 echo "ZOWE_ZOSMF_HOST=${ZOWE_ZOSMF_HOST}   ZOWE_ZOSMF_PORT=${ZOWE_ZOSMF_PORT}")
      (>&2 echo "You can also specify z/OSMF certificate explicitly in the ZOSMF_CERTIFICATE environmental variable in the zowe-setup-certificates.env file.")
      echo "</zowe-setup-certificates.sh>" >> $LOG_FILE
      rm ${KEYSTORE_PREFIX}* ${TRUSTSTORE_PREFIX}* ${EXTERNAL_CA_PREFIX}* ${LOCAL_CA_PREFIX}* 2> /dev/null
      exit 1
  fi
fi
echo "Creating certificates and keystores... DONE"

JWT_ALIAS="jwtsecret"
APIML_PUBLIC_KEY="${KEYSTORE_PREFIX}.${JWT_ALIAS}.pem"
P12_PUBLIC_KEY="${KEYSTORE_PREFIX}.${JWT_ALIAS}.p12"
if ! [[ -z "${PKCS11_TOKEN_NAME}" ]] && ! [[ -z "${PKCS11_TOKEN_LABEL}" ]]; then
  if [[ -f ${APIML_PUBLIC_KEY} ]]
  then
    chtag -tc ISO8859-1 ${APIML_PUBLIC_KEY}
    if ! keytool -importcert -file ${APIML_PUBLIC_KEY} -keystore ${P12_PUBLIC_KEY} -storetype pkcs12 -storepass ${KEYSTORE_PASSWORD} -trustcacerts -noprompt >> $LOG_FILE 2>&1 ; then
      echo "Unable to convert ${APIML_PUBLIC_KEY} to PKCS#12. See $LOG_FILE for more details."
    else
      keytool -importcert -file ${LOCAL_CA_PREFIX}.cer -alias localca -keystore ${P12_PUBLIC_KEY} -storetype pkcs12 -storepass ${KEYSTORE_PASSWORD} -trustcacerts -noprompt >> $LOG_FILE 2>&1
      UPPER_KEY_LABEL=$(echo "${PKCS11_TOKEN_LABEL}" | tr '[:lower:]' '[:upper:]')
      if ! echo "${KEYSTORE_PASSWORD}" | gskkyman -i -t ${PKCS11_TOKEN_NAME} -l ${UPPER_KEY_LABEL} -p ${P12_PUBLIC_KEY} >> $LOG_FILE 2>&1 ; then
        echo "Unable to store ${P12_PUBLIC_KEY} in token ${PKCS11_TOKEN_NAME} with label ${UPPER_KEY_LABEL}. See $LOG_FILE for more details."
      else
        echo "Successfully loaded ${APIML_PUBLIC_KEY} into token ${PKCS11_TOKEN_NAME} with label ${UPPER_KEY_LABEL}."
      fi
      rm ${P12_PUBLIC_KEY} 2> /dev/null
    fi
  else
    echo "No such file ${APIML_PUBLIC_KEY}, unable to complete SSO setup."
  fi
fi

# detect external root CA
EXTERNAL_ROOT_CA=
detectExternalRootCA;

# re-create and populate the zowe-certificates.env file.
ZOWE_CERTIFICATES_ENV=${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME}
rm ${ZOWE_CERTIFICATES_ENV} 2> /dev/null

if [[ -z "${ZOWE_KEYRING}" ]]; then
  cat >${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME} <<EOF
    KEY_ALIAS=${KEYSTORE_ALIAS}
    KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD}
    KEYSTORE=${KEYSTORE_PREFIX}.p12
    KEYSTORE_TYPE="PKCS12"
    TRUSTSTORE=${TRUSTSTORE_PREFIX}.p12
    KEYSTORE_KEY=${KEYSTORE_PREFIX}.key
    KEYSTORE_CERTIFICATE=${KEYSTORE_PREFIX}.cer-ebcdic
    KEYSTORE_CERTIFICATE_AUTHORITY=${LOCAL_CA_PREFIX}.cer-ebcdic
    EXTERNAL_ROOT_CA=${EXTERNAL_ROOT_CA}
    ZOWE_APIM_VERIFY_CERTIFICATES=${VERIFY_CERTIFICATES}
    SETUP_APIML_SSO=${SETUP_APIML_SSO}
    SSO_FALLBACK_TO_NATIVE_AUTH=${SSO_FALLBACK_TO_NATIVE_AUTH}
    PKCS11_TOKEN_NAME=${PKCS11_TOKEN_NAME}
    PKCS11_TOKEN_LABEL=${UPPER_KEY_LABEL}
EOF
else
  cat >${KEYSTORE_DIRECTORY}/${ZOWE_CERT_ENV_NAME} <<EOF
    KEY_ALIAS=${KEYSTORE_ALIAS}
    KEYSTORE_PASSWORD="password"
    KEYRING_OWNER="${ZOWE_USER_ID}"
    KEYRING_NAME="${ZOWE_KEYRING}"
    KEYSTORE="safkeyring:////\${KEYRING_OWNER}/\${KEYRING_NAME}"
    KEYSTORE_TYPE="JCERACFKS"
    TRUSTSTORE="safkeyring:////\${KEYRING_OWNER}/\${KEYRING_NAME}"
    EXTERNAL_ROOT_CA=${EXTERNAL_ROOT_CA}
    ZOWE_APIM_VERIFY_CERTIFICATES=${VERIFY_CERTIFICATES}
    SETUP_APIML_SSO=${SETUP_APIML_SSO}
    SSO_FALLBACK_TO_NATIVE_AUTH=${SSO_FALLBACK_TO_NATIVE_AUTH}
    PKCS11_TOKEN_NAME=${PKCS11_TOKEN_NAME}
    PKCS11_TOKEN_LABEL=${UPPER_KEY_LABEL}
EOF
fi

# set up privileges and ownership
chmod -R 500 ${KEYSTORE_DIRECTORY}/${LOCAL_KEYSTORE_SUBDIR}/* ${KEYSTORE_DIRECTORY}/${KEYSTORE_ALIAS}/*
echo "Trying to change an owner of the ${KEYSTORE_DIRECTORY}."
if ! chown -R ${ZOWE_USER_ID} ${KEYSTORE_DIRECTORY} >> $LOG_FILE 2>&1 ; then
  echo "Unable to change the current owner of the ${KEYSTORE_DIRECTORY} directory to the ${ZOWE_USER_ID} owner. See $LOG_FILE for more details."
  echo "Trying to change a group of the ${KEYSTORE_DIRECTORY}."
  chmod -R 550 ${KEYSTORE_DIRECTORY}
  if ! chgrp -R ${ZOWE_GROUP_ID} ${KEYSTORE_DIRECTORY} >> $LOG_FILE 2>&1 ; then
    echo "Unable to change the group of the ${KEYSTORE_DIRECTORY} directory to the ${ZOWE_GROUP_ID} group. See $LOG_FILE for more details."
    echo "Please change the owner or the group of the ${KEYSTORE_DIRECTORY} manually so that keystores are protected correctly!"
    echo "Ideally, only ${ZOWE_USER_ID} should have access to the ${KEYSTORE_DIRECTORY}."
  else
    echo "Group of the ${KEYSTORE_DIRECTORY} changed successfully to the ${ZOWE_GROUP_ID} owner."
  fi
else
  echo "Owner of the ${KEYSTORE_DIRECTORY} changed successfully to the ${ZOWE_USER_ID} owner."
fi

echo "</zowe-setup-certificates.sh>" >> $LOG_FILE
