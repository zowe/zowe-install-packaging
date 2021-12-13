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
  cmd=$1

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
