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

ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_COMMON_NAME="Zowe Development Instances Certificate Authority"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_ORG_UNIT="API Mediation Layer"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_ORG="Zowe Sample"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_LOCALITY="Prague"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_STATE="Prague"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_COUNTRY="CZ"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_VALIDITY="3650"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_COMMON_NAME="Zowe Service"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG_UNIT="API Mediation Layer"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG="Zowe Sample"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_LOCALITY="Prague"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_STATE="Prague"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_COUNTRY="CZ"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_VALIDITY="3650"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_KEY_USAGE="keyEncipherment,digitalSignature,nonRepudiation,dataEncipherment"
ZWE_PRIVATE_DEFAULT_CERTIFICATE_EXTENDED_KEY_USAGE="clientAuth,serverAuth"

#######################################################################
# Notes: some keyring related functions, like ncert, are using R_datalib behind the scene. It requires proper
#        permission setup on the server.
#
# If you see error message like this, that means your user id doesn't have proper permission:
#
#   R_datalib call failed: function code: 01, SAF rc: 8, RACF rc: 8, RACF rsn: 8
#
# Check below link to learn failure reason codes:
#   https://www.ibm.com/docs/en/zos/2.3.0?topic=library-return-reason-codes
#
# Check this link to learn how to configure permission for RDATALIB:
#   https://www.ibm.com/docs/en/zos/2.3.0?topic=library-racf-authorization
# To retrieve private key of others, you need UPDATE access to
# <ringOwner>.<ringName>.LST resource in the RDATALIB class.
# To retrieve private key of CERTAUTH, you need CONTROL access to
# <ringOwner>.<ringName>.LST resource in the RDATALIB class.
#   https://www.ibm.com/docs/en/zos/2.3.0?topic=library-usage-notes#usgntrdata
#
# Example permission setup on RACF:
#   Keyring owner is ZWESVUSR
#   Keyring name is Zowe2Keyring
#
# - define permission and disable access for all
# RDEFINE RDATALIB ZWESVUSR.Zowe2Keyring.LST UACC(NONE)
# - allow list permission to IBMUSER
# PERMIT ZWESVUSR.Zowe2Keyring.LST CLASS(RDATALIB) ID(IBMUSER) ACCESS(CONTROL)
# - refresh RDATALIB permission
# SETROPTS RACLIST(RDATALIB) REFRESH
# - verify permission setup
# RLIST  RDATALIB ZWESVUSR.Zowe2Keyring.LST  ALL
# RLIST  FACILITY IRR.DIGTCERT.LISTRING  ALL
#######################################################################

pkeytool() {
  args=$@

  print_debug "- Calling keytool ${args}"
  result=$(keytool "$@" 2>&1)
  code=$?

  if [ ${code} -eq 0 ]; then
    echo "${result}"
    print_debug "  * keytool succeeded"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    if [ -n "${result}" ]; then
      print_trace "$(padding_left "${result}" "    ")"
    fi
  else
    print_debug "  * keytool failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi
  fi

  return ${code}
}

ncert_utility() {
  args=$@

  utils_dir="${ZWE_zowe_runtimeDirectory}/bin/utils"
  zct="${utils_dir}/ncert/src/cli.js"

  print_debug "- Calling ncert ${args}"
  # show we enable verbose mode of ncert command?
  result=$(node "${zct}" "$@" 2>&1)
  code=$?

  if [ ${code} -eq 0 ]; then
    echo "${result}"
    print_debug "  * ncert succeeded"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    if [ -n "${result}" ]; then
      print_trace "$(padding_left "${result}" "    ")"
    fi
  else
    print_debug "  * ncert failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi
  fi

  return ${code}
}

pkcs12_ensure_binary_tag() {
  keystore="${1}"

  if [ "${ZWE_RUN_ON_ZOS}" != "true" ]; then
    return 0
  fi
  if [ ! -f "${keystore}" ]; then
    # not created yet, maybe we should add a warning here
    return 0
  fi

  print_trace "- tag ${keystore} as binary"
  result=$(chtag -b "${keystore}" 2>&1)
  code=$?
  if [ ${code} -ne 0 ]; then
    print_trace "  * chtag failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi

    return ${code}
  fi
}

pkcs12_lock_keystore_directory() {
  keystore_dir="${1}"
  user="${2}"
  group="${3}"
  # can be read, write, or <none>
  group_permission="${4}"

  if [ "${group_permission}" = "write" ]; then
    print_debug "- Change keystore directory \"${keystore_dir}\" permission to 570"
    result=$(chmod -R 570 "${keystore_dir}" 2>&1)
    code=$?
  elif [ "${group_permission}" = "read" ]; then
    print_debug "- Change keystore directory \"${keystore_dir}\" permission to 550"
    result=$(chmod -R 550 "${keystore_dir}" 2>&1)
    code=$?
  else
    print_debug "- Change keystore directory \"${keystore_dir}\" permission to 500"
    result=$(chmod -R 500 "${keystore_dir}" 2>&1)
    code=$?
  fi
  if [ ${code} -ne 0 ]; then
    print_debug "  * chmod failed"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    if [ -n "${result}" ]; then
      print_trace "$(padding_left "${result}" "    ")"
    fi
    return 1
  fi

  print_debug "- Change keystore directory \"${keystore_dir}\" owner to ${user}:${group}"
  result=$(chown -R ${user}:${group} "${keystore_dir}" 2>&1)
  code=$?
  if [ ${code} -ne 0 ]; then
    print_debug "  * chown failed"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    if [ -n "${result}" ]; then
      print_trace "$(padding_left "${result}" "    ")"
    fi

    print_message "WARNING: Unable to change the owner of the ${keystore_dir} directory to ${user}:${group}."
    print_message "         Please change the owner and group of the ${keystore_dir} manually so that keystores are protected correctly!"
    print_message "         Ideally, only ${user} should have read access to the ${keystore_dir}."
  fi
}

pkcs12_create_certificate_authority() {
  keystore_dir="${1}"
  alias="${2}"
  password="${3}"
  common_name=${4:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_COMMON_NAME}}

  flags=$(get_java_pkcs12_keystore_flag)

  print_message ">>>> Generate PKCS12 format local CA with alias ${alias}:"
  mkdir -p "${keystore_dir}/${alias}"
  result=$(pkeytool -genkeypair -v \
            -alias "${alias}" \
            -keyalg RSA -keysize 2048 \
            -dname "CN=${common_name}, OU=${ZWE_PRIVATE_CERTIFICATE_CA_ORG_UNIT:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_ORG_UNIT}}, O=${ZWE_PRIVATE_CERTIFICATE_CA_ORG:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_ORG}}, L=${ZWE_PRIVATE_CERTIFICATE_CA_LOCALITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_LOCALITY}}, S=${ZWE_PRIVATE_CERTIFICATE_CA_STATE:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_STATE}}, C=${ZWE_PRIVATE_CERTIFICATE_CA_COUNTRY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_COUNTRY}}" \
            -keystore "${keystore_dir}/${alias}/${alias}.keystore.p12" \
            -keypass "${password}" \
            -storepass "${password}" \
            -storetype "PKCS12" \
            -validity "${ZWE_PRIVATE_CERTIFICATE_CA_VALIDITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_VALIDITY}}" \
            ${flags} \
            -ext KeyUsage="keyCertSign" \
            -ext BasicConstraints:"critical=ca:true")
  if [ $? -ne 0 ]; then
    return 1
  fi
  pkcs12_ensure_binary_tag "${keystore_dir}/${alias}/${alias}.keystore.p12"
  if [ $? -ne 0 ]; then
    return 1
  fi
}

