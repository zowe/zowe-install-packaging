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
is_port_available() {
  port="${1}"

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

# get current IP address
get_ipaddress() {
  hostname=$1
  method=
  ip=

  # dig is preferred than ping
  dig_result=$(dig -4 +short ${hostname} 2>/dev/null || dig +short ${hostname} 2>/dev/null)
  if [ -n "${dig_result}" ]; then
    method=dig
    ip=$(echo "${dig_result}" | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -1)
  fi

  # try ping
  if [ -z "${ip}" ]; then
    ping=$(get_ping)
    timeout=2
    ip=
    if [ -n "${ping}" ]; then
      # try to get IPv4 address only
      # - z/OS: -A ipv4
      # - Linux: -4
      # - Mac: not supported
      # timeout
      # - z/OS: -t
      # - Linux: -W
      # - Mac: -t
      # try in sequence of z/OS, Linux, Mac
      ping_result=$(${ping} -c 1 -A ipv4 -t ${timeout} ${hostname} 2>/dev/null || ${ping} -c 1 -4 -W ${timeout} ${hostname} 2>/dev/null || ${ping} -c 1 -t ${timeout} ${hostname} 2>/dev/null)
      if [ $? -eq 0 ]; then
        method=ping
        ip=$(echo "${ping_result}" | sed -n -E 's/^[^(]+\(([^)]+)\).*/\1/p' | head -1)
      fi
    fi
  fi

  # we don't have dig and ping, let's check /etc/hosts
  if [ -z "${ip}" -a -f /etc/hosts ]; then
    method=hosts
    ip=$(cat /etc/hosts | awk '{$1=$1;print}' | grep -v -e '^#' | grep -v -e '^$' | grep -e " ${hostname}$" | awk '{print $1}' | grep -v ':' | head -1)
  fi

  if [ -n "${ip}" ]; then
    echo "${ip}"
  else
    return 1
  fi
}
