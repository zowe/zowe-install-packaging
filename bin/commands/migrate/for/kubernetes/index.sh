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
# constants / variables
rnd=$(echo $RANDOM)
user_id=$(get_user_id | upper_case)
temp_dir="$(get_tmp_dir)/zowe-convert-for-k8s-$(echo ${rnd})"

###############################
# validation
require_java
require_node
require_zowe_yaml

###############################
# opening message
print_level0_message "Prepare Kubernetes manifests"

print_message "SECURITY WARNING: This script will generate information with sensitive certificate"
print_message "                  private keys. Please make sure the content will not be left on any"
print_message "                  devices after the process is done."
print_message "                  During the process, this command will generate temporary files under"
print_message "                    ${temp_dir}/."
print_message "                  Normally those files will be deleted automatically before the script"
print_message "                  exits. If the script exits with an error, please verify if any of"
print_message "                  those files are left on the system and they MUST be manually deleted"
print_message "                  for security purposes."
print_message

###############################
# prepare temp work directory
rm -fr "${temp_dir}"
mkdir -p "${temp_dir}"
# prepare env files based on zowe.yaml
ZWE_PRIVATE_WORKSPACE_ENV_DIR="${temp_dir}/.env"
mkdir -p "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}"
# convert to instance.env and source it to understand how zowe.yaml defines certificate
generate_instance_env_from_yaml_config convert-for-k8s
source_env "${ZWE_PRIVATE_WORKSPACE_ENV_DIR}/.instance-convert-for-k8s.env"
# prepare full SAN list for k8s
full_k8s_domain_list="${ZWE_CLI_PARAMETER_DOMAINS},localhost.localdomain,localhost,127.0.0.1,*.${ZWE_CLI_PARAMETER_K8S_NAMESPACE}.svc.${ZWE_CLI_PARAMETER_K8S_CLUSTER_NAME},*.${ZWE_CLI_PARAMETER_K8S_NAMESPACE}.pod.${ZWE_CLI_PARAMETER_K8S_CLUSTER_NAME},*.discovery-service.${ZWE_CLI_PARAMETER_K8S_NAMESPACE}.svc.${ZWE_CLI_PARAMETER_K8S_CLUSTER_NAME},*.gateway-service.${ZWE_CLI_PARAMETER_K8S_NAMESPACE}.svc.${ZWE_CLI_PARAMETER_K8S_CLUSTER_NAME}"
original_zss_host="${ZWE_zowe_externalDomains_0}"
original_zss_port="${ZWE_components_zss_port}"

# prepare target zowe.yaml for k8s
cp "${ZWE_CLI_PARAMETER_CONFIG}" "${temp_dir}/zowe.yaml"

if [[ "${ZWE_zowe_certificate_keystore_type}" == JCE*KS ]]; then
  # export keyring to PKCS#12 format
  print_level1_message "Convert Keyring to PKCS#12 keystore for Kubernetes"
  print_message "You are using z/OS Keyring. All certificates used by Zowe will be exported."
  keyring_owner=$(echo "${ZWE_zowe_certificate_keystore_file}" | awk -F/ '{print $5}')
  if [ -z "${keyring_owner}" ]; then
    print_error_and_exit "Error: Failed to find keyring owner from zowe.certificate.keystore.file. The keystore file must be in format of safkeyring:////<owner>/<name>."
  fi
  keyring_name=$(echo "${ZWE_zowe_certificate_keystore_file}" | awk -F/ '{print $6}')
  if [ -z "${keyring_name}" ]; then
    print_error_and_exit "Error: Failed to find keyring name from zowe.certificate.keystore.file. The keystore file must be in format of safkeyring:////<owner>/<name>."
  fi
  keyring_export_all_to_pkcs12 "${keyring_owner}" "${keyring_name}" "${temp_dir}" "${ZWE_CLI_PARAMETER_ALIAS}" "${ZWE_CLI_PARAMETER_PASSWORD}"
  ZWE_zowe_certificate_keystore_type=PKCS12
  ZWE_zowe_certificate_truststore_type=PKCS12
  ZWE_zowe_certificate_keystore_file="${temp_dir}/keystore/${ZWE_CLI_PARAMETER_ALIAS}/${ZWE_CLI_PARAMETER_ALIAS}.keystore.p12"
  ZWE_zowe_certificate_truststore_file="${temp_dir}/keystore/${ZWE_CLI_PARAMETER_ALIAS}/${ZWE_CLI_PARAMETER_ALIAS}.truststore.p12"
  ZWE_zowe_certificate_keystore_password="${ZWE_CLI_PARAMETER_PASSWORD}"
  ZWE_zowe_certificate_truststore_password="${ZWE_CLI_PARAMETER_PASSWORD}"

  keystore_content=$(pkeytool -list \
                      -keystore "${ZWE_zowe_certificate_keystore_file}" \
                      -storepass "${ZWE_zowe_certificate_keystore_password}" \
                      -storetype "${ZWE_zowe_certificate_keystore_type}")

  ZWE_zowe_certificate_keystore_alias=
  aliases=$(echo "${keystore_content}" | grep -i keyentry | awk -F, '{print $1}')
  while read -r alias; do
    if [ -n "${alias}" ]; then
      alias_lc=$(lower_case "${alias}")
      ZWE_zowe_certificate_keystore_alias="${alias}"
      ZWE_zowe_certificate_pem_certificate="${temp_dir}/keystore/${ZWE_CLI_PARAMETER_ALIAS}/${alias_lc}.cer"
      ZWE_zowe_certificate_pem_key="${temp_dir}/keystore/${ZWE_CLI_PARAMETER_ALIAS}/${alias_lc}.key"
    fi
  done <<EOF