pkcs12_create_certificate_and_sign() {
  keystore_dir="${1}"
  keystore_name="${2}"
  alias="${3}"
  password="${4}"
  common_name=${5:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_COMMON_NAME}}
  domains=${6}
  ca_alias=${7}
  ca_password=${8}


  print_message ">>>> Generate certificate \"${alias}\" in the keystore ${keystore_name}:"

  flags=$(get_java_pkcs12_keystore_flag)

  mkdir -p "${keystore_dir}/${keystore_name}"
  result=$(pkeytool -genkeypair -v \
            ${flags} \
            -alias "${alias}" \
            -keyalg RSA -keysize 2048 \
            -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
            -keypass "${password}" \
            -storepass "${password}" \
            -storetype "PKCS12" \
            -dname "CN=${common_name}, OU=${ZWE_PRIVATE_CERTIFICATE_ORG_UNIT:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG_UNIT}}, O=${ZWE_PRIVATE_CERTIFICATE_ORG:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG}}, L=${ZWE_PRIVATE_CERTIFICATE_LOCALITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_LOCALITY}}, S=${ZWE_PRIVATE_CERTIFICATE_STATE:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_STATE}}, C=${ZWE_PRIVATE_CERTIFICATE_COUNTRY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_COUNTRY}}" \
            -validity "${ZWE_PRIVATE_CERTIFICATE_VALIDITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_VALIDITY}}")
  if [ $? -ne 0 ]; then
    return 1
  fi
  pkcs12_ensure_binary_tag "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12"
  if [ $? -ne 0 ]; then
    return 1
  fi

  print_message ">>>> Generate CSR for the certificate \"${alias}\" in the keystore \"${keystore_name}\":"
  result=$(pkeytool ${flags} \
            -certreq -v \
            -alias "${alias}" \
            -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
            -storepass "${password}" \
            -file "${keystore_dir}/${keystore_name}/${alias}.csr" \
            -keyalg RSA \
            -storetype "PKCS12" \
            -dname "CN=${common_name}, OU=${ZWE_PRIVATE_CERTIFICATE_ORG_UNIT:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG_UNIT}}, O=${ZWE_PRIVATE_CERTIFICATE_ORG:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG}}, L=${ZWE_PRIVATE_CERTIFICATE_LOCALITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_LOCALITY}}, S=${ZWE_PRIVATE_CERTIFICATE_STATE:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_STATE}}, C=${ZWE_PRIVATE_CERTIFICATE_COUNTRY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_COUNTRY}}" \
            -validity "${ZWE_PRIVATE_CERTIFICATE_VALIDITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_VALIDITY}}")
  if [ $? -ne 0 ]; then
    return 1
  fi

  # generate SAN list
  san="SAN="
  for item in $(echo "${domains}" | lower_case | tr "," " "); do
    if [ -n "${item}" ]; then
      # test if it's IP
      if expr "${item}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
        san="${san}ip:${item},"
      else
        san="${san}dns:${item},"
      fi
    fi
  done
  san="${san}dns:localhost.localdomain,dns:localhost,ip:127.0.0.1"

  print_message ">>>> Sign the CSR using the Certificate Authority \"${ca_alias}\":"
  result=$(pkeytool ${flags} \
            -gencert -v \
            -infile "${keystore_dir}/${keystore_name}/${alias}.csr" \
            -outfile "${keystore_dir}/${keystore_name}/${alias}.signed.cer" \
            -keystore "${keystore_dir}/${ca_alias}/${ca_alias}.keystore.p12" \
            -alias "${ca_alias}" \
            -keypass "${ca_password}" \
            -storepass "${ca_password}" \
            -storetype "PKCS12" \
            -ext "${san}" \
            -ext "KeyUsage:critical=${ZWE_PRIVATE_CERTIFICATE_KEY_USAGE:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_KEY_USAGE}}" \
            -ext "ExtendedKeyUsage=${ZWE_PRIVATE_CERTIFICATE_EXTENDED_KEY_USAGE:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_EXTENDED_KEY_USAGE}}" \
            -rfc \
            -validity "${ZWE_PRIVATE_CERTIFICATE_VALIDITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_VALIDITY}}")
  if [ $? -ne 0 ]; then
    return 1
  fi

  # delete CSR
  rm -f "${keystore_dir}/${keystore_name}/${alias}.csr"

  ca_alias_lc=$(echo "${ca_alias}" | lower_case)
  ca_cert_file="${keystore_dir}/${ca_alias}/${ca_alias_lc}.cer"
  if [ ! -f "${ca_cert_file}" ]; then
    print_error "Error: CA certificate is not exported. Check \"zwe certificate pkcs12 export --help\" to find more details."
    return 1
  fi

  # test if we need to import CA into keystore
  keytool -list -v -noprompt \
    -alias "${ca_alias}" \
    -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
    -storepass "${password}" \
    -storetype "PKCS12" \
    >/dev/null 2>/dev/null
  if [ "$?" != "0" ]; then
    print_message ">>>> Import the Certificate Authority \"${ca_alias}\" to the keystore \"${keystore_name}\":"
    result=$(pkeytool ${flags} \
              -importcert -v \
              -trustcacerts -noprompt \
              -file "${ca_cert_file}" \
              -alias "${ca_alias}" \
              -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
              -storepass "${password}" \
              -storetype "PKCS12")
  fi

  # test if we need to import CA into truststore
  keytool -list -v -noprompt \
    -alias "${ca_alias}" \
    -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.truststore.p12" \
    -storepass "${password}" \
    -storetype "PKCS12" \
    >/dev/null 2>/dev/null
  if [ "$?" != "0" ]; then
    print_message ">>>> Import the Certificate Authority \"${ca_alias}\" to the truststore \"${keystore_name}\":"
    result=$(pkeytool ${flags} \
              -importcert -v \
              -trustcacerts -noprompt \
              -file "${ca_cert_file}" \
              -alias "${ca_alias}" \
              -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.truststore.p12" \
              -storepass "${password}" \
              -storetype "PKCS12")

    pkcs12_ensure_binary_tag "${keystore_dir}/${keystore_name}/${keystore_name}.truststore.p12"
    if [ $? -ne 0 ]; then
      return 1
    fi
  fi

  print_message ">>>> Import the signed CSR to the keystore \"${keystore_name}\":"
  result=$(pkeytool ${flags} \
            -importcert -v \
            -trustcacerts -noprompt \
            -file "${keystore_dir}/${keystore_name}/${alias}.signed.cer" \
            -alias "${alias}" \
            -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
            -storepass "${password}" \
            -storetype "PKCS12")
  if [ $? -ne 0 ]; then
    return 1
  fi

  # delete signed CSR
  rm -f "${keystore_dir}/${keystore_name}/${alias}.signed.cer"
}

