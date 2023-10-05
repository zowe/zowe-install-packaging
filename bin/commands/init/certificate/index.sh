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

USE_CONFIGMGR=$(check_configmgr_enabled)
if [ "${USE_CONFIGMGR}" = "true" ]; then
  if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then

    # user-facing command, use tmpdir to not mess up workspace permissions
    export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=1
  fi
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/init/certificate/cli.js"
else


###############################
# validation
require_zowe_yaml

###############################
# read prefix and validate
prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
if [ -z "${prefix}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
fi
# read JCL library and validate
jcllib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.jcllib")
if [ -z "${jcllib}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe custom JCL library (zowe.setup.dataset.jcllib) is not defined in Zowe YAML configuration file." "" 157
fi
security_product=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.product")
security_users_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.zowe")
security_groups_admin=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.admin")
# read cert type and validate
cert_type=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.type")
if [ -z "${cert_type}" ]; then
  print_error_and_exit "Error ZWEL0157E: Certificate type (zowe.setup.certificate.type) is not defined in Zowe YAML configuration file." "" 157
fi
[[ "$cert_type" == "PKCS12" || "$cert_type" == JCE*KS ]]
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWEL0164E: Value of certificate type (zowe.setup.certificate.type) defined in Zowe YAML configuration file is invalid. Valid values are PKCS12, JCEKS, JCECCAKS, JCERACFKS, JCECCARACFKS, or JCEHYBRIDRACFKS." "" 164
fi
# read cert dname
for item in caCommonName commonName orgUnit org locality state country; do
  var_name="dname_${item}"
  var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.dname.${item}")
  eval "${var_name}=\"${var_val}\""
done
# read cert validity
cert_validity=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.validity")
if [ "${cert_type}" = "PKCS12" ]; then
  # read keystore info
  for item in directory lock name password caAlias caPassword; do
    var_name="pkcs12_${item}"
    var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.pkcs12.${item}")
    eval "${var_name}=\"${var_val}\""
  done
  if [ -z "${pkcs12_directory}" ]; then
    print_error_and_exit "Error ZWEL0157E: Keystore directory (zowe.setup.certificate.pkcs12.directory) is not defined in Zowe YAML configuration file." "" 157
  fi
  # read keystore import info
  for item in keystore password alias; do
    var_name="pkcs12_import_${item}"
    var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.pkcs12.import.${item}")
    eval "${var_name}=\"${var_val}\""
  done
  if [ -n "${pkcs12_import_keystore}" ]; then
    if [ -z "${pkcs12_import_password}" ]; then
      print_error_and_exit "Error ZWEL0157E: Password for import keystore (zowe.setup.certificate.pkcs12.import.password) is not defined in Zowe YAML configuration file." "" 157
    fi
    if [ -z "${pkcs12_import_alias}" ]; then
      print_error_and_exit "Error ZWEL0157E: Certificate alias of import keystore (zowe.setup.certificate.pkcs12.import.alias) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi
elif [[ "${cert_type}" == JCE*KS ]]; then
  keyring_option=1
  # read keyring info
  for item in owner name label caLabel; do
    var_name="keyring_${item}"
    var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.${item}")
    eval "${var_name}=\"${var_val}\""
  done
  if [ -z "${keyring_name}" ]; then
    print_error_and_exit "Error ZWEL0157E: Zowe keyring name (zowe.setup.certificate.keyring.name) is not defined in Zowe YAML configuration file." "" 157
  fi
  keyring_import_dsName=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.import.dsName")
  keyring_import_password=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.import.password")
  if [ -n "${keyring_import_dsName}" ]; then
    keyring_option=3
    if [ -z "${keyring_import_password}" ]; then
      print_error_and_exit "Error ZWEL0157E: The password for data set storing importing certificate (zowe.setup.certificate.keyring.import.password) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi
  keyring_connect_user=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.connect.user")
  keyring_connect_label=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.connect.label")
  if [ -n "${keyring_connect_label}" ]; then
    keyring_option=2
  fi
fi
# read keystore domains
cert_import_CAs=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.importCertificateAuthorities" | tr '\n' ',')
# read keystore domains
cert_domains=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.san" | tr '\n' ',')
if [ -z "${cert_domains}" ]; then
  cert_domains=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.externalDomains" | tr '\n' ',')
fi

# read z/OSMF info
for item in user ca; do
  var_name="zosmf_${item}"
  var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.zOSMF.${item}")
  eval "${var_name}=\"${var_val}\""
done
for item in host port; do
  var_name="zosmf_${item}"
  var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zOSMF.${item}")
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


###############################
# set default values
if [ -z "${security_product}" ]; then
  security_product=RACF
fi
if [ -z "${security_users_zowe}" ]; then
  security_users_zowe=${ZWE_PRIVATE_DEFAULT_ZOWE_USER}
fi
if [ -z "${security_groups_admin}" ]; then
  security_groups_admin=${ZWE_PRIVATE_DEFAULT_ADMIN_GROUP}
fi
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
elif [[ "${cert_type}" == JCE*KS ]]; then
  if [ -z "${keyring_owner}" ]; then
    keyring_owner=${security_users_zowe}
  fi
  if [ -z "${keyring_label}" ]; then
    keyring_label=localhost
  fi
  if [ "${keyring_option}" = "1" ]; then
    if [ -z "${keyring_caLabel}" ]; then
      keyring_caLabel=localca
    fi
  else
    # for import case, this variable is not used
    keyring_caLabel=
  fi
  if [ -z "${zosmf_ca}" -a "${security_product}" = "RACF" -a -n "${zosmf_host}" ]; then
    zosmf_ca="_auto_"
  fi
fi
pkcs12_name_lc=$(echo "${pkcs12_name}" | lower_case)
pkcs12_caAlias_lc=$(echo "${pkcs12_caAlias}" | lower_case)
# what PEM format CAs we should tell Zowe to use
yaml_pem_cas=

###############################
if [ "${cert_type}" = "PKCS12" ]; then
  if [ -n "${pkcs12_import_keystore}" ]; then
    # import from another keystore
    zwecli_inline_execute_command \
      certificate pkcs12 import \
      --keystore "${pkcs12_directory}/${pkcs12_name}/${pkcs12_name}.keystore.p12" \
      --password "${pkcs12_password}" \
      --alias "${pkcs12_name}" \
      --source-keystore "${pkcs12_import_keystore}" \
      --source-password "${pkcs12_import_password}" \
      --source-alias "${pkcs12_import_alias}"
  else
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

    # export CA cert in PEM format
    zwecli_inline_execute_command \
      certificate pkcs12 export \
        --keystore "${pkcs12_directory}/${pkcs12_caAlias}/${pkcs12_caAlias}.keystore.p12" \
        --password "${pkcs12_caPassword}"

    yaml_pem_cas="${pkcs12_directory}/${pkcs12_caAlias}/${pkcs12_caAlias_lc}.cer"

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
  fi

  # import extra CAs if they are defined
  if [ -n "${cert_import_CAs}" ]; then
    # also imported to keystore to maintain full chain
    zwecli_inline_execute_command \
      certificate pkcs12 import \
      --keystore "${pkcs12_directory}/${pkcs12_name}/${pkcs12_name}.keystore.p12" \
      --password "${pkcs12_password}" \
      --alias "" \
      --source-keystore "" \
      --source-password "" \
      --source-alias "" \
      --trust-cas "${cert_import_CAs}"

    zwecli_inline_execute_command \
      certificate pkcs12 import \
      --keystore "${pkcs12_directory}/${pkcs12_name}/${pkcs12_name}.truststore.p12" \
      --password "${pkcs12_password}" \
      --alias "" \
      --source-keystore "" \
      --source-password "" \
      --source-alias "" \
      --trust-cas "${cert_import_CAs}"
  fi

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

  # export all certs in PEM format
  zwecli_inline_execute_command \
    certificate pkcs12 export \
      --keystore "${pkcs12_directory}/${pkcs12_name}/${pkcs12_name}.keystore.p12" \
      --password "${pkcs12_password}" \
      --private-keys "${pkcs12_name}"
  zwecli_inline_execute_command \
    certificate pkcs12 export \
      --keystore "${pkcs12_directory}/${pkcs12_name}/${pkcs12_name}.truststore.p12" \
      --password "${pkcs12_password}" \
      --private-keys ""

  # after we export truststore, the imported CAs will be exported as extca*.cer
  if [ -n "${cert_import_CAs}" ]; then
    imported_cas=$(find "${pkcs12_directory}/${pkcs12_name}" -name 'extca*.cer' -type f | tr '\n' ',')
    if [ -z "${yaml_pem_cas}" ]; then
      yaml_pem_cas="${imported_cas}"
    else
      yaml_pem_cas="${yaml_pem_cas},${imported_cas}"
    fi
  fi

  # lock keystore directory with proper permission
  # - group permission is none
  # NOTE: njq returns `null` or empty for boolean false, so let's check true
  if [ "$(lower_case "${pkcs12_lock}")" = "true" ]; then
    zwecli_inline_execute_command \
      certificate pkcs12 lock \
        --keystore-dir "${pkcs12_directory}" \
        --user "${security_users_zowe}" \
        --group "${security_groups_admin}" \
        --group-permission none
  fi

  # update zowe.yaml
  if [ "${ZWE_CLI_PARAMETER_UPDATE_CONFIG}" = "true" ]; then
    print_level1_message "Update certificate configuration to ${ZWE_CLI_PARAMETER_CONFIG}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.type" "PKCS12"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.file" "${pkcs12_directory}/${pkcs12_name}/${pkcs12_name}.keystore.p12"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.password" "${pkcs12_password}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.alias" "${pkcs12_name_lc}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.type" "PKCS12"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.file" "${pkcs12_directory}/${pkcs12_name}/${pkcs12_name}.truststore.p12"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.password" "${pkcs12_password}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.pem.key" "${pkcs12_directory}/${pkcs12_name}/${pkcs12_name_lc}.key"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.pem.certificate" "${pkcs12_directory}/${pkcs12_name}/${pkcs12_name_lc}.cer"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.pem.certificateAuthorities" "${yaml_pem_cas}"
    print_level2_message "Zowe configuration is updated successfully."
  else
    print_level1_message "Update certificate configuration to ${ZWE_CLI_PARAMETER_CONFIG}"
    print_message "Please manually update to these values:"
    print_message ""
    print_message "zowe:"
    print_message "  certificate:"
    print_message "    keystore:"
    print_message "      type: PKCS12"
    print_message "      file: \"${pkcs12_directory}/${pkcs12_name}/${pkcs12_name}.keystore.p12\""
    print_message "      password: \"${pkcs12_password}\""
    print_message "      alias: \"${pkcs12_name_lc}\""
    print_message "    truststore:"
    print_message "      type: PKCS12"
    print_message "      file: \"${pkcs12_directory}/${pkcs12_name}/${pkcs12_name}.truststore.p12\""
    print_message "      password: \"${pkcs12_password}\""
    print_message "    pem:"
    print_message "      key: \"${pkcs12_directory}/${pkcs12_name}/${pkcs12_name_lc}.key\""
    print_message "      certificate: \"${pkcs12_directory}/${pkcs12_name}/${pkcs12_name_lc}.cer\""
    print_message "      certificateAuthorities: \"${yaml_pem_cas}\""
    print_message ""
    print_level2_message "Zowe configuration requires manual updates."
  fi
###############################
elif [[ "${cert_type}" == JCE*KS ]]; then
  # FIXME: how do we check if keyring exists without permission on RDATALIB?
  # should we clean up before creating new
  if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
    # warning
    print_message "Warning ZWEL0300W: Keyring \"safkeyring:////${keyring_owner}/${keyring_name}\" will be overwritten during configuration."

    zwecli_inline_execute_command \
      certificate keyring-jcl clean \
      --dataset-prefix "${prefix}" \
      --jcllib "${jcllib}" \
      --keyring-owner "${keyring_owner}" \
      --keyring-name "${keyring_name}" \
      --alias "${keyring_label}" \
      --ca-alias "${keyring_caLabel}" \
      --security-product "${security_product}"
  else
    # error
    # print_error_and_exit "Error ZWEL0158E: Keyring \"safkeyring:////${keyring_owner}/${keyring_name}\" already exists." "" 158
  fi

  yaml_keyring_label=
  case ${keyring_option} in
    1)
      # generate new cert in keyring
      zwecli_inline_execute_command \
        certificate keyring-jcl generate \
        --dataset-prefix "${prefix}" \
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
      
      yaml_keyring_label="${keyring_label}"
      # keyring string for self-signed CA
      yaml_pem_cas="safkeyring:////${keyring_owner}/${keyring_name}&${keyring_caLabel}"
      ;;
    2)
      # connect existing certs to zowe keyring
      zwecli_inline_execute_command \
        certificate keyring-jcl connect \
        --dataset-prefix "${prefix}" \
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

      yaml_keyring_label="${keyring_connect_label}"
      ;;
    3)
      # import certs from data set into zowe keyring
      zwecli_inline_execute_command \
        certificate keyring-jcl import-ds \
        --dataset-prefix "${prefix}" \
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
      # FIXME: currently ZWEKRING jcl will import the cert and chain, CA will also be added to CERTAUTH, but the CA will not be connected to keyring.
      #        the CA imported could have label like LABEL00000001.

      yaml_keyring_label="${keyring_label}"
      ;;
  esac

  if [ -n "${cert_import_CAs}" ]; then
    # append imported CAs to list
    while read -r item; do
      item=$(echo "${item}" | trim)
      if [ -n "${item}" ]; then
        if [ -n "${yaml_pem_cas}" ]; then
          yaml_pem_cas="${yaml_pem_cas},safkeyring:////${keyring_owner}/${keyring_name}&${item}"
        else
          yaml_pem_cas="safkeyring:////${keyring_owner}/${keyring_name}&${item}"
        fi
      fi
    done <<EOF
