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

pkcs12_create_certificate_authority() {
  keystore_dir=$1
  alias=$2
  password=$3
  common_name=${4:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_COMMON_NAME}}

  print_message ">>>> Generate PKCS12 format local CA with alias ${alias}:"
  mkdir -p "${keystore_dir}/${alias}"
  pkeytool -genkeypair -v \
    -alias "${alias}" \
    -keyalg RSA -keysize 2048 \
    -dname "CN=${common_name}, OU=${ZWE_PRIVATE_CERTIFICATE_CA_ORG_UNIT:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_ORG_UNIT}}, O=${ZWE_PRIVATE_CERTIFICATE_CA_ORG:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_ORG}}, L=${ZWE_PRIVATE_CERTIFICATE_CA_LOCALITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_LOCALITY}}, S=${ZWE_PRIVATE_CERTIFICATE_CA_STATE:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_STATE}}, C=${ZWE_PRIVATE_CERTIFICATE_CA_COUNTRY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_COUNTRY}}" \
    -keystore "${keystore_dir}/${alias}/${alias}.keystore.p12" \
    -keypass "${password}" \
    -storepass "${password}" \
    -storetype "PKCS12" \
    -validity "${ZWE_PRIVATE_CERTIFICATE_CA_VALIDITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_CA_VALIDITY}}" \
    -ext KeyUsage="keyCertSign" \
    -ext BasicConstraints:"critical=ca:true"
  if [ $? -ne 0 ]; then
    return 1
  fi
 
  chmod 600 "${keystore_dir}/${alias}/${alias}.keystore.p12"

  print_message ">>>> Export local CA with alias ${alias}:"
  pkeytool -export -v \
    -alias "${alias}" \
    -keystore "${keystore_dir}/${alias}/${alias}.keystore.p12" \
    -keypass "${password}" \
    -storepass "${password}" \
    -storetype "PKCS12" \
    -rfc \
    -file "${keystore_dir}/${alias}/${alias}.cer"
  if [ $? -ne 0 ]; then
    return 1
  fi

  if [ "${ZWE_RUN_ON_ZOS}" = "true" ]; then
    iconv -f ISO8859-1 -t IBM-1047 "${keystore_dir}/${alias}/${alias}.cer" > "${keystore_dir}/${alias}/${alias}.cer-ebcdic"
  fi
}

pkcs12_create_certificate_and_sign() {
  keystore_dir=$1
  keystore_name=$2
  alias=$3
  password=$4
  common_name=${5:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_COMMON_NAME}}
  domains=${6}
  ca_alias=${7}
  ca_password=${8}

  print_message ">>>> Generate certificate \"${alias}\" in the keystore ${keystore_name}:"
  mkdir -p "${keystore_dir}/${keystore_name}"
  pkeytool -genkeypair -v \
    -alias "${alias}" \
    -keyalg RSA -keysize 2048 \
    -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
    -keypass "${password}" \
    -storepass "${password}" \
    -storetype "PKCS12" \
    -dname "CN=${common_name}, OU=${ZWE_PRIVATE_CERTIFICATE_ORG_UNIT:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG_UNIT}}, O=${ZWE_PRIVATE_CERTIFICATE_ORG:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG}}, L=${ZWE_PRIVATE_CERTIFICATE_LOCALITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_LOCALITY}}, S=${ZWE_PRIVATE_CERTIFICATE_STATE:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_STATE}}, C=${ZWE_PRIVATE_CERTIFICATE_COUNTRY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_COUNTRY}}" \
    -validity "${ZWE_PRIVATE_CERTIFICATE_VALIDITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_VALIDITY}}"
  if [ $? -ne 0 ]; then
    return 1
  fi

  print_message ">>>> Generate CSR for the certificate \"${alias}\" in the keystore \"${keystore_name}\":"
  pkeytool -certreq -v \
    -alias "${alias}" \
    -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
    -storepass "${password}" \
    -file "${keystore_dir}/${keystore_name}/${alias}.csr" \
    -keyalg RSA \
    -storetype "PKCS12" \
    -dname "CN=${common_name}, OU=${ZWE_PRIVATE_CERTIFICATE_ORG_UNIT:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG_UNIT}}, O=${ZWE_PRIVATE_CERTIFICATE_ORG:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_ORG}}, L=${ZWE_PRIVATE_CERTIFICATE_LOCALITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_LOCALITY}}, S=${ZWE_PRIVATE_CERTIFICATE_STATE:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_STATE}}, C=${ZWE_PRIVATE_CERTIFICATE_COUNTRY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_COUNTRY}}" \
    -validity "${ZWE_PRIVATE_CERTIFICATE_VALIDITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_VALIDITY}}"
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
  pkeytool -gencert -v \
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
    -validity "${ZWE_PRIVATE_CERTIFICATE_VALIDITY:-${ZWE_PRIVATE_DEFAULT_CERTIFICATE_VALIDITY}}"
  if [ $? -ne 0 ]; then
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
    pkeytool -importcert -v \
      -trustcacerts -noprompt \
      -file "${keystore_dir}/${ca_alias}/${ca_alias}.cer" \
      -alias "${ca_alias}" \
      -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
      -storepass "${password}" \
      -storetype "PKCS12"
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
    pkeytool -importcert -v \
      -trustcacerts -noprompt \
      -file "${keystore_dir}/${ca_alias}/${ca_alias}.cer" \
      -alias "${ca_alias}" \
      -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.truststore.p12" \
      -storepass "${password}" \
      -storetype "PKCS12"
  fi

  print_message ">>>> Import the signed CSR to the keystore \"${keystore_name}\":"
  pkeytool -importcert -v \
    -trustcacerts -noprompt \
    -file "${keystore_dir}/${keystore_name}/${alias}.signed.cer" \
    -alias "${alias}" \
    -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
    -storepass "${password}" \
    -storetype "PKCS12"
  if [ $? -ne 0 ]; then
    return 1
  fi

  # delete CSR
  rm -f "${keystore_dir}/${keystore_name}/${alias}.csr"
  rm -f "${keystore_dir}/${keystore_name}/${alias}.signed.cer"

  print_message ">>>> Export certificate \"${alias}\" to the PEM format"
  pkeytool -exportcert -v \
    -alias "${alias}" \
    -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
    -storepass "${password}" \
    -storetype "PKCS12" \
    -rfc \
    -file "${keystore_dir}/${keystore_name}/${alias}.cer"
  if [ $? -ne 0 ]; then
    return 1
  fi
  if [ `uname` = "OS/390" ]; then
    iconv -f ISO8859-1 -t IBM-1047 "${keystore_dir}/${keystore_name}/${alias}.cer" > "${keystore_dir}/${keystore_name}/${alias}.cer-ebcdic"
  fi

  print_message ">>>> Exporting certificate \"${alias}\" private key"
  if [ "${ZWE_RUN_ON_ZOS}" = "true" ]; then
    java -cp "${ZWE_zowe_runtimeDirectory}/bin/utils" \
      ExportPrivateKeyZos \
      "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
      PKCS12 \
      "${password}" \
      "${alias}" \
      "${password}" \
      "${keystore_dir}/${keystore_name}/${alias}.key"
    if [ $? -ne 0 ]; then
      return 1
    fi

    iconv -f ISO8859-1 -t IBM-1047 "${keystore_dir}/${keystore_name}/${alias}.key" > "${keystore_dir}/${keystore_name}/${alias}.key-ebcdic"
  else
    java -cp "${ZWE_zowe_runtimeDirectory}/bin/utils" \
      ExportPrivateKeyLinux \
      "${keystore_dir}/${keystore_name}/${keystore_name}.keystore.p12" \
      PKCS12 \
      "${password}" \
      "${alias}" \
      "${password}" \
      "${keystore_dir}/${keystore_name}/${alias}.key"
    if [ $? -ne 0 ]; then
      return 1
    fi
  fi
}