$(echo "${aliases}")
EOF

  ZWE_zowe_certificate_pem_certificateAuthorities=
  aliases=$(echo "${keystore_content}" | grep -i trustedcertentry | awk -F, '{print $1}')
  while read -r alias; do
    if [ -n "${alias}" ]; then
      alias_lc=$(lower_case "${alias}")
      if [ -n "${ZWE_zowe_certificate_pem_certificateAuthorities}" ]; then
        ZWE_zowe_certificate_pem_certificateAuthorities="${ZWE_zowe_certificate_pem_certificateAuthorities},"
      fi
      ZWE_zowe_certificate_pem_certificateAuthorities="${ZWE_zowe_certificate_pem_certificateAuthorities}${temp_dir}/keystore/${ZWE_CLI_PARAMETER_ALIAS}/${alias_lc}.cer"
    fi
  done <<EOF
$(echo "${aliases}")
EOF

  print_message
fi

if [ "${ZWE_zowe_setup_certificate_type}" = "PKCS12" -a "${ZWE_zowe_verifyCertificates}" = "STRICT" -a "$(is_certificate_generated_by_zowe)" = "true" ]; then
  print_level1_message "Re-generate Zowe certificate to include proper domains."

  print_message "To make the certificates working properly in Kubernetes, we need to generate"
  print_message "a new certificate with proper domains."
  print_message "You can customize domains by passing --domains option to this command."
  print_message

  if [ -z "${ZWE_zowe_setup_certificate_pkcs12_directory}" -o -z "${ZWE_zowe_setup_certificate_pkcs12_name}" -o -z "${ZWE_zowe_setup_certificate_pkcs12_caAlias}" ]; then
    print_error_and_exit "Error: zowe.setup.certificate section is required to regenerate new keystore."
  fi
  if [ ! -f "${ZWE_zowe_certificate_keystore_file}" ]; then
    print_error_and_exit "Error: cannot find original keystore file."
  fi

  mkdir -p "${temp_dir}/keystore"
  # copy CA to target directory, we need this to sign the new cert
  cp -r "${ZWE_zowe_setup_certificate_pkcs12_directory}/${ZWE_zowe_setup_certificate_pkcs12_caAlias}" "${temp_dir}/keystore"

  # create new certificate
  # we use node utility to generate certificate because keytool doesn't support * in SAN
  pkcs12_create_certificate_and_sign_with_node \
    "${temp_dir}/keystore" \
    "${ZWE_zowe_setup_certificate_pkcs12_name}" \
    "${ZWE_zowe_setup_certificate_pkcs12_name}" \
    "${ZWE_zowe_setup_certificate_pkcs12_password}" \
    "" \
    "${full_k8s_domain_list}" \
    "${ZWE_zowe_setup_certificate_pkcs12_caAlias}" \
    "${ZWE_zowe_setup_certificate_pkcs12_caPassword}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0169E: Failed to create certificate \"${ZWE_zowe_setup_certificate_pkcs12_name}\"." "" 169
  fi
  if [ ! -f "${temp_dir}/keystore/${ZWE_zowe_setup_certificate_pkcs12_name}/${ZWE_zowe_setup_certificate_pkcs12_name}.keystore.p12" ]; then
    >&2 echo "Error: failed to generate keystore for Kubernetes"
    exit 1
  fi

  # merge new generated keystore into original
  mv "${temp_dir}/keystore/${ZWE_zowe_setup_certificate_pkcs12_name}/${ZWE_zowe_setup_certificate_pkcs12_name}.keystore.p12" "${temp_dir}/keystore/${ZWE_zowe_setup_certificate_pkcs12_name}/${ZWE_zowe_setup_certificate_pkcs12_name}.keystore.p12-k8s"
  cp "${ZWE_zowe_certificate_keystore_file}" "${temp_dir}/keystore/${ZWE_zowe_setup_certificate_pkcs12_name}/${ZWE_zowe_setup_certificate_pkcs12_name}.keystore.p12"
  pkcs12_import_pkcs12_keystore \
    "${temp_dir}/keystore/${ZWE_zowe_setup_certificate_pkcs12_name}/${ZWE_zowe_setup_certificate_pkcs12_name}.keystore.p12" \
    "${ZWE_zowe_certificate_keystore_password}" \
    "${ZWE_zowe_certificate_keystore_alias}" \
    "${temp_dir}/keystore/${ZWE_zowe_setup_certificate_pkcs12_name}/${ZWE_zowe_setup_certificate_pkcs12_name}.keystore.p12-k8s" \
    "${ZWE_zowe_certificate_keystore_password}" \
    "${ZWE_zowe_certificate_keystore_alias}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0179E: Failed to import certificate into keystore ${ZWE_zowe_setup_certificate_pkcs12_name}.keystore.p12." "" 179
  fi
  rm -f "${temp_dir}/keystore/${ZWE_zowe_setup_certificate_pkcs12_name}/${ZWE_zowe_setup_certificate_pkcs12_name}.keystore.p12-k8s"

  # export all certs in PKCS#12 keystore as PEM format
  pkcs12_export_pem \
    "${temp_dir}/keystore/${ZWE_zowe_setup_certificate_pkcs12_name}/${ZWE_zowe_setup_certificate_pkcs12_name}.keystore.p12" \
    "${ZWE_zowe_certificate_keystore_password}" \
    "${ZWE_zowe_certificate_keystore_alias}"
  if [ $? -ne 0 ]; then
    print_error_and_exit "Error ZWEL0178E: Failed to export PKCS12 keystore ${ZWE_zowe_setup_certificate_pkcs12_name}.keystore.p12." "" 178
  fi

  # this is our new keystore for k8s
  ZWE_zowe_certificate_keystore_file="${temp_dir}/keystore/${ZWE_zowe_setup_certificate_pkcs12_name}/${ZWE_zowe_setup_certificate_pkcs12_name}.keystore.p12"
  ZWE_zowe_certificate_pem_key="${temp_dir}/keystore/${ZWE_zowe_setup_certificate_pkcs12_name}/$(lower_case "${ZWE_zowe_setup_certificate_pkcs12_name}").key"
  ZWE_zowe_certificate_pem_certificate="${temp_dir}/keystore/${ZWE_zowe_setup_certificate_pkcs12_name}/$(lower_case "${ZWE_zowe_setup_certificate_pkcs12_name}").cer"
  # truststore will reuse original

  print_message