# This function acts similar pkcs12_create_certificate_and_sign but doesn't use keytool
# JDK8 keytool does not support SAN dns with * in it.
# TODO: allow to customize dname
pkcs12_create_certificate_and_sign_with_node() {
  keystore_dir="${1}"
  keystore_name="${2}"
  alias="${3}"
  password="${4}"
  common_name=${5:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_COMMON_NAME}}
  domains=${6}
  ca_alias=${7}
  ca_password=${8}

  ca_alias_lc=$(echo "${ca_alias}" | lower_case)

  print_message ">>>> Generate certificate \"${alias}\" in the keystore ${keystore_name}:"
  mkdir -p "${keystore_dir}/${keystore_name}"

  # generate --alt list from domains list
  alt_names=
  for item in $(echo "${domains}" | lower_case | tr "," " "); do
    if [ -n "${item}" ]; then
      alt_names="${alt_names} --alt ${item}"
    fi
  done

  # make sure keystore file is tagged as binary
  pkcs12_ensure_binary_tag "${keystore_dir}/${ca_alias}/${ca_alias}.keystore.p12"
  if [ $? -ne 0 ]; then
    return 1
  fi
  pkcs12_ensure_binary_tag "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12"
  if [ $? -ne 0 ]; then
    return 1
  fi

  # generate cert
  result=$(ncert_utility pkcs12 generate "${alias}" \
            --ca "${keystore_dir}/${ca_alias}/${ca_alias}.keystore.p12" \
            --cap "${ca_password}" \
            --caa "${ca_alias_lc}" \
            -f "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
            -p "${password}" \
            ${alt_names})
  if [ $? -ne 0 ]; then
    return 1
  fi

  ca_cert_file="${keystore_dir}/${ca_alias}/${ca_alias_lc}.cer"
  if [ ! -f "${ca_cert_file}" ]; then
    print_error "Error: CA certificate is not exported. Check \"zwe certificate pkcs12 export --help\" to find more details."
    return 1
  fi

  # test if we need to import CA into keystore
  keytool -list -v -noprompt \
    -alias "${ca_alias}" \
    -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
    -storepass "${password}" \
    -storetype "PKCS12" \
    >/dev/null 2>/dev/null
  if [ "$?" != "0" ]; then
    print_message ">>>> Import the Certificate Authority \"${ca_alias}\" to the keystore \"${keystore_name}\":"
    result=$(pkeytool -importcert -v \
              -trustcacerts -noprompt \
              -file "${ca_cert_file}" \
              -alias "${ca_alias}" \
              -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
              -storepass "${password}" \
              -storetype "PKCS12")
  fi
}

pkcs12_import_pkcs12_keystore() {
  dest_keystore="${1}"
  dest_keystore_dir=$(dirname "${dest_keystore}")
  dest_password="${2}"
  dest_alias="${3}"
  source_keystore="${4}"
  source_password="${5}"
  source_alias="${6}"

  print_message ">>>> Import ${source_alias} from keystore \"${source_keystore}\" to \"${dest_keystore}\" as ${dest_alias}:"

  # make sure directory exists
  print_trace "- Make sure keystore directory ${dest_keystore_dir} exists."
  result=$(mkdir -p "${dest_keystore_dir}")
  if [ ! -d "${dest_keystore_dir}" ]; then
    print_trace "  * Output:"
    if [ -n "${result}" ]; then
      print_trace "$(padding_left "${result}" "    ")"
    fi
    print_error "Error ZWEL0139E: Failed to create directory ${dest_keystore_dir}."
    return 139
  fi

  pkcs12_ensure_binary_tag "${source_keystore}"
  if [ $? -ne 0 ]; then
    return 1
  fi

  flags=$(get_java_pkcs12_keystore_flag)

  result=$(pkeytool ${flags} \
            -importkeystore -v \
            -noprompt \
            -deststoretype "PKCS12" \
            -destkeystore "${dest_keystore}" \
            -deststorepass "${dest_password}" \
            -destkeypass "${dest_password}" \
            -destalias "${dest_alias}" \
            -srcstoretype "PKCS12" \
            -srckeystore "${source_keystore}" \
            -srcstorepass "${source_password}" \
            -srcalias "${source_alias}")
  if [ $? -ne 0 ]; then
    return 1
  fi

  pkcs12_ensure_binary_tag "${dest_keystore}"
  if [ $? -ne 0 ]; then
    return 1
  fi
}

pkcs12_import_certificates() {
  dest_keystore="${1}"
  dest_password="${2}"
  # CA files names separated by comma
  ca_files="${3}"
  alias="${4:-extca}"

  flags=$(get_java_pkcs12_keystore_flag)

  ca_index=1
  while read -r ca_file; do
    ca_file=$(echo "${ca_file}" | trim)
    if [ -n "${ca_file}" ]; then
      print_message ">>>> Import \"${ca_file}\" to the keystore \"${dest_keystore}\":"
      result=$(pkeytool ${flags} \
                -importcert -v \
                -trustcacerts -noprompt \
                -file "${ca_file}" \
                -alias "${alias}${ca_index}" \
                -keystore "${dest_keystore}" \
                -storepass "${dest_password}" \
                -storetype "PKCS12")
      if [ $? -ne 0 ]; then
        return 1
      fi

      ca_index=$((ca_index+1))
    fi
  done <<EOF
$(echo "${ca_files}" | tr "," "\n")
EOF
}

