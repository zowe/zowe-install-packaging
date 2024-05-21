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

if [ -z "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}" ]; then
  # user-facing command, use tmpdir to not mess up workspace permissions
  export ZWE_PRIVATE_TMP_MERGED_YAML_DIR=$(create_tmp_file)
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF),HEAPPOOLS64(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/internal/config/output/cli.js"
  # use the yaml configmgr returns because it will contain defaults for the version we are using.
  ZWE_CLI_PARAMETER_CONFIG=${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}/.zowe-merged.yaml
fi


###############################
# read prefix and validate
prefix=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.prefix")
if [ -z "${prefix}" ]; then
  print_error_and_exit "Error ZWEL0157E: Zowe dataset prefix (zowe.setup.dataset.prefix) is not defined in Zowe YAML configuration file." "" 157
fi

jcllib=$(verify_generated_jcl)
if [ "$?" -eq 1 ]; then
  print_error_and_exit "Error ZWEL0999E: zowe.setup.dataset.jcllib does not exist, cannot run. Run 'zwe init', 'zwe init generate', or submit JCL ${prefix}.SZWESAMP(ZWEGENER) before running this command." "" 999
fi

# read cert type and validate
cert_type=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.type")
if [ -z "${cert_type}" ]; then
  print_error_and_exit "Error ZWEL0157E: Certificate type (zowe.setup.certificate.type) is not defined in Zowe YAML configuration file." "" 157
fi

[[ "$cert_type" == "PKCS12" || "$cert_type" == JCE*KS ]]
if [ $? -ne 0 ]; then
  print_error_and_exit "Error ZWEL0164E: Value of certificate type (zowe.setup.certificate.type) defined in Zowe YAML configuration file is invalid. Valid values are PKCS12, JCEKS, JCECCAKS, JCERACFKS, JCECCARACFKS, or JCEHYBRIDRACFKS." "" 164
fi

if [ "${cert_type}" = "PKCS12" ]; then
  # read keystore info
  for item in directory lock name password; do
    var_name="pkcs12_${item}"
    var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.pkcs12.${item}")
    eval "${var_name}=\"${var_val}\""
  done
  if [ -z "${pkcs12_directory}" ]; then
    print_error_and_exit "Error ZWEL0157E: Keystore directory (zowe.setup.certificate.pkcs12.directory) is not defined in Zowe YAML configuration file." "" 157
  fi
  # read keystore import info
  pkcs12_import_keystore=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.pkcs12.import.keystore")

else # JCE* content
  security_product=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.product")

  keyring_option=1
  # read keyring info
  # TODO removed "owner" here because it wasnt being read in the JCL.
  for item in name label caLabel; do
    var_name="keyring_${item}"
    var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.${item}")
    eval "${var_name}=\"${var_val}\""
  done
  # FIXME: currently ZWEKRING jcl will import the cert and chain, CA will also be added to CERTAUTH, but the CA will not be connected to keyring.
  #        the CA imported could have label like LABEL00000001.
  yaml_keyring_label="${keyring_label}"
  if [ -z "${keyring_name}" ]; then
    print_error_and_exit "Error ZWEL0157E: Zowe keyring name (zowe.setup.certificate.keyring.name) is not defined in Zowe YAML configuration file." "" 157
  fi

  keyring_import_dsName=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.import.dsName")
  if [ -n "${keyring_import_dsName}" ]; then
    keyring_option=3
    keyring_import_password=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.import.password")
    if [ -z "${keyring_import_password}" ]; then
      print_error_and_exit "Error ZWEL0157E: The password for data set storing importing certificate (zowe.setup.certificate.keyring.import.password) is not defined in Zowe YAML configuration file." "" 157
    fi
  else
    keyring_connect_label=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.connect.label")
    if [ -n "${keyring_connect_label}" ]; then
      keyring_option=2
      keyring_connect_user=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.connect.user")
      if [ -z "${keyring_connect_user}" ]; then
        print_error_and_exit "Error ZWEL0157E: (zowe.setup.certificate.keyring.connect.user) is not defined in Zowe YAML configuration file." "" 157
      fi
      yaml_keyring_label="${keyring_connect_label}"
    fi
  fi

  if [ "${keyring_option}" -eq 1 ]; then
    # validate parameters only needed for creation of certificate
    for item in caCommonName commonName orgUnit org locality state country; do
      var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.dname.${item}")
      if [ -z "${var_val}" ]; then
        print_error_and_exit "Error ZWEL0157E: Certificate creation parameter (zowe.setup.certificate.dname.${item}) is not defined in Zowe YAML configuration file." "" 157
      fi
    done
    # read cert validity
    cert_validity=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.validity")
    if [ -z "${cert_validity}" ]; then
      print_error_and_exit "Error ZWEL0157E: Certificate creation parameter (zowe.setup.certificate.validity) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi

  # read keyring-specific z/OSMF info
  for item in user ca; do
    var_name="zosmf_${item}"
    var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.keyring.zOSMF.${item}")
    eval "${var_name}=\"${var_val}\""
  done
fi

# read keystore domains
cert_import_CAs=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.importCertificateAuthorities" | tr '\n' ',')
# read keystore domains
cert_domains=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.san" | tr '\n' ',')
if [ -z "${cert_domains}" ]; then
  cert_domains=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.externalDomains" | tr '\n' ',')
fi

for item in host port; do
  var_name="zosmf_${item}"
  var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zOSMF.${item}")
  eval "${var_name}=\"${var_val}\""
done
keyring_trust_zosmf=0
verify_certificates=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.verifyCertificates" | upper_case)
if [ "${verify_certificates}" = "STRICT" -o "${verify_certificates}" = "NONSTRICT" ]; then
  keyring_trust_zosmf=1
else
  # no need to trust z/OSMF service
  zosmf_host=
  zosmf_port=
fi


###############################
# set default values or quit on missing ones

if [ "${cert_type}" = "PKCS12" ]; then
  if [ -z "${pkcs12_name}" ]; then
    print_error_and_exit "Error ZWEL0157E: (zowe.setup.certificate.pkcs12.name) is not defined in Zowe YAML configuration file." "" 157
  fi
  if [ -z "${pkcs12_password}" ]; then
    print_error_and_exit "Error ZWEL0157E: (zowe.setup.certificate.pkcs12.password) is not defined in Zowe YAML configuration file." "" 157
  fi

 
  if [ "$(lower_case "${pkcs12_lock}")" = "true" ]; then
    security_users_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.zowe")
    security_groups_admin=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.admin")
    if [ -z "${security_users_zowe}" ]; then
      security_users_zowe=${ZWE_PRIVATE_DEFAULT_ZOWE_USER}
    fi
    if [ -z "${security_groups_admin}" ]; then
      security_groups_admin=${ZWE_PRIVATE_DEFAULT_ADMIN_GROUP}
    fi
  fi
else # JCE* content
  if [ -z "${security_product}" ]; then
    print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.product) is not defined in Zowe YAML configuration file." "" 157
  fi
  security_users_zowe=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.zowe")
  if [ -z "${security_users_zowe}" ]; then
    print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.users.zowe) is not defined in Zowe YAML configuration file." "" 157
  fi
  # TODO this seems to not actually be used... was this an unusual user request? is it even possible to be a different owner?
  if [ -z "${keyring_owner}" ]; then
    keyring_owner=${security_users_zowe}
  fi

  if [ "${keyring_option}" = "1" ]; then
    if [ -z "${keyring_caLabel}" ]; then
      print_error_and_exit "Error ZWEL0157E: (zowe.setup.certificate.keyring.caLabel) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi
  if [ "${keyring_option}" != "2" ]; then
    if [ -z "${keyring_label}" ]; then
      print_error_and_exit "Error ZWEL0157E: (zowe.setup.certificate.keyring.label) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi
  if [ "${security_product}" = "ACF2" ]; then
    security_groups_stc=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.groups.stc")
    if [ -z "${security_groups_stc}" ]; then
      print_error_and_exit "Error ZWEL0157E: (zowe.setup.security.groups.stc) is not defined in Zowe YAML configuration file." "" 157
    fi
  fi    

  if [ -z "${zosmf_ca}" -a "${security_product}" = "RACF" -a -n "${zosmf_host}" ]; then
    zosmf_ca="_auto_"
  fi