fi

################################################################################
# update zowe.yaml suitable for k8s
print_level1_message "Update zowe.yaml configuration for Kubernetes"

delete_zowe_yaml "${temp_dir}/zowe.yaml" "java.home"
delete_zowe_yaml "${temp_dir}/zowe.yaml" "node.home"
delete_zowe_yaml "${temp_dir}/zowe.yaml" "haInstances"
delete_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.externalDomains"

update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.useConfigmgr" "false"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.runtimeDirectory" "${ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY}"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.workspaceDirectory" "${ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY}"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.logDirectory" "${ZWE_PRIVATE_CONTAINER_LOG_DIRECTORY}"

iterator_index=0
for host in $(echo "${ZWE_CLI_PARAMETER_DOMAINS}" | sed 's#[,]# #g'); do
  update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.externalDomains[${iterator_index}]" "${host}"
  iterator_index=`expr $iterator_index + 1`
done

update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.externalPort" "${ZWE_CLI_PARAMETER_EXTERNAL_PORT}"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.gateway.port" "7554"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.discovery.port" "7553"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.api-catalog.port" "7552"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.caching-service.port" "7555"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.app-server.port" "7556"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.jobs-api.port" "8545"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.files-api.port" "8547"

update_zowe_yaml "${temp_dir}/zowe.yaml" "components.gateway.enabled" "true"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.discovery.enabled" "true"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.api-catalog.enabled" "true"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.caching-service.enabled" "true"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.app-server.enabled" "true"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.jobs-api.enabled" "true"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.files-api.enabled" "true"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.explorer-jes.enabled" "true"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.explorer-mvs.enabled" "true"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.explorer-uss.enabled" "true"

