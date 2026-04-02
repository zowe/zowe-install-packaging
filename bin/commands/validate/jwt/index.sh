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

print_level1_message "Validate z/OSMF JWK endpoint"

###############################
# validation
validate_zowe_yaml "${ZWE_CLI_PARAMETER_CONFIG}"
require_java

###############################
# read z/OSMF host and port
zosmf_host=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zOSMF.host")
zosmf_port=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zOSMF.port")

if [ -z "${zosmf_host}" ]; then
  print_error_and_exit "Error ZWEL0180E: z/OSMF host (zOSMF.host) is not defined in Zowe YAML configuration file." "" 180
fi
if [ -z "${zosmf_port}" ]; then
  print_error_and_exit "Error ZWEL0180E: z/OSMF port (zOSMF.port) is not defined in Zowe YAML configuration file." "" 180
fi

###############################
# read gateway auth provider and jwtAutoconfiguration
auth_provider=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".components.gateway.apiml.security.auth.provider")
jwt_autoconfig=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".components.gateway.apiml.security.auth.zosmf.jwtAutoconfiguration")

# pre-validation: auth provider
if [ -n "${auth_provider}" ] && [ "$(echo "${auth_provider}" | lower_case)" = "saf" ]; then
  print_level2_message "Auth provider is 'saf', not 'zosmf'. z/OSMF JWK endpoint validation is only applicable when using zosmf as the auth provider."
  print_message "Skipping JWK endpoint check."
  exit 0
fi

# pre-validation: jwtAutoconfiguration
if [ -n "${jwt_autoconfig}" ] && [ "$(echo "${jwt_autoconfig}" | lower_case)" = "ltpa" ]; then
  print_message "WARNING ZWEL0182E: jwtAutoconfiguration is 'ltpa'. The z/OSMF JWK endpoint may not be available. Consider switching to 'jwt' mode."
  print_message "Proceeding with JWK endpoint check anyway..."
fi

###############################
# read verifyCertificates
verify_certificates=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.verifyCertificates")
if [ -z "${verify_certificates}" ]; then
  verify_certificates="STRICT"
fi
verify_certificates=$(echo "${verify_certificates}" | upper_case)

###############################
# build java -jar arguments
jar_path="${ZWE_zowe_runtimeDirectory}/bin/utils/zosmf-jwt-check.jar"
if [ ! -f "${jar_path}" ]; then
  print_error_and_exit "Error ZWEL0180E: zosmf-jwt-check.jar not found at ${jar_path}." "" 180
fi

java_cmd="${JAVA_HOME}/bin/java -jar ${jar_path}"
java_args="--zosmf-host ${zosmf_host} --zosmf-port ${zosmf_port} --verify-certificates ${verify_certificates}"

###############################
# resolve truststore if verification is not DISABLED
if [ "${verify_certificates}" != "DISABLED" ]; then
  truststore_type=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.certificate.truststore.type")
  truststore_file=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.certificate.truststore.file")
  truststore_password=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.certificate.truststore.password")

  if [ -z "${truststore_file}" ]; then
    print_error_and_exit "Error ZWEL0180E: Truststore file (zowe.certificate.truststore.file) is not defined in Zowe YAML configuration file. Required when verifyCertificates is ${verify_certificates}." "" 180
  fi
  if [ -z "${truststore_password}" ]; then
    print_error_and_exit "Error ZWEL0180E: Truststore password (zowe.certificate.truststore.password) is not defined in Zowe YAML configuration file. Required when verifyCertificates is ${verify_certificates}." "" 180
  fi

  java_args="${java_args} --truststore-file ${truststore_file} --truststore-password ${truststore_password}"

  if [ -n "${truststore_type}" ]; then
    java_args="${java_args} --truststore-type ${truststore_type}"
  fi
fi

###############################
# resolve keystore (for mutual TLS, optional)
keystore_file=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.certificate.keystore.file")
keystore_password=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.certificate.keystore.password")
keystore_type=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.certificate.keystore.type")

if [ -n "${keystore_file}" ] && [ -n "${keystore_password}" ]; then
  java_args="${java_args} --keystore-file ${keystore_file} --keystore-password ${keystore_password}"
  if [ -n "${keystore_type}" ]; then
    java_args="${java_args} --keystore-type ${keystore_type}"
  fi
fi

###############################
# execute z/OSMF JWT check
print_message "Running z/OSMF JWT check against z/OSMF at ${zosmf_host}:${zosmf_port} (verifyCertificates=${verify_certificates})"
print_trace "Command: ${java_cmd} ${java_args}"

eval "${java_cmd} ${java_args}"
rc=$?

if [ ${rc} -eq 0 ]; then
  print_level2_message "z/OSMF JWK endpoint check passed."
elif [ ${rc} -eq 4 ]; then
  print_error_and_exit "Error ZWEL0180E: z/OSMF JWK endpoint check failed. The endpoint may not be reachable or the certificate configuration may be incorrect." "" 180
elif [ ${rc} -eq 8 ]; then
  # help was displayed by the jar, not an error
  exit 0
else
  print_error_and_exit "Error ZWEL0180E: z/OSMF JWK endpoint check failed with unexpected exit code ${rc}." "" 180
fi