pkcs12_trust_service() {
  keystore_dir=$1
  keystore_name=$2
  # password of truststore (<keystore_dir>/<keystore_name>.truststore.p12)
  password=$3
  service_host=$4
  service_port=$5
  service_alias=${6}

  if [ ! -f "${keystore_dir}/${keystore_name}/${keystore_name}.truststore.p12" ]; then
    print_error "Truststore ${keystore_name}.truststore.p12 doesn't exist."
    return 1
  fi

  print_message ">>>> Getting certificates from service host"
  print_cert_cmd="-printcert -sslserver ${service_host}:${service_port} -J-Dfile.encoding=UTF8"

  if [ "${ZWE_PRIVATE_LOG_LEVEL_CLI}" = "DEBUG" -o "${ZWE_PRIVATE_LOG_LEVEL_CLI}" = "TRACE" ]; then
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
  if [ ${code} -ne 0 ]; then
    print_error "Failed to get certificate of service instance https://${service_host}:${service_port}, exit code ${code}."
    return 1
  fi

  # parse keytool output into separate files
  csplit -s -k -f "${keystore_dir}/${keystore_name}/${service_alias}" "${tmp_file}" /-----END\ CERTIFICATE-----/1 \
    {$(expr `grep -c -e '-----END CERTIFICATE-----' "${tmp_file}"` - 1)}
  for cert in "${keystore_dir}/${keystore_name}/${service_alias}"*; do
    [ -s "${cert}" ] || continue
    cert_file=$(basename "${cert}")
    cert_alias=${cert_file%.cer}
    echo ">>>> Import a certificate \"${cert_alias}\" to the truststore:"
    pkeytool -importcert -v \
      -trustcacerts \
      -noprompt \
      -file "${cert}" \
      -alias "${cert_alias}" \
      -keystore "${keystore_dir}/${keystore_name}/${keystore_name}.truststore.p12" \
      -storepass "${password}" \
      -storetype PKCS12
    if [ $? -ne 0 ]; then
      return 1
    fi
  done

  # clean up temporary files
  rm -f "${tmp_file}"
  rm -f "${keystore_dir}/${keystore_name}/${service_alias}"*
}

compare_domain_with_wildcards() {
  pattern=$(echo "$1" | lower_case)
  domain=$(echo "$2" | lower_case)
  
  if [ "${pattern}" = "${domain}" ] || [[ ${domain} == ${pattern} ]]; then
    echo "true"
  fi
}

validate_certificate_domain() {
  host=$1
  port=$2
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
