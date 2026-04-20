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

##############################################################################
# Validate ATTLS ports for enabled components
#
# This function validates that AT-TLS rules are properly configured for 
# component ports that have AT-TLS enabled.
#
# Required environment variables:
# - ZWE_CLI_PARAMETER_CONFIG (path to zowe.yaml configuration file)
# - ZWE_zowe_runtimeDirectory
#
# Optional environment variables:
# - None
#
# Parameters:
# - $1: attls_requested (true/false) - global ATTLS setting from config
# - $2: quit_on_error (true/false) - if true, exit on first error
# - $3: component_name (optional) - validate only a specific component
#
# Returns:
# Return code 0 if all validations passed
# Return code > 0 if any validation failed
#
validate_attls_ports() {
  attls_requested="${1:-false}"
  quit_on_error="${2:-false}"
  component_name_filter="${3}"
  
  if [ ! -f "${ZWE_CLI_PARAMETER_CONFIG}" ]; then
    print_error "ZWEL0363W: Configuration file not found"
    return 1
  fi
  
  # Get userid from YAML configuration
  zowe_user_id=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.security.users.zowe")
  if [ -z "${zowe_user_id}" ]; then
    err_msg="zowe.setup.security.users.zowe is not configured. Cannot validate ATTLS port."
    if [ "${quit_on_error}" = "true" ]; then
      print_error "ZWEL0364E: ${err_msg}"
      return 1
    else
      print_error "ZWEL0363W: ${err_msg}"
      return 1
    fi
  fi
  
  # Get list of enabled components
  enabled_components=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.launchScript.*.enabled" | grep -i "true" || true)
  
  if [ -n "${component_name_filter}" ] && [ -n "${enabled_components}" ]; then
    # Validate specific component
    if echo "${enabled_components}" | grep -q "${component_name_filter}"; then
      checked_components="${component_name_filter}"
    else
      # Check if component is defined in config
      component_exists=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".components.${component_name_filter}" || true)
      if [ -z "${component_exists}" ]; then
        err_msg="Component '${component_name_filter}' is not defined. Skipping port ATTLS validation."
      else
        err_msg="Component '${component_name_filter}' is not enabled. Skipping port ATTLS validation."
      fi
      if [ "${quit_on_error}" = "true" ]; then
        print_error "ZWEL0364E: ${err_msg}"
      else
        print_error "ZWEL0363W: ${err_msg}"
      fi
      return 1
    fi
  else
    checked_components="${enabled_components}"
  fi
  
  detect_attls_port_path="${ZWE_zowe_runtimeDirectory}/bin/utils/detect-attls-port"
  my_jobname="${_BPX_JOBNAME}"
  
  print_formatted_info "validateAttlsPorts" "Checking ATTLS ports of component(s)"
  
  failed_count=0
  has_errors=false
  
  # Process each component
  for component_name in ${checked_components}; do
    component_name=$(echo "${component_name}" | trim)
    if [ -z "${component_name}" ]; then
      continue
    fi
    
    # Get port for component
    port=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".components.${component_name}.port" || true)
    
    # Skip if component doesn't have port configured
    if [ -z "${port}" ]; then
      print_formatted_debug "validateAttlsPorts" "${component_name}: Component has no port, skipped."
      continue
    fi
    
    # Check for per-component override, otherwise use global setting
    component_attls_override=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".components.${component_name}.zowe.network.server.tls.attls" || true)
    if [ -n "${component_attls_override}" ]; then
      component_attls_config="${component_attls_override}"
    else
      component_attls_config="${attls_requested}"
    fi

    # ATTLS direction is hardcoded to Inbound (1) for now
    attls_direction=1
    
    # Get component directory
    component_dir=$(find_component_directory "${component_name}")
    
    # Get listen address
    listen_address="0.0.0.0"
    component_listen_addresses=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".components.${component_name}.zowe.network.server.listenAddresses[0]" || true)
    if [ -n "${component_listen_addresses}" ]; then
      listen_address="${component_listen_addresses}"
    else
      global_listen_addresses=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.network.server.listenAddresses[0]" || true)
      if [ -n "${global_listen_addresses}" ]; then
        listen_address="${global_listen_addresses}"
      fi
    fi
    
    # Get component manifest and jobname
    jobname=""
    manifest=""
    if [ -n "${component_dir}" ]; then
      manifest=$(get_component_manifest "${component_dir}")
    fi
    
    # Get jobname using component function
    jobname=$(get_jobname_for_component "${component_name}" "${manifest}")
    
    # Set jobname if found
    if [ -n "${jobname}" ]; then
      export _BPX_JOBNAME="${jobname}"
      print_formatted_debug "validateAttlsPorts" \
        "${component_name}: Checking if ATTLS is enabled for port ${port} for userid ${zowe_user_id} on host ${listen_address}, jobname ${jobname}"
    else
      print_formatted_debug "validateAttlsPorts" \
        "${component_name}: Checking if ATTLS is enabled for port ${port} for userid ${zowe_user_id} on host ${listen_address} with default jobname"
    fi
    
    # Call detect-attls-port utility
    if [ -x "${detect_attls_port_path}" ]; then
      detect_output=$("${detect_attls_port_path}" \
        --serverPort "${port}" \
        --serverHost "${listen_address}" \
        --direction "${attls_direction}" 2>&1)
      result_rc=$?
    else
      print_formatted_error "validateAttlsPorts" \
        "ZWEL0365E: ${component_name}: Utility not found: ${detect_attls_port_path}"
      result_rc=1
      detect_output=""
    fi
    
    # Restore original jobname
    if [ -n "${jobname}" ]; then
      export _BPX_JOBNAME="${my_jobname}"
    fi
    
    # Check for mismatch: ATTLS enabled in config but no rules found, or ATTLS not enabled but rules found
    if [ "${component_attls_config}" = "true" ] && [ ${result_rc} -ne 0 ]; then
      # ATTLS is enabled but no rules found
      failed_count=$((failed_count + 1))
      if [ -n "${detect_output}" ]; then
        print_debug "${detect_output}"
      fi
      if [ -n "${jobname}" ]; then
        print_formatted_error "validateAttlsPorts" \
          "ZWEL0365E: ${component_name}: No AT-TLS rule identified on ${listen_address}:${port} for user ${zowe_user_id} and jobname ${jobname}"
      else
        print_formatted_error "validateAttlsPorts" \
          "ZWEL0365E: ${component_name}: No AT-TLS rule identified on ${listen_address}:${port} for user ${zowe_user_id}"
      fi
      has_errors=true
    elif [ "${component_attls_config}" = "false" ] && [ ${result_rc} -eq 0 ]; then
      # ATTLS is not enabled but rules are found - configuration mismatch
      failed_count=$((failed_count + 1))
      if [ -n "${detect_output}" ]; then
        print_debug "${detect_output}"
      fi
      if [ -n "${jobname}" ]; then
        print_formatted_error "validateAttlsPorts" \
          "ZWEL0367E: ${component_name}: AT-TLS rule found but ATTLS is not enabled in configuration on ${listen_address}:${port} for user ${zowe_user_id} and jobname ${jobname}"
      else
        print_formatted_error "validateAttlsPorts" \
          "ZWEL0367E: ${component_name}: AT-TLS rule found but ATTLS is not enabled in configuration on ${listen_address}:${port} for user ${zowe_user_id}"
      fi
      has_errors=true
    elif [ -n "${detect_output}" ]; then
      print_debug "${detect_output}"
    fi
  done
  
  if [ "${has_errors}" = "false" ]; then
    print_formatted_info "validateAttlsPorts" "Zowe port ATTLS validation passed."
    return 0
  elif [ "${quit_on_error}" = "false" ]; then
    print_formatted_error "validateAttlsPorts" \
      "ZWEL0366E: ${failed_count} Zowe port ATTLS validation(s) failed, review output for action items before running Zowe."
    return ${failed_count}
  else
    # It is possible that the ATTLS check failed due to missing detect-attls-port binary or other unexpected error, so we want to provide a hint about how to bypass the check if needed instead of just exiting with error code.
    print_formatted_error "validateAttlsPorts" \
      "Zowe port ATTLS validation failed. This check can be dismissed with YAML value \"zowe.launchScript.startupChecks.attls: warn\""
    print_error "ZWEL0366E: ${failed_count} Zowe port ATTLS validation(s) failed, review output for action items before running Zowe."
    exit 8
  fi
}

