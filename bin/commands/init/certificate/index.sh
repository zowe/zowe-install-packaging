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

# read HLQ and validate
hlq=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.hlq")
if [ -z "${hlq}" -o "${hlq}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe high level qualifier (zowe.setup.mvs.hlq) is not defined in Zowe YAML configuration file." "" 157
fi
# read JCL library and validate
jcllib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.mvs.jcllib")
if [ -z "${jcllib}" -o "${jcllib}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe custom JCL library (zowe.setup.mvs.jcllib) is not defined in Zowe YAML configuration file." "" 157
fi
security_product=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.product")
if [ -z "${security_product}" -o "${security_product}" = "null" ]; then
  security_product=RACF
fi
security_users_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.zowe")
if [ -z "${security_users_zowe}" -o "${security_users_zowe}" = "null" ]; then
  security_users_zowe=${ZWE_PRIVATE_DEFAULT_ZOWE_USER}
fi
security_groups_admin=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.admin")
if [ -z "${security_groups_admin}" -o "${security_groups_admin}" = "null" ]; then
  security_groups_admin=${ZWE_PRIVATE_DEFAULT_ADMIN_GROUP}
fi
# read cert type and validate
cert_type=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.type")
if [ -z "${cert_type}" -o "${cert_type}" = "null" ]; then
  print_error_and_exit "Error ZWEL0157E: Certificate type (zowe.setup.certificate.type) is not defined in Zowe YAML configuration file." "" 157
fi
if [ "${cert_type}" != "PKCS12" -a "${cert_type}" != "JCERACFKS" ]; then
  print_error_and_exit "Error ZWEL0164E: Value of certificate type (zowe.setup.certificate.type) defined in Zowe YAML configuration file is invalid. Valid values are PKCS12 or JCERACFKS." "" 164
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
if [ "${cert_type}" = "PKCS12" ]; then
  # read keystore info
  for item in directory name password caAlias caPassword importFrom; do
    var_name="pkcs12_${item}"
    var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.pkcs12.${item}")
    if [ "${var_val}" = "null" ]; then
      var_val=
    fi
    eval "${var_name}=\"${var_val}\""
  done
  if [ -z "${pkcs12_directory}" ]; then
    print_error_and_exit "Error ZWEL0157E: Keystore directory (zowe.setup.certificate.pkcs12.directory) is not defined in Zowe YAML configuration file." "" 157
  fi
  # TODO: implement pkcs12_importFrom
elif [ "${cert_type}" = "JCERACFKS" ]; then
  keyring_option=1
  # read keyring info
  for item in owner name label caLabel; do
    var_name="keyring_${item}"
    var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.${item}")
    if [ "${var_val}" = "null" ]; then
      var_val=
    fi
    eval "${var_name}=\"${var_val}\""
  done
  if [ -z "${keyring_name}" ]; then
    print_error_and_exit "Error ZWEL0157E: Zowe keyring name (zowe.setup.certificate.keyring.name) is not defined in Zowe YAML configuration file." "" 157
  fi
  keyring_import_dsName=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.import.dsName")
  if [ "${keyring_import_dsName}" = "null" ]; then
    keyring_import_dsName=
  fi
  keyring_import_password=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.import.password")
  if [ "${keyring_import_password}" = "null" ]; then
    keyring_import_password=
  fi
  if [ -n "${keyring_import_dsName}" ]; then
    keyring_option=3
    if [ -z "${keyring_import_password}" ]; then
      print_error_and_exit "Error ZWEL0157E: The password for data set storing importing certificate (zowe.setup.certificate.keyring.import.password) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi
  keyring_connect_user=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.connect.user")
  if [ "${keyring_connect_user}" = "null" ]; then
    keyring_connect_user=
  fi
  keyring_connect_label=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.connect.label")
  if [ "${keyring_connect_label}" = "null" ]; then
    keyring_connect_label=
  fi
  if [ -n "${keyring_connect_label}" ]; then
    keyring_option=2
  fi
fi
# read keystore domains
cert_import_CAs=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.importCertificateAuthorities" | tr '\n' ',')
if [ "${cert_import_CAs}" = "null" -o "${cert_import_CAs}" = "null," ]; then
  cert_import_CAs=
fi
# read keystore domains
cert_domains=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.san" | tr '\n' ',')
if [ -z "${cert_domains}" -o "${cert_domains}" = "null" -o "${cert_domains}" = "null," ]; then
  cert_domains=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.externalDomains" | tr '\n' ',')
fi
if [ "${cert_domains}" = "null" -o "${cert_domains}" = "null," ]; then
  cert_domains=
fi
# read z/OSMF info
for item in user ca; do
  var_name="zosmf_${item}"
  var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.zOSMF.${item}")
  if [ "${var_val}" = "null" ]; then
    var_val=
  fi
  eval "${var_name}=\"${var_val}\""
done
for item in host port; do
  var_name="zosmf_${item}"
  var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zOSMF.${item}")
  if [ "${var_val}" = "null" ]; then
    var_val=
  fi
  eval "${var_name}=\"${var_val}\""
done
keyring_trust_zosmf=
verify_certificates=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.verifyCertificates" | upper_case)
if [ "${verify_certificates}" = "STRICT" -o "${verify_certificates}" = "NONSTRICT" ]; then
  keyring_trust_zosmf="--trust-zosmf"
else
  # no need to trust z/OSMF service
  zosmf_host=
  zosmf_port=
fi

# set default values
if [ "${cert_type}" = "PKCS12" ]; then
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
elif [ "${cert_type}" = "JCERACFKS" ]; then
  if [ -z "${keyring_owner}" ]; then
    keyring_owner=${security_users_zowe}
  fi
  if [ -z "${keyring_label}" ]; then
    keyring_label=localhost
  fi
  if [ -z "${keyring_caLabel}" ]; then
    keyring_caLabel=localca
  fi
  if [ -z "${zosmf_ca}" -a "${security_product}" = "RACF" -a -n "${zosmf_host}" ]; then
    zosmf_ca="_auto_"
  fi
fi

if [ "${cert_type}" = "PKCS12" ]; then
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
      --keystore-dir "${pkcs12_directory}" \
      --keystore "${pkcs12_name}" \
      --password "${pkcs12_password}" \
      --host "${zosmf_host}" \
      --port "${zosmf_port}" \
      --alias "zosmf"
  fi

  # lock keystore directory with proper permission
  # - group permission is none
  zwecli_inline_execute_command \
    certificate pkcs12 lock \
      --keystore-dir "${pkcs12_directory}" \
      --user "${security_users_zowe}" \
      --group "${security_groups_admin}" \
      --group-permission none
elif [ "${cert_type}" = "JCERACFKS" ]; then
  case ${keyring_option} in
    1)
      # generate new cert in keyring
      zwecli_inline_execute_command \
        certificate keyring-jcl generate \
        --hlq "${hlq}" \
        --jcllib "${jcllib}" \
        --keyring-owner "${keyring_owner}" \
        --keyring-name "${keyring_name}" \
        --alias "${keyring_label}" \
        --ca-alias "${keyring_caLabel}" \
        --trust-cas "${cert_import_CAs}" \
        --common-name "${dname_commonName}" \
        --org-unit "${dname_orgUnit}" \
        --org "${dname_org}" \
        --locality "${dname_locality}" \
        --state "${dname_state}" \
        --country "${dname_country}" \
        --validity "${cert_validity}" \
        --security-product "${security_product}" \
        --domains "${cert_domains}" \
        "${keyring_trust_zosmf}" \
        --zosmf-ca "${zosmf_ca}" \
        --zosmf-user "${zosmf_user}"
      ;;
    2)
      # connect existing certs to zowe keyring
      zwecli_inline_execute_command \
        certificate keyring-jcl connect \
        --hlq "${hlq}" \
        --jcllib "${jcllib}" \
        --keyring-owner "${keyring_owner}" \
        --keyring-name "${keyring_name}" \
        --trust-cas "${cert_import_CAs}" \
        --connect-user "${keyring_connect_user}" \
        --connect-label "${keyring_connect_label}" \
        --security-product "${security_product}" \
        "${keyring_trust_zosmf}" \
        --zosmf-ca "${zosmf_ca}" \
        --zosmf-user "${zosmf_user}"
      ;;
    3)
      # import certs from data set into zowe keyring
      zwecli_inline_execute_command \
        certificate keyring-jcl import-ds \
        --hlq "${hlq}" \
        --jcllib "${jcllib}" \
        --keyring-owner "${keyring_owner}" \
        --keyring-name "${keyring_name}" \
        --alias "${keyring_label}" \
        --trust-cas "${cert_import_CAs}" \
        --import-ds-name "${keyring_import_dsName}" \
        --import-ds-password "${keyring_import_password}" \
        --security-product "${security_product}" \
        "${keyring_trust_zosmf}" \
        --zosmf-ca "${zosmf_ca}" \
        --zosmf-user "${zosmf_user}"
      ;;
  esac
fi

if [ -n "${zosmf_host}" -a "${verify_certificates}" = "STRICT" ]; then
  # CN/SAN must be valid if z/OSMF is used and in strict mode
  zwecli_inline_execute_command \
    certificate verify-service \
    --host "${zosmf_host}" \
    --port "${zosmf_port}"
fi
