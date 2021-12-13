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

###############################
# validation
require_zowe_yaml

# read cert type and validate
cert_type=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.type")
if [ -z "${cert_type}" -o "${cert_type}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Certificate type must be PKCS12 or JCERACFKS." "" 157
fi
# read cert dname
for item in caCommonName commonName orgUnit org locality state country; do
  var_name="dname_${item}"
  var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.dname.${item}")
  if [ "${var_val}" = "null" ]; then
    var_val=
  fi
  eval "${var_name}=\"${var_val}\""
done
# read cert validity
cert_validity=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.validity")
if [ "${cert_validity}" = "null" ]; then
  cert_validity=
fi
# read keystore info
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
# read keystore domains
cert_domains=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.san" | tr '\n' ',')
if [ -z "${cert_type}" -o "${cert_type}" = "null" ]; then
  cert_domains=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.externalDomains" | tr '\n' ',')
fi
# read z/OSMF info
zosmf_host=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zOSMF.host")
if [ "${zosmf_host}" = "null" ]; then
  zosmf_host=
fi
zosmf_port=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zOSMF.port")
if [ "${zosmf_port}" = "null" ]; then
  zosmf_port=
fi
zosmf_verify=
verify_certificates=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.verifyCertificates" | upper_case)
if [ "${verify_certificates}" = "STRICT" ]; then
  zosmf_verify="--verify"
fi

# set default values
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

# create CA
zwecli_inline_execute_command \
  certificate pkcs12 create ca \
  --keystore-dir "${pkcs12_directory}" \
  --alias "${pkcs12_caAlias}" \
  --password "${pkcs12_caPassword}" \
  --common-name "${dname_caCommonName}" \
  --org-unit "${dname_orgUnit}" \
  --org "${dname_org}" \
  --locality "${dname_locality}" \
  --state "${dname_state}" \
  --country "${dname_country}" \
  --validity "${cert_validity}"

# create default cert
zwecli_inline_execute_command \
  certificate pkcs12 create cert \
  --keystore-dir "${pkcs12_directory}" \
  --keystore "${pkcs12_name}" \
  --alias "${pkcs12_name}" \
  --password "${pkcs12_password}" \
  --common-name "${dname_caCommonName}" \
  --org-unit "${dname_orgUnit}" \
  --org "${dname_org}" \
  --locality "${dname_locality}" \
  --state "${dname_state}" \
  --country "${dname_country}" \
  --validity "${cert_validity}" \
  --ca-alias "${pkcs12_caAlias}" \
  --ca-password "${pkcs12_caPassword}" \
  --domains "${cert_domains}"

# trust z/OSMF
if [ -n "${zosmf_host}" -a -n "${zosmf_port}" ]; then
  zwecli_inline_execute_command \
    certificate pkcs12 trust-service \
    --service-name "z/OSMF" \
    ${zosmf_verify} \
    --keystore-dir "${pkcs12_directory}" \
    --keystore "${pkcs12_name}" \
    --password "${pkcs12_password}" \
    --host "${zosmf_host}" \
    --port "${zosmf_port}" \
    --alias "zosmf"
fi
