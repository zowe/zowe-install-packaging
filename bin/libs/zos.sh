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

tso_command() {
  message="- tsocmd $@"
  print_debug "${message}"
  result=$(tsocmd "$@" 2>&1)
  code=$?
  if [ ${code} -eq 0 ]; then
    print_debug "  * Succeeded"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    if [ -n "${result}" ]; then
      print_trace "$(padding_left "${result}" "    ")"
    fi
  else
    print_debug "  * Failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi
  fi

  echo "${result}"

  return ${code}
}

operator_command() {
  cmd="${1}"

  opercmd=${ZWE_zowe_runtimeDirectory}/bin/utils/opercmd.rex

  message="- opercmd ${cmd}"
  print_debug "${message}"
  result=$("${opercmd}" "${cmd}" 2>&1)
  code=$?
  if [ ${code} -eq 0 ]; then
    print_debug "  * Succeeded"
    print_trace "  * Exit code: ${code}"
    print_trace "  * Output:"
    if [ -n "${result}" ]; then
      print_trace "$(padding_left "${result}" "    ")"
    fi
  else
    print_debug "  * Failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi
  fi

  echo "${result}"

  return ${code}
}

verify_generated_jcl() {
  jcllib=$(read_yaml "${ZWE_CLI_PARAMETER_CONFIG}" ".zowe.setup.dataset.jcllib")
  # read JCL library and validate
  does_jcl_exist=$(is_data_set_exists "${jcllib}")
  if [ -z "${does_jcl_exist}" ]; then
    result=$(zwecli_inline_execute_command init generate)
  fi

  # should be created, but may take time to discover.
  if [ -z "${does_jcl_exist}" ]; then
    does_jcl_exist=
    for secs in 1 5 10 ; do
      does_jcl_exist=$(is_data_set_exists "${jcllib}")
      if [ -z "${does_jcl_exist}" ]; then
        sleep ${secs}
      else
        break
      fi
    done

    if [ -z "${does_jcl_exist}" ]; then
      return 1
    fi
  fi
  echo "${jcllib}"
  return 0
}
