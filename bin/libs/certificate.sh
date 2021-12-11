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