pkcs12_trust_service() {
  keystore_dir="${1}"
  keystore_name="${2}"
  # password of truststore (<keystore_dir>/<keystore_name>.truststore.p12)
  password="${3}"
  service_host="${4}"
  service_port="${5}"
  service_alias=${6}

  print_message ">>>> Getting certificates from service host"
  print_cert_cmd="-printcert -sslserver ${service_host}:${service_port} -J-Dfile.encoding=UTF8"

  if [ "${ZWE_PRIVATE_LOG_LEVEL_ZWELS}" = "DEBUG" -o "${ZWE_PRIVATE_LOG_LEVEL_ZWELS}" = "TRACE" ]; then
    # only run in debug mode
    service_fingerprints=$(pkeytool ${print_cert_cmd} | grep -e 'Owner:' -e 'Issuer:' -e 'SHA1:' -e 'SHA256:' -e 'MD5')
    code=$?
    if [ ${code} -ne 0 ]; then
      print_error "Failed to get certificate of service instance https://${service_host}:${service_port}, exit code ${code}."
      return 1
    fi
    print_debug "> service certificate fingerprint:"
    print_debug "${service_fingerprints}"
  fi

  tmp_file=$(create_tmp_file "service-cert" "${keystore_dir}/${keystore_name}")
  print_debug "> Temporary certificate file is ${tmp_file}"
  keytool ${print_cert_cmd} -rfc > "${tmp_file}"
  code=$?
  chmod 700 "${tmp_file}"
  if [ ${code} -ne 0 ]; then
    print_error "Failed to get certificate of service instance https://${service_host}:${service_port}, exit code ${code}."
    return 1
  fi

  flags=$(get_java_pkcs12_keystore_flag)

  # parse keytool output into separate files
  csplit -s -k -f "${keystore_dir}/${keystore_name}/${service_alias}" "${tmp_file}" /-----END\ CERTIFICATE-----/1 \
    {$(expr `grep -c -e '-----END CERTIFICATE-----' "${tmp_file}"` - 1)}
  for cert in "${keystore_dir}/${keystore_name}/${service_alias}"*; do
    [ -s "${cert}" ] || continue
    cert_file=$(basename "${cert}")
    cert_alias=${cert_file%.cer}
    echo ">>>> Import a certificate \"${cert_alias}\" to the truststore:"
    result=$(pkeytool ${flags} \
              -importcert -v \
              -trustcacerts \
              -noprompt \
              -file "${cert}" \
              -alias "${cert_alias}" \
              -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.truststore.p12" \
              -storepass "${password}" \
              -storetype "PKCS12")
    if [ $? -ne 0 ]; then
      return 1
    fi
  done

  pkcs12_ensure_binary_tag "${keystore_dir}/${keystore_name}/${keystore_name}.truststore.p12"
  if [ $? -ne 0 ]; then
    return 1
  fi

  # clean up temporary files
  rm -f "${tmp_file}"
  rm -f "${keystore_dir}/${keystore_name}/${service_alias}"*
}

pkcs12_export_pem() {
  keystore_file="${1}"
  keystore_dir=$(dirname "${keystore_file}")
  password="${2}"
  # these private keys will also be exported
  private_key_aliases="${3}"

  print_message ">>>> List content of keystore \"${keystore_file}\":"
  keystore_content=$(pkeytool -list \
            -keystore "${keystore_file}" \
            -storepass "${password}" \
            -storetype "PKCS12")
  if [ $? -ne 0 ]; then
    return 1
  fi

  aliases=$(echo "${keystore_content}" | grep -i keyentry | awk -F, '{print $1}')
  while read -r alias; do
    if [ -n "${alias}" ]; then
      alias_lc=$(echo "${alias}" | lower_case)
      print_message ">>>> Export certificate \"${alias}\" to PEM format"
      result=$(pkeytool -exportcert -v \
                -alias "${alias}" \
                -keystore "${keystore_file}" \
                -storepass "${password}" \
                -storetype "PKCS12" \
                -rfc \
                -file "${keystore_dir}/${alias_lc}.cer")
      if [ $? -ne 0 ]; then
        return 1
      fi
      if [ `uname` = "OS/390" ]; then
        iconv -f ISO8859-1 -t IBM-1047 "${keystore_dir}/${alias_lc}.cer" > "${keystore_dir}/${alias_lc}.cer-ebcdic"
        mv "${keystore_dir}/${alias_lc}.cer-ebcdic" "${keystore_dir}/${alias_lc}.cer"
        ensure_file_encoding "${keystore_dir}/${alias_lc}.cer" "CERTIFICATE"
      fi
    fi
  done <<EOF
$(echo "${aliases}")
EOF

  aliases=$(echo "${keystore_content}" | grep -i trustedcertentry | awk -F, '{print $1}')
  while read -r alias; do
    if [ -n "${alias}" ]; then
      alias_lc=$(echo "${alias}" | lower_case)
      print_message ">>>> Export certificate \"${alias}\" to PEM format"
      result=$(pkeytool -exportcert -v \
                -alias "${alias}" \
                -keystore "${keystore_file}" \
                -storepass "${password}" \
                -storetype "PKCS12" \
                -rfc \
                -file "${keystore_dir}/${alias_lc}.cer")
      if [ $? -ne 0 ]; then
        return 1
      fi
      if [ `uname` = "OS/390" ]; then
        iconv -f ISO8859-1 -t IBM-1047 "${keystore_dir}/${alias_lc}.cer" > "${keystore_dir}/${alias_lc}.cer-ebcdic"
        mv "${keystore_dir}/${alias_lc}.cer-ebcdic" "${keystore_dir}/${alias_lc}.cer"
        ensure_file_encoding "${keystore_dir}/${alias_lc}.cer" "CERTIFICATE"
      fi
    fi
  done <<EOF
$(echo "${aliases}")
EOF

  while read -r alias; do
    alias=$(echo "${alias}" | trim)
    if [ -n "${alias}" ]; then
      alias_lc=$(echo "${alias}" | lower_case)

      print_message ">>>> Exporting certificate \"${alias}\" private key"
      if [ "${ZWE_RUN_ON_ZOS}" = "true" ]; then
        java -cp "${ZWE_zowe_runtimeDirectory}/bin/utils" \
          ExportPrivateKeyZos \
          "${keystore_file}" \
          PKCS12 \
          "${password}" \
          "${alias}" \
          "${password}" \
          "${keystore_dir}/${alias_lc}.key"
        if [ $? -ne 0 ]; then
          return 1
        fi

        # it's already EBCDIC, remove tag if there are any
        ensure_file_encoding "${keystore_dir}/${alias_lc}.key" "PRIVATE"
      else
        java -cp "${ZWE_zowe_runtimeDirectory}/bin/utils" \
          ExportPrivateKeyLinux \
          "${keystore_file}" \
          PKCS12 \
          "${password}" \
          "${alias}" \
          "${password}" \
          "${keystore_dir}/${alias_lc}.key"
        if [ $? -ne 0 ]; then
          return 1
        fi
      fi
    fi
  done <<EOF
$(echo "${private_key_aliases}" | tr "," "\n")
EOF
}

pkcs12_show_info() {
  keystore_file="${1}"
  alias="${2}"
  password="${3}"

  print_debug ">>>> Show certificate information of ${alias}:"
  result=$(pkeytool -list -v \
            -alias "${alias}" \
            -keystore "${keystore_file}" \
            -storepass "${password}" \
            -storetype "PKCS12")
  if [ $? -ne 0 ]; then
    return 1
  fi

  echo "${result}"
}

pkcs12_delete_cert() {
  keystore_file="${1}"
  password="${2}"
  alias="${3}"

  print_message ">>>> Delete ${alias} from keystore \"${keystore_file}\":"

  result=$(pkeytool -delete -v \
            -storetype "PKCS12" \
            -keystore "${keystore_file}" \
            -storepass "${password}" \
            -alias "${alias}")
  if [ $? -ne 0 ]; then
    return 1
  fi
}

compare_domain_with_wildcards() {
  pattern=$(echo "$1" | lower_case)
  domain=$(echo "$2" | lower_case)
  
  if [ "${pattern}" = "${domain}" ] || [[ ${domain} == ${pattern} ]]; then
    echo "true"
  fi
}

validate_certificate_domain() {
  host="${1}"
  port="${2}"
  host=$(echo "${host}" | lower_case)

  print_message ">>>> Validate certificate of ${host}:${port}"

  # get first certificate, ignore CAs
  cert=$(pkeytool -printcert -sslserver "${host}:${port}" | sed '/Certificate #1/q')
  if [ -z "${cert}" ]; then
    print_error "Error: failed to load certificate of ${host}:${port} to validate"
    return 1
  fi

  owner=$(echo "${cert}" | grep -i "Owner:" | awk -F":" '{print $2;}')
  common_name=
  old_IFS="${IFS}"
  IFS=,
  for prop in $owner; do
    key=$(echo "${prop}" | sed 's/^ *//g' | awk -F"=" '{print $1;}')
    val=$(echo "${prop}" | sed 's/^ *//g' | awk -F"=" '{print $2;}')
    if [ "${key}" = "CN" ]; then
      common_name="${val}"
    fi
  done
  IFS="${old_IFS}"

  if [ -z "${common_name}" ]; then
    print_error "Error: failed to find common name of the certificate"
    return 2
  fi
  print_debug "${host} certificate has common name ${common_name}"

  if [ "$(compare_domain_with_wildcards "${common_name}" "${host}")" != "true" ]; then
    print_debug "${host} doesn't match certificate common name, check subject alternate name(s)"
    san=$(echo "${cert}" | sed -e '1,/2.5.29.17/d' | sed '/ObjectId/q')
    dnsnames=$(echo "${san}" | grep -i DNSName | tr , '\n' | tr -d '[]' | awk -F":" '{print $2;}' | sed 's/^ *//g' | sed 's/ *$//g')
    if [ -n "${dnsnames}" ]; then
      print_debug "certificate has these subject alternate name(s):"
      print_debug "${dnsnames}"
      match=
      for dnsname in ${dnsnames} ; do
        if [ "$(compare_domain_with_wildcards "${dnsname}" "${host}")" = "true" ]; then
          match=true
        fi
      done
      if [ "${match}" != "true" ]; then
        print_error "Error: ${host} doesn't match any of the certificate common name and subject alternate name(s)"
        return 4
      fi
    else
      print_error "Error: ${host} certificate doesn't have subject alternate name(s)"
      return 3
    fi
  fi
  print_message "certificate of ${host}:${port} has valid common name and/or subject alternate name(s)"
  return 0
}

keyring_run_zwekring_jcl() {
  prefix="${1}"
  jcllib="${2}"
  # should be 1, 2 or 3
  jcloption="${3}"
  keyring_owner="${4}"
  keyring_name="${5}"
  domains="${6}"
  alias="${7}"
  ca_alias="${8}"
  # external CA labels separated by comma (label can have spaces)
  ext_cas="${9}"
  # set to 1 or true to import z/OSMF CA
  trust_zosmf=0
  if [ "${10}" = "true" -o "${10}" = "1" ]; then
    trust_zosmf=1
  fi
  zosmf_root_ca="${11}"
  # option 2 - connect existing
  connect_user="${12}"
  connect_label="${13}"
  # option 3 - import from data set
  import_ds_name="${14}"
  import_ds_password="${15}"
  validity="${16:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_VALIDITY}}"
  security_product=${17:-RACF}

  # generate from domains list
  domain_name=
  ip_address=
  for item in $(echo "${domains}" | lower_case | tr "," " "); do
    if [ -n "${item}" ]; then
      # test if it's IP
      if expr "${item}" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
        if [ -z "${ip_address}" ]; then
          ip_address="${item}"
        fi
      else
        if [ -z "${domain_name}" ]; then
          domain_name="${item}"
        fi
      fi
    fi
  done

  import_ext_ca=0
  import_ext_intermediate_ca_label=
  import_ext_root_ca_label=
  while read -r item; do
    item=$(echo "${item}" | trim)
    if [ -n "${item}" ]; then
      if [ -z "${import_ext_intermediate_ca_label}" ]; then
        import_ext_intermediate_ca_label="${item}"
        import_ext_ca=1
      elif [ -z "${import_ext_root_ca_label}" ]; then
        import_ext_root_ca_label="${item}"
        import_ext_ca=1
      fi
    fi
  done <<EOF
$(echo "${ext_cas}" | tr "," "\n")
EOF

  if [ "${trust_zosmf}" = "1" ]; then
    if [ "${zosmf_root_ca}" = "_auto_" ]; then
      zosmf_root_ca=$(detect_zosmf_root_ca "${ZWE_PRIVATE_ZOSMF_USER}")
    fi
    if [ -z "${zosmf_root_ca}" ]; then
      print_error_and_exit "Error ZWEL0137E: z/OSMF root certificate authority is not provided (or cannot be detected) with trusting z/OSMF option enabled." "" 137
    fi
  fi

  date_add_util="${ZWE_zowe_runtimeDirectory}/bin/utils/date-add.rex"
  validity_ymd=$("${date_add_util}" ${validity} 1234-56-78)
  validity_mdy=$("${date_add_util}" ${validity} 56/78/34)

  # option 2 needs further changes on JCL
  racf_connect1="s/dummy/dummy/"
  racf_connect2="s/dummy/dummy/"
  acf2_connect="s/dummy/dummy/"
  tss_connect="s/dummy/dummy/"
  if [ "${jcloption}" =  "2" ]; then
    if [ "${connect_user}" = "SITE" ]; then
      racf_connect1="s/^ \+RACDCERT CONNECT[(]SITE | ID[(]userid[)].*\$/   RACDCERT CONNECT(SITE +/"
      acf2_connect="s/^ \+CONNECT CERTDATA[(]SITECERT\.digicert | userid\.digicert[)].*\$/   CONNECT CERTDATA(SITECERT.${connect_label}) -/"
      tss_connect="s/^ \+RINGDATA[(]CERTSITE|userid,digicert[)].*\$/       RINGDATA(CERTSITE,${connect_label}) +/"
    elif [ -n "${connect_user}" ]; then
      racf_connect1="s/^ \+RACDCERT CONNECT[(]SITE | ID[(]userid[)].*\$/   RACDCERT CONNECT(ID(${connect_user}) +/"
      acf2_connect="s/^ \+CONNECT CERTDATA[(]SITECERT\.digicert | userid\.digicert[)].*\$/   CONNECT CERTDATA(${connect_user}.${connect_label}) -/"
      tss_connect="s/^ \+RINGDATA[(]CERTSITE|userid,digicert[)].*\$/       RINGDATA(${connect_user},${connect_label}) +/"
    fi
    racf_connect2="s/^ \+LABEL[(]'certlabel'[)].*\$/            LABEL('${connect_label}') +/"
  fi

  # used by ACF2  
  stc_group=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.stc")
  if [ -z "${stc_group}" ]; then
    stc_group=${ZWE_PRIVATE_DEFAULT_ADMIN_GROUP}
  fi

  ###############################
  # prepare ZWEKRING JCL
  print_message ">>>> Modify ZWEKRING"
  print_debug "- Create temp file"
  tmpfile=$(create_tmp_file $(echo "zwe ${ZWE_CLI_COMMANDS_LIST}" | sed "s# #-#g"))
  print_debug "  > temp file: ${tmpfile}"
  print_debug "- Create temp data set member"
  tmpdsm=$(create_data_set_tmp_member "${jcllib}" "ZW$(date +%H%M)")
  print_debug "  > data set member: ${jcllib}(tmpdsm)"
  print_debug "- Copy ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWEKRING) to ${tmpfile}"
  result=$(cat "//'${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWEKRING)'" | \
          sed  "s/^\/\/ \+SET \+PRODUCT=.*\$/\/\/         SET  PRODUCT=${security_product}/" | \
          sed "s/^\/\/ \+SET \+ZOWEUSER=.*\$/\/\/         SET  ZOWEUSER=${keyring_owner:-${ZWE_PRIVATE_DEFAULT_ZOWE_USER}}/" | \
          sed "s/^\/\/ \+SET \+ZOWERING=.*\$/\/\/         SET  ZOWERING='${keyring_name}'/" | \
          sed   "s/^\/\/ \+SET \+OPTION=.*\$/\/\/         SET  OPTION=${jcloption}/" | \
          sed    "s/^\/\/ \+SET \+LABEL=.*\$/\/\/         SET  LABEL='${alias}'/" | \
          sed  "s/^\/\/ \+SET \+LOCALCA=.*\$/\/\/         SET  LOCALCA='${ca_alias}'/" | \
          sed       "s/^\/\/ \+SET \+CN=.*\$/\/\/         SET  CN='${ZWE_PRIVATE_CERTIFICATE_COMMON_NAME:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_COMMON_NAME}}'/" | \
          sed       "s/^\/\/ \+SET \+OU=.*\$/\/\/         SET  OU='${ZWE_PRIVATE_CERTIFICATE_ORG_UNIT:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG_UNIT}}'/" | \
          sed        "s/^\/\/ \+SET \+O=.*\$/\/\/         SET  O='${ZWE_PRIVATE_CERTIFICATE_ORG:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG}}'/" | \
          sed        "s/^\/\/ \+SET \+L=.*\$/\/\/         SET  L='${ZWE_PRIVATE_CERTIFICATE_LOCALITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_LOCALITY}}'/" | \
          sed       "s/^\/\/ \+SET \+SP=.*\$/\/\/         SET  SP='${ZWE_PRIVATE_CERTIFICATE_STATE:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_STATE}}'/" | \
          sed        "s/^\/\/ \+SET \+C=.*\$/\/\/         SET  C='${ZWE_PRIVATE_CERTIFICATE_COUNTRY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_COUNTRY}}'/" | \
          sed "s/^\/\/ \+SET \+HOSTNAME=.*\$/\/\/         SET  HOSTNAME='${domain_name}'/" | \
          sed "s/^\/\/ \+SET \+IPADDRES=.*\$/\/\/         SET  IPADDRES='${ip_address}'/" | \
          sed   "s/^\/\/ \+SET \+DSNAME=.*\$/\/\/         SET  DSNAME=${import_ds_name}/" | \
          sed "s/^\/\/ \+SET \+PKCSPASS=.*\$/\/\/         SET  PKCSPASS='${import_ds_password}'/" | \
          sed "s/^\/\/ \+SET \+IFZOWECA=.*\$/\/\/         SET  IFZOWECA=${import_ext_ca}/" | \
          sed "s/^\/\/ \+SET \+ITRMZWCA=.*\$/\/\/         SET  ITRMZWCA='${import_ext_intermediate_ca_label}'/" | \
          sed "s/^\/\/ \+SET \+ROOTZWCA=.*\$/\/\/         SET  ROOTZWCA='${import_ext_root_ca_label}'/" | \
          sed "s/^\/\/ \+SET \+IFROZFCA=.*\$/\/\/         SET  IFROZFCA=${trust_zosmf}/" | \
          sed "s/^\/\/ \+SET \+ROOTZFCA=.*\$/\/\/         SET  ROOTZFCA='${zosmf_root_ca}'/" | \
          sed   "s/^\/\/ \+SET \+STCGRP=.*\$/\/\/         SET  STCGRP=${stc_group}/" | \
          sed "${racf_connect1}" | \
          sed "${racf_connect2}" | \
          sed "${acf2_connect}" | \
          sed "${tss_connect}" | \
          sed  "s/2030-05-01/${validity_ymd}/g" | \
          sed  "s#05/01/30#${validity_mdy}#g" \
          > "${tmpfile}")
  code=$?
  chmod 700 "${tmpfile}"
  if [ ${code} -eq 0 ]; then
    print_debug "  * Succeeded"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    if [ -n "${result}" ]; then
      print_trace "$(padding_left "${result}" "    ")"
    fi
  else
    print_debug "  * Failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi
  fi
  if [ ! -f "${tmpfile}" ]; then
    print_error "Error ZWEL0159E: Failed to modify ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWEKRING)"
    return 159
  fi
  print_trace "- Ensure ${tmpfile} encoding before copying into data set"
  ensure_file_encoding "${tmpfile}" "SPDX-License-Identifier"
  print_trace "- ${tmpfile} created, copy to ${jcllib}(${tmpdsm})"
  copy_to_data_set "${tmpfile}" "${jcllib}(${tmpdsm})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
  code=$?
  print_trace "- Delete ${tmpfile}"
  rm -f "${tmpfile}"
  if [ ${code} -ne 0 ]; then
    print_error "Error ZWEL0160E: Failed to write to ${jcllib}(${tmpdsm}). Please check if target data set is opened by others."
    return 160
  fi
  print_message "    - ${jcllib}(${tmpdsm}) is prepared"
  print_message

  ###############################
  # submit job
  if [ "${ZWE_CLI_PARAMETER_SECURITY_DRY_RUN}" = "true" ]; then
    print_message "Dry-run mode, JCL will NOT be submitted on the system."
    print_message "Please submit ${jcllib}(${tmpdsm}) manually."
  else
    print_message ">>>> Submit ${jcllib}(${tmpdsm})"
    jobid=$(submit_job "//'${jcllib}(${tmpdsm})'")
    code=$?
    if [ ${code} -ne 0 ]; then
      print_error "Error ZWEL0161E: Failed to run JCL ${jcllib}(${tmpdsm})."
      return 161
    fi
    print_debug "- job id ${jobid}"
    jobstate=$(wait_for_job "${jobid}")
    code=$?
    if [ ${code} -eq 1 ]; then
      print_error "Error ZWEL0162E: Failed to find job ${jobid} result."
      return 162
    fi
    jobname=$(echo "${jobstate}" | awk -F, '{print $2}')
    jobcctext=$(echo "${jobstate}" | awk -F, '{print $3}')
    jobcccode=$(echo "${jobstate}" | awk -F, '{print $4}')
    if [ ${code} -eq 0 ]; then
      print_message "    - Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})."

      print_message ""
      print_message "WARNING: Due to the limitation of the ZWEKRING job, exit with 0 does not mean"
      print_message "         the job is fully successful. Please check the job log to determine"
      print_message "         if there are any inline errors."
      print_message ""
    else
      print_error "Error ZWEL0163E: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})."
      return 163
    fi
  fi
}

keyring_run_zwenokyr_jcl() {
  prefix="${1}"
  jcllib="${2}"
  keyring_owner="${3}"
  keyring_name="${4}"
  alias="${5}"
  ca_alias="${6}"
  security_product=${7:-RACF}

  # used by ACF2
  stc_group=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.stc")
  if [ -z "${stc_group}" ]; then
    stc_group=${ZWE_PRIVATE_DEFAULT_ADMIN_GROUP}
  fi

  ###############################
  # prepare ZWENOKYR JCL
  print_message ">>>> Modify ZWENOKYR"
  print_debug "- Create temp file"
  tmpfile=$(create_tmp_file $(echo "zwe ${ZWE_CLI_COMMANDS_LIST}" | sed "s# #-#g"))
  print_debug "  > temp file: ${tmpfile}"
  print_debug "- Create temp data set member"
  tmpdsm=$(create_data_set_tmp_member "${jcllib}" "ZW$(date +%H%M)")
  print_debug "  > data set member: ${jcllib}(tmpdsm)"
  print_debug "- Copy ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWENOKYR) to ${tmpfile}"
  result=$(cat "//'${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWENOKYR)'" | \
          sed  "s/^\/\/ \+SET \+PRODUCT=.*\$/\/\/         SET  PRODUCT=${security_product}/" | \
          sed "s/^\/\/ \+SET \+ZOWEUSER=.*\$/\/\/         SET  ZOWEUSER=${keyring_owner:-${ZWE_PRIVATE_DEFAULT_ZOWE_USER}}/" | \
          sed "s/^\/\/ \+SET \+ZOWERING=.*\$/\/\/         SET  ZOWERING='${keyring_name}'/" | \
          sed    "s/^\/\/ \+SET \+LABEL=.*\$/\/\/         SET  LABEL='${alias}'/" | \
          sed  "s/^\/\/ \+SET \+LOCALCA=.*\$/\/\/         SET  LOCALCA='${ca_alias}'/" | \
          sed   "s/^\/\/ \+SET \+STCGRP=.*\$/\/\/         SET  STCGRP=${stc_group}/" \
          > "${tmpfile}")
  code=$?
  chmod 700 "${tmpfile}"
  if [ ${code} -eq 0 ]; then
    print_debug "  * Succeeded"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    if [ -n "${result}" ]; then
      print_trace "$(padding_left "${result}" "    ")"
    fi
  else
    print_debug "  * Failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi
  fi
  if [ ! -f "${tmpfile}" ]; then
    print_error "Error ZWEL0159E: Failed to modify ${prefix}.${ZWE_PRIVATE_DS_SZWESAMP}(ZWENOKYR)"
    return 159
  fi
  print_trace "- Ensure ${tmpfile} encoding before copying into data set"
  ensure_file_encoding "${tmpfile}" "SPDX-License-Identifier"
  print_trace "- ${tmpfile} created, copy to ${jcllib}(${tmpdsm})"
  copy_to_data_set "${tmpfile}" "${jcllib}(${tmpdsm})" "" "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}"
  code=$?
  print_trace "- Delete ${tmpfile}"
  rm -f "${tmpfile}"
  if [ ${code} -ne 0 ]; then
    print_error "Error ZWEL0160E: Failed to write to ${jcllib}(${tmpdsm}). Please check if target data set is opened by others."
    return 160
  fi
  print_message "    - ${jcllib}(${tmpdsm}) is prepared"
  print_message

  ###############################
  # submit job
  if [ "${ZWE_CLI_PARAMETER_SECURITY_DRY_RUN}" = "true" ]; then
    print_message "Dry-run mode, JCL will NOT be submitted on the system."
    print_message "Please submit ${jcllib}(${tmpdsm}) manually."
  else
    print_message ">>>> Submit ${jcllib}(${tmpdsm})"
    jobid=$(submit_job "//'${jcllib}(${tmpdsm})'")
    code=$?
    if [ ${code} -ne 0 ]; then
      print_error "Error ZWEL0161E: Failed to run JCL ${jcllib}(${tmpdsm})."
      return 161
    fi
    print_debug "- job id ${jobid}"
    jobstate=$(wait_for_job "${jobid}")
    code=$?
    if [ ${code} -eq 1 ]; then
      print_error "Error ZWEL0162E: Failed to find job ${jobid} result."
      return 162
    fi
    jobname=$(echo "${jobstate}" | awk -F, '{print $2}')
    jobcctext=$(echo "${jobstate}" | awk -F, '{print $3}')
    jobcccode=$(echo "${jobstate}" | awk -F, '{print $4}')
    if [ ${code} -eq 0 ]; then
      print_message "    - Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})."
    else
      print_error "Error ZWEL0163E: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})."
      return 163
    fi
  fi
}

# FIXME: this only works for RACF
keyring_show_info() {
  keyring_owner="${1}"
  keyring_name="${2}"

  print_debug ">>>> Show certificate information of safkeyring:////${keyring_owner}/${keyring_name}:"
  result=$(tso_command "RACDCERT LIST(LABEL('${keyring_name}')) ID(${keyring_owner})")
  if [ $? -ne 0 ]; then
    return 1
  fi

  echo "${result}"
}

keyring_show_info_node() {
  keyring_owner="${1}"
  keyring_name="${2}"
  # usage of the certificate: PERSONAL or CERTAUTH
  usage="${3}"
  label="${4}"
  output="${5}"

  opts=
  if [ -n "${label}" ]; then
    opts="${opts} -l \"${label}\""
  fi
  if [ -n "${usage}" ]; then
    opts="${opts} -u \"${usage}\""
  fi
  if [ "${output}" = "label" ]; then
    opts="${opts} --label-only"
  elif [ "${output}" = "owner" ]; then
    opts="${opts} --owner-only"
  fi
  
  print_debug ">>>> Show certificate information of safkeyring:////${keyring_owner}/${keyring_name}&${label}"
  result=$(ncert_utility keyring info "${keyring_owner}" "${keyring_name}" ${opts})
  if [ $? -ne 0 ]; then
    return 1
  fi
  echo "${result}"
}

keyring_export_to_pkcs12() {
  keyring_owner="${1}"
  keyring_name="${2}"
  label="${3}"
  uss_temp_dir="${4}"
  keystore_file="${5}"
  keystore_password="${6}"
  cert_only="${7}"

  dummy_cert=keyring-export-to-pkcs12-dummy
  dummy_cert_created=
  uss_temp_target=$(create_tmp_file "keyring-export-to-pkcs12" "${uss_temp_dir}")

  # remove temp files if they exists
  rm -f "${uss_temp_target}.cer"
  rm -f "${uss_temp_target}.key"
  rm -f "${uss_temp_target}.p12"

  print_debug ">>>> Export certificate \"${label}\" from safkeyring:////${keyring_owner}/${keyring_name} to PKCS#12 keystore ${keystore_file}"

 flags=$(get_java_pkcs12_keystore_flag)

  # create keystore if it doesn't exist
  if [ -f "${keystore_file}" ]; then
    print_debug "- Create keystore with dummy certificate ${dummy_cert}"
    result=$(pkeytool ${flags} \
            -genkeypair \
            -alias "${dummy_cert}" \
            -dname "CN=Zowe Dummy Cert, OU=ZWELS, O=Zowe, C=US" \
            -keystore "${keystore_file}" \
            -storetype PKCS12 \
            -storepass "${keystore_password}" \
            -validity 90 \
            -keyalg RSA -keysize 2048)
    if [ $? -ne 0 ]; then
      return 1
    fi

    pkcs12_ensure_binary_tag "${keystore_file}"
    if [ $? -ne 0 ]; then
      return 1
    fi

    dummy_cert_created=true
  fi

  # QUESTION: do we need to know cert owner?
  cert_owner=$(keyring_show_info_node "${keyring_owner}" "${keyring_name}" "PERSONAL" "${cert}" "owner")
  if [ $? -ne 0 ]; then
    return 1
  fi

  print_debug "- Export certificate \"${label}\" in PEM format"
  result=$(ncert_utility keyring export "${keyring_owner}" "${keyring_name}" "${label}" -f "${uss_temp_target}.cer")
  if [ $? -ne 0 ]; then
    return 1
  fi
  chmod 700 "${uss_temp_target}.cer"

  if [ "${cert_only}" = "true" ]; then
    # use keytool to import certificate
    print_debug "- Import certificate into keystore as \"${label}\""
    result=$(pkeytool ${flags} \
            -import -v \
            -trustcacerts -noprompt \
            -alias "${label}" \
            -file "${uss_temp_target}.cer" \
            -keystore "${keystore_file}" \
            -storetype PKCS12 \
            -keypass "${keystore_password}" \
            -storepass "${keystore_password}")
    if [ $? -ne 0 ]; then
      return 1
    fi
  else
    # keytool cannot import PEM private key, use ncert utility

    # export private key
    print_debug "- Export private key of \"${label}\" in PEM format"
    result=$(ncert_utility keyring export "${keyring_owner}" "${keyring_name}" "${label}" -k -f "${uss_temp_target}.key")
    if [ $? -ne 0 ]; then
      return 1
    fi
    chmod 700 "${uss_temp_target}.key"

    # convert PEM format into temporary PKCS#12 keystore
    print_debug "- Generate PKCS#12 keystore from the certificate and private key in PEM format"
    result=$(ncert_utility pkcs12 create-from-pem "${label}" -f "${uss_temp_target}.p12" -p "${keystore_password}" --cert "${uss_temp_target}.cer" --key "${uss_temp_target}.key")
    if [ $? -ne 0 ]; then
      return 1
    fi
    chmod 700 "${uss_temp_target}.p12"

    pkcs12_ensure_binary_tag "${uss_temp_target}.p12"
    if [ $? -ne 0 ]; then
      return 1
    fi

    # import into target keystore
    pkcs12_import_pkcs12_keystore \
      "${keystore_file}" \
      "${keystore_password}" \
      "${label}" \
      "${uss_temp_target}.p12" \
      "${keystore_password}" \
      "${label}"
    if [ $? -ne 0 ]; then
      return 1
    fi
  fi

  if [ "${dummy_cert_created}" = "true" ]; then
    print_debug "- Delete dummy certificate ${dummy_cert} from keystore"
    result=$(pkeytool -delete \
            -alias "${dummy_cert}" \
            -keystore "${keystore_file}" \
            -storetype PKCS12 \
            -storepass "${keystore_password}")
  fi

  print_debug
}

keyring_export_all_to_pkcs12() {
  keyring_owner="${1}"
  keyring_name="${2}"
  uss_temp_dir="${3}"
  keystore_name="${4:-localhost}"
  keystore_password="${5}"

  mkdir -p "${uss_temp_dir}/keystore/${keystore_name}"
  temp_keystore_file="${uss_temp_dir}/keystore/${keystore_name}/${keystore_name}.keystore.p12"
  temp_truststore_file="${uss_temp_dir}/keystore/${keystore_name}/${keystore_name}.truststore.p12"
  labels_with_private_key=

  # converting keystore
  print_debug ">>>> Listing PERSONAL certificates"
  certs=$(keyring_show_info_node "${keyring_owner}" "${keyring_name}" "PERSONAL" "" "label")
  print_debug "- Found these certificates: ${certs}"
  print_debug
  while read -r cert; do
    if [ -n "${cert}" ]; then
      keyring_export_to_pkcs12 \
         "${keyring_owner}" \
         "${keyring_name}" \
         "${cert}" \
         "${uss_temp_dir}" \
         "${temp_keystore_file}" \
         "${keystore_password}"
      if [ $? -ne 0 ]; then
        return 1
      fi
      if [ -z "${labels_with_private_key}" ]; then
        labels_with_private_key="${labels_with_private_key},"
      fi
      labels_with_private_key="${labels_with_private_key}${cert}"
    fi
  done <<EOF
$(echo "${certs}")
EOF

  pkcs12_ensure_binary_tag "${temp_keystore_file}"
  if [ $? -ne 0 ]; then
    return 1
  fi
  pkcs12_ensure_binary_tag "${temp_truststore_file}"
  if [ $? -ne 0 ]; then
    return 1
  fi

  # converting truststore
  print_debug ">>>> Listing CERTAUTH certificates"
  certs=$(keyring_show_info_node "${keyring_owner}" "${keyring_name}" "CERTAUTH" "" "label")
  print_debug "- Found these certificates: ${certs}"
  print_debug
  while read -r cert; do
    if [ -n "${cert}" ]; then
      found=$(item_in_list "${ZWE_zowe_certificate_pem_certificateAuthorities}" "safkeyring:////${keyring_owner}/${keyring_name}&${cert}")
      if [ "${found}" = "true" ]; then
        # RDATALIB cannot export private key of CERTAUTH certificate, so only the cert itself, no private key
        keyring_export_to_pkcs12 \
          "${keyring_owner}" \
          "${keyring_name}" \
          "${cert}" \
          "${uss_temp_dir}" \
          "${temp_truststore_file}" \
          "${keystore_password}" \
          "true"
        if [ $? -ne 0 ]; then
          return 1
        fi

        # also put it into keystore to create full chain
        keyring_export_to_pkcs12 \
          "${keyring_owner}" \
          "${keyring_name}" \
          "${cert}" \
          "${uss_temp_dir}" \
          "${temp_keystore_file}" \
          "${keystore_password}" \
          "true"
        if [ $? -ne 0 ]; then
          return 1
        fi
      else
        # Not Zowe CA, we only export cert without private key
        keyring_export_to_pkcs12 \
          "${keyring_owner}" \
          "${keyring_name}" \
          "${cert}" \
          "${uss_temp_dir}" \
          "${temp_truststore_file}" \
          "${keystore_password}" \
          "true"
        if [ $? -ne 0 ]; then
          return 1
        fi
      fi
    fi
  done <<EOF
$(echo "${certs}")
EOF

  # export keystore to PEM format
  pkcs12_export_pem \
    "${temp_keystore_file}" \
    "${keystore_password}" \
    "${labels_with_private_key}"
}

# this only works for RACF
detect_zosmf_root_ca() {
  zosmf_user=${1:-IZUSVR}
  zosmf_root_ca=

  print_trace "- Detect z/OSMF keyring by listing ID(${zosmf_user})"
  zosmf_certs=$(tsocmd "RACDCERT LIST ID(${zosmf_user})" 2>&1)
  code=$?
  if [ ${code} -ne 0 ]; then
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    if [ -n "${zosmf_certs}" ]; then
      print_trace "$(padding_left "${zosmf_certs}" "    ")"
    fi
    return 1
  fi

  zosmf_keyring_name=$(echo "${zosmf_certs}" | grep -v RACDCERT | awk "/Ring:/{x=NR+10;next}(NR<=x){print}" | awk '{print $1}' | sed -e 's/^>//' -e 's/<$//' | tr -d '\n')
  if [ -n "${zosmf_keyring_name}" ]; then
    print_trace "  * z/OSMF keyring name is ${zosmf_keyring_name}"
    print_trace "- Detect z/OSMF root certificate authority by listing keyring (${zosmf_keyring_name})"
    zosmf_keyring=$(tsocmd "RACDCERT LISTRING(${zosmf_keyring_name}) ID(${zosmf_user})" 2>&1)
    code=$?
    if [ ${code} -ne 0 ]; then
      print_trace "  * Exit code: ${code}"
      print_trace "  * Output:"
      if [ -n "${zosmf_keyring}" ]; then
        print_trace "$(padding_left "${zosmf_keyring}" "    ")"
      fi
      return 2
    fi

    zosmf_root_ca=$(echo "${zosmf_keyring}" | grep -v RACDCERT | grep 'CERTAUTH' | head -n 1 | awk '{print $1}' | tr -d '\n')
    if [ -z "${zosmf_root_ca}" ]; then
      print_trace "  * Error: cannot detect z/OSMF root certificate authority"
      return 3
    else
      print_trace "  * z/OSMF root certificate authority found: ${zosmf_root_ca}"
      echo "${zosmf_root_ca}"
      return 0
    fi
  else
    print_trace "  * Error: failed to detect z/OSMF keyring name"
    return 4
  fi
}

is_certificate_generated_by_zowe() {
  issuer_keyword="${1:-Zowe Development Instances}"

  if [ "${ZWE_zowe_certificate_keystore_type}" = "PKCS12" ]; then
    issuer=$(pkcs12_show_info "${ZWE_zowe_certificate_keystore_file}" "${ZWE_zowe_certificate_keystore_alias}" "${ZWE_zowe_certificate_keystore_password}" | grep "Issuer:")
    if [ -z "${issuer}" ]; then
      # FIXME: error code
      print_error_and_exit "Error: cannot find issuer of certificate ${ZWE_zowe_certificate_keystore_alias} in ${ZWE_zowe_certificate_keystore_file}." "" 1
    fi
    found=$(echo "${issuer}" | grep "${issuer_keyword}")
    if [ -n "${found}" ]; then
      echo "true"
    fi
  elif [[ "${KEYSTORE_TYPE}" == JCE*KS ]]; then
    issuer=$(keyring_show_info "${ZWE_zowe_certificate_keystore_file}" "${ZWE_zowe_certificate_keystore_alias}" | sed -n '/Issuer/{n;p;}')
    if [ -z "${issuer}" ]; then
      # FIXME: error code
      print_error_and_exit "Error: cannot find issuer of certificate ${ZWE_zowe_certificate_keystore_alias} with owner ${ZWE_zowe_certificate_keystore_file}." "" 1
    fi
    found=$(echo "${issuer}" | grep "${issuer_keyword}")
    if [ -n "${found}" ]; then
      echo "true"
    fi
  fi
}