fi

###############################
if [ "${cert_type}" = "PKCS12" ]; then
  # what PEM format CAs we should tell Zowe to use
  yaml_pem_cas=

  if [ -n "${pkcs12_import_keystore}" ]; then
    pkcs12_import_password=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.pkcs12.import.password")
    if [ -z "${pkcs12_import_password}" ]; then
      print_error_and_exit "Error ZWEL0157E: Password for import keystore (zowe.setup.certificate.pkcs12.import.password) is not defined in Zowe YAML configuration file." "" 157
    fi
    pkcs12_import_alias=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.pkcs12.import.alias")
    if [ -z "${pkcs12_import_alias}" ]; then
      print_error_and_exit "Error ZWEL0157E: Certificate alias of import keystore (zowe.setup.certificate.pkcs12.import.alias) is not defined in Zowe YAML configuration file." "" 157
    fi
        
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
    # cert to be created, read creation parameters.
    for item in caCommonName commonName orgUnit org locality state country; do
      var_name="dname_${item}"
      var_val=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.dname.${item}")
      eval "${var_name}=\"${var_val}\""
    done
    # read cert validity
    cert_validity=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.validity")

    pkcs12_caPassword=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.pkcs12.caPassword")
    pkcs12_caAlias=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.certificate.pkcs12.caAlias")
    pkcs12_caAlias_lc=$(echo "${pkcs12_caAlias}" | lower_case)

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
      --common-name "${dname_commonName}" \
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

  pkcs12_name_lc=$(echo "${pkcs12_name}" | lower_case)

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
else # JCE* content
  # FIXME: how do we check if keyring exists without permission on RDATALIB?
  # should we clean up before creating new
  if [ "${ZWE_CLI_PARAMETER_ALLOW_OVERWRITE}" = "true" ]; then
    # warning
    print_message "Warning ZWEL0300W: Keyring \"safkeyring:///${keyring_owner}/${keyring_name}\" will be overwritten during configuration."

    keyring_run_zwenokyr_jcl "${prefix}" "${jcllib}" "${security_product}"
  else
    # error
    # print_error_and_exit "Error ZWEL0158E: Keyring \"safkeyring:///${keyring_owner}/${keyring_name}\" already exists." "" 158
  fi

  keyring_run_zwekring_jcl "${prefix}" \
                           "${jcllib}" \
                           "${keyring_option}" \
                           "${cert_domains}" \
                           "${cert_import_CAs}" \
                           "${keyring_trust_zosmf}" \
                           "${zosmf_ca}" \
                           "${cert_validity}" \
                           "${security_product}"
  
  if [ $? -ne 0 ]; then
    job_has_failures=true
    if [ "${ZWE_CLI_PARAMETER_IGNORE_SECURITY_FAILURES}" = "true" ]; then
      print_error "Error ZWEL0174E: Failed to generate certificate in Zowe keyring \"${ZWE_CLI_PARAMETER_KEYRING_OWNER}/${ZWE_CLI_PARAMETER_KEYRING_NAME}\"."
    else
      print_error_and_exit "Error ZWEL0174E: Failed to generate certificate in Zowe keyring \"${ZWE_CLI_PARAMETER_KEYRING_OWNER}/${ZWE_CLI_PARAMETER_KEYRING_NAME}\"." "" 174
    fi
  fi

  if [ "${job_has_failures}" = "true" ]; then
    print_level2_message "Failed to generate certificate to Zowe keyring. Please check job log for details."
  else
    print_level2_message "Certificate is generated in keyring successfully."
  fi

  # update zowe.yaml
  if [ "${ZWE_CLI_PARAMETER_UPDATE_CONFIG}" = "true" ]; then
    print_level1_message "Update certificate configuration to ${ZWE_CLI_PARAMETER_CONFIG}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.type" "${cert_type}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.file" "safkeyring:////${keyring_owner}/${keyring_name}"
    # we must set a dummy value here, other JDK will complain wrong parameter
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.password" "password"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.keystore.alias" "${yaml_keyring_label}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.type" "${cert_type}"
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.file" "safkeyring:////${keyring_owner}/${keyring_name}"
    # we must set a dummy value here, other JDK will complain wrong parameter
    update_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}" "zowe.certificate.truststore.password" "password"
    print_level2_message "Zowe configuration is updated successfully."
  else
    print_level1_message "Update certificate configuration to ${ZWE_CLI_PARAMETER_CONFIG}"
    print_message "Please manually update to these values:"
    print_message ""
    print_message "zowe:"
    print_message "  certificate:"
    print_message "    keystore:"
    print_message "      type: ${cert_type}"
    print_message "      file: \"safkeyring:////${keyring_owner}/${keyring_name}\""
    print_message "      password: \"password\""
    print_message "      alias: \"${yaml_keyring_label}\""
    print_message "    truststore:"
    print_message "      type: ${cert_type}"
    print_message "      file: \"safkeyring:////${keyring_owner}/${keyring_name}\""
    print_message "      password: \"password\""
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

# cleanup temp file made at top.
if [ -n "$ZWE_PRIVATE_TMP_MERGED_YAML_DIR" ]; then
  rm "${ZWE_PRIVATE_TMP_MERGED_YAML_DIR}/.zowe-merged.yaml"
fi