update_zowe_yaml "${temp_dir}/zowe.yaml" "components.gateway.apiml.security.x509.externalMapperUrl" ""
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.gateway.apiml.security.authorization.endpoint.url" ""
gateway_auth_provider=$(read_yaml "${temp_dir}/zowe.yaml" ".components.gateway.apiml.security.authorization.endpoint.provider")
if [ "${gateway_auth_provider}" != "" ]; then
  print_message "Zowe APIML Gateway authorization provider is suggested to be empty when running in Kubernetes. 'native' is not supported off Z platform."
fi
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.gateway.apiml.security.authorization.endpoint.provider" ""
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.discovery.replicas" "1"
update_zowe_yaml "${temp_dir}/zowe.yaml" "components.caching-service.storage.mode" ""

update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.environments.ZWED_agent_host" "${original_zss_host}"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.environments.ZWED_agent_https_port" "${original_zss_port}"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.environments.ZOWE_ZLUX_TELNET_HOST" "${original_zss_host}"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.environments.ZOWE_ZLUX_SSH_HOST" "${original_zss_host}"

update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.certificate.keystore.file" "${ZWE_PRIVATE_CONTAINER_KEYSTORE_DIRECTORY}/keystore.p12"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.certificate.truststore.file" "${ZWE_PRIVATE_CONTAINER_KEYSTORE_DIRECTORY}/truststore.p12"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.certificate.pem.certificateAuthorities" "${ZWE_PRIVATE_CONTAINER_KEYSTORE_DIRECTORY}/ca.cer"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.certificate.pem.key" "${ZWE_PRIVATE_CONTAINER_KEYSTORE_DIRECTORY}/keystore.key"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.certificate.pem.certificate" "${ZWE_PRIVATE_CONTAINER_KEYSTORE_DIRECTORY}/keystore.cer"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.certificate.keystore.alias" "${ZWE_zowe_certificate_keystore_alias}"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.certificate.keystore.password" "${ZWE_zowe_certificate_keystore_password}"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.certificate.keystore.type" "${ZWE_zowe_certificate_keystore_type}"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.certificate.truststore.password" "${ZWE_zowe_certificate_truststore_password}"
update_zowe_yaml "${temp_dir}/zowe.yaml" "zowe.certificate.truststore.type" "${ZWE_zowe_certificate_truststore_type}"

print_message

################################################################################
# start official output
print_level1_message "Output Kubernetes ConfigMap and Secret manifests"

print_message "Please copy content between >>> START and <<< END, save them as a YAML file on your local"
print_message "computer, then apply it to your Kubernetes cluster. After apply, you MUST delete"
print_message "and destroy the temporary file from your local computer."
print_message
print_message "  Example: kubectl apply -f /path/to/my/local-saved.yaml"
print_message
print_message ">>> START"

################################################################################
# Prepare Kubernetes ConfigMap and Secret
cat << EOF
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: zowe-config
  namespace: ${ZWE_CLI_PARAMETER_K8S_NAMESPACE}
  labels:
    app.kubernetes.io/name: zowe
    app.kubernetes.io/instance: zowe
    app.kubernetes.io/managed-by: manual
data:
  zowe.yaml: |
$(cat "${temp_dir}/zowe.yaml" | file_padding_left - "    ")
EOF

cat << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: zowe-certificates-secret
  namespace: ${ZWE_CLI_PARAMETER_K8S_NAMESPACE}
  labels:
    app.kubernetes.io/name: zowe
    app.kubernetes.io/instance: zowe
    app.kubernetes.io/managed-by: manual
type: Opaque
data:
  keystore.p12: $(base64_encode "${ZWE_zowe_certificate_keystore_file}")
  truststore.p12: $(base64_encode "${ZWE_zowe_certificate_truststore_file}")
stringData:
  keystore.key: |
$(file_padding_left "${ZWE_zowe_certificate_pem_key}" "    ")
  keystore.cer: |
$(file_padding_left "${ZWE_zowe_certificate_pem_certificate}" "    ")
  ca.cer: |
$(files_padding_left "${ZWE_zowe_certificate_pem_certificateAuthorities}" "    ")
EOF

print_message
print_message "<<< END"
print_message

###############################
# remove temporary directory
rm -fr "${temp_dir}"

###############################
# exit message
print_level1_message "Kubernetes manifests to run Zowe in containers are ready."
