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

# get netstat command, could be empty
get_netstat() {
  # z/OS
  netstat -? 2>/dev/null 1>/dev/null
  if [ $? -eq 0 ]; then
    echo "netstat"
  else
    # z/OS
    onetstat -? 2>/dev/null 1>/dev/null
    if [ $? -eq 0 ]; then
      echo "onetstat"
    else
      # non-z/OS may work with -h
      netstat -h 2>/dev/null 1>/dev/null
      if [ $? -eq 0 ]; then
        echo "netstat"
      else
        # non-z/OS may work with -h, but exit code is not 0. try listing interfaces
        netstat -i 2>/dev/null 1>/dev/null
        if [ $? -eq 0 ]; then
          echo "netstat"
        else
          return 1
        fi
      fi
    fi
  fi

  return 0
}

# $1 - should not be bound to a port currently
validate_port_is_available() {
  port=$1

  netstat=$(get_netstat)
  if [ $? -gt 0 ]; then
    print_error "No netstat tool found."
    return 1
  fi

  case $(uname) in
    "OS/390")
      result=$(${netstat} -c SERVER -P ${port} 2>/dev/null)
      code=$?
      if [ ${code} -ne 0 ]; then
        print_error "Netstat test fail with exit code ${code} (${result})"
        return 1
      fi
      result=$(echo "${result}" | grep Listen | xargs)
      if [ -n "${result}" ]; then
        print_error "Port ${port} is already in use by process (${result})"
        return 1
      fi
      ;;
    "Darwin")
      result=$(${netstat} -an -p tcp 2>/dev/null)
      code=$?
      if [ ${code} -ne 0 ]; then
        print_error "Netstat test fail with exit code ${code} (${result})"
        return 1
      fi
      result=$(echo "${result}" | grep -i LISTEN | grep ${port} | xargs)
      if [ -n "${result}" ]; then
        print_error "Port ${port} is already in use by process (${result})"
        return 1
      fi
      ;;
    *)
      # assume it's Linux format
      result=$(${netstat} -nlt 2>/dev/null)
      code=$?
      if [ ${code} -ne 0 ]; then
        print_error "Netstat test fail with exit code ${code} (${result})"
        return 1
      fi
      result=$(echo "${result}" | grep -i LISTEN | grep ${port} | xargs)
      if [ -n "${result}" ]; then
        print_error "Port ${port} is already in use by process (${result})"
        return 1
      fi
      ;;
  esac
}
