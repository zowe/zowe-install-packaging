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

print_level1_message "Create certificate"

###############################
# validation
require_zowe_yaml

# read cert type and validate
cert_type=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.type")
if [ -z "${cert_type}" -o "${cert_type}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Certificate type must be PKCS12 or JCERACFKS." "" 157
fi
for item in caCommonName commonName orgUnit org locality state country; do
  var_name="dname_${item}"
  var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.dname.${item}")
  if [ "${var_val}" = "null" ]; then
    var_val=
  fi
  eval "${var_name}=\"${var_val}\""
done
cert_validity=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.validity")
if [ "${cert_validity}" = "null" ]; then
  cert_validity=
fi
for item in directory name password caAlias caPassword; do
  var_name="pkcs12_${item}"
  var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.pkcs12.${item}")
  if [ "${var_val}" = "null" ]; then
    var_val=
  fi
  eval "${var_name}=\"${var_val}\""
done
if [ -z "${pkcs12_directory}" ]; then
  print_error_and_exit "Error ZWEL0157E: Keystore directory is not defined." "" 157
fi
cert_domains=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.san" | tr '\n' ',')
if [ -z "${cert_type}" -o "${cert_type}" = "null" ]; then
  cert_domains=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.externalDomains" | tr '\n' ',')
fi

if [ -z "${pkcs12_caAlias}" ]; then
  pkcs12_caAlias=local_ca
fi
if [ -z "${pkcs12_caPassword}" ]; then
  pkcs12_caPassword=local_ca_password
fi
if [ -z "${pkcs12_name}" ]; then
  pkcs12_name=localhost
fi
if [ -z "${pkcs12_password}" ]; then
  pkcs12_password=password
fi

# check existence
keystore="${pkcs12_directory}/${pkcs12_caAlias}/${pkcs12_caAlias}.keystore.p12"
if [ -f "${keystore}" ]; then
  if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
    # warning
    print_message "Warning ZWEL0158W: Keystore \"${keystore}\" already exists. This keystore will be overwritten during configuration."
    rm -fr "${pkcs12_directory}/${pkcs12_caAlias}"
  else
    # error
    print_error_and_exit "Error ZWEL0158E: Keystore \"${keystore}\" already exists." "" 158
  fi
fi
keystore="${pkcs12_directory}/${pkcs12_name}/${pkcs12_name}.keystore.p12"
if [ -f "${keystore}" ]; then
  if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITTEN}" = "true" ]; then
    # warning
    print_message "Warning ZWEL0158W: Keystore \"${keystore}\" already exists. This keystore will be overwritten during configuration."
    rm -fr "${pkcs12_directory}/${pkcs12_name}"
  else
    # error
    print_error_and_exit "Error ZWEL0158E: Keystore \"${keystore}\" already exists." "" 158
  fi
fi

print_message ">> Create certificate authority"
ZWE_PRIVATE_CERTIFICATE_CA_ORG_UNIT="${dname_orgUnit}" \
  ZWE_PRIVATE_CERTIFICATE_CA_ORG="${dname_org}" \
  ZWE_PRIVATE_CERTIFICATE_CA_LOCALITY="${dname_locality}" \
  ZWE_PRIVATE_CERTIFICATE_CA_STATE="${dname_state}" \
  ZWE_PRIVATE_CERTIFICATE_CA_COUNTRY="${dname_country}" \
  ZWE_PRIVATE_CERTIFICATE_CA_VALIDITY="${cert_validity}" \
  pkcs12_create_certificate_authority \
  "${pkcs12_directory}" \
  "${pkcs12_caAlias}" \
  "${pkcs12_caPassword}" \
  "${dname_caCommonName}"
print_message

print_message ">> Create default certificate"
ZWE_PRIVATE_CERTIFICATE_ORG_UNIT="${dname_orgUnit}" \
  ZWE_PRIVATE_CERTIFICATE_ORG="${dname_org}" \
  ZWE_PRIVATE_CERTIFICATE_LOCALITY="${dname_locality}" \
  ZWE_PRIVATE_CERTIFICATE_STATE="${dname_state}" \
  ZWE_PRIVATE_CERTIFICATE_COUNTRY="${dname_country}" \
  ZWE_PRIVATE_CERTIFICATE_VALIDITY="${cert_validity}" \
  pkcs12_create_certificate_and_sign \
  "${pkcs12_directory}" \
  "${pkcs12_name}" \
  "${pkcs12_name}" \
  "${pkcs12_password}" \
  "${dname_commonName}" \
  "${cert_domains}" \
  "${pkcs12_caAlias}" \
  "${pkcs12_caPassword}"

print_level2_message "Certificate is created successfully."