$(echo "${cert_import_CAs}" | tr "," "\n")
EOF
  fi

  # update zowe.yaml
  if [ "${ZWE_CLI_PARAMETER_UPDATE_CONFIG}" = "true" ]; then
    print_level1_message "Update certificate configuration to ${ZWE_CLI_PARAMETER_CONFIG}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.type" "${cert_type:-JCERACFKS}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.file" "safkeyring:////${keyring_owner}/${keyring_name}"
    # we must set a dummy value here, other JDK will complain wrong parameter
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.password" "password"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.alias" "${yaml_keyring_label}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.type" "${cert_type:-JCERACFKS}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.file" "safkeyring:////${keyring_owner}/${keyring_name}"
    # we must set a dummy value here, other JDK will complain wrong parameter
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.password" "password"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.pem.key" ""
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.pem.certificate" ""
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.pem.certificateAuthorities" "${yaml_pem_cas}"
    print_level2_message "Zowe configuration is updated successfully."
  else
    print_level1_message "Update certificate configuration to ${ZWE_CLI_PARAMETER_CONFIG}"
    print_message "Please manually update to these values:"
    print_message ""
    print_message "zowe:"
    print_message "  certificate:"
    print_message "    keystore:"
    print_message "      type: ${cert_type:-JCERACFKS}"
    print_message "      file: \"safkeyring:////${keyring_owner}/${keyring_name}\""
    print_message "      password: \"password\""
    print_message "      alias: \"${yaml_keyring_label}\""
    print_message "    truststore:"
    print_message "      type: ${cert_type:-JCERACFKS}"
    print_message "      file: \"safkeyring:////${keyring_owner}/${keyring_name}\""
    print_message "      password: \"password\""
    print_message "    pem:"
    print_message "      key: \"\""
    print_message "      certificate: \"\""
    print_message "      certificateAuthorities: \"${yaml_pem_cas}\""
    print_message ""
    print_level2_message "Zowe configuration requires manual updates."
  fi
fi

###############################
if [ -n "${zosmf_host}" -a "${verify_certificates}" = "STRICT" ]; then
  # CN/SAN must be valid if z/OSMF is used and in strict mode
  zwecli_inline_execute_command \
    certificate verify-service \
    --host "${zosmf_host}" \
    --port "${zosmf_port}"
fi
fi
