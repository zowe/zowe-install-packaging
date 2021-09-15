#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2021
################################################################################

###############################
# Return system name in lower case
#
# - value &SYSNAME variable
# - short hostname
get_sysname() {
  # works for z/OS
  sysname=$(sysvar SYSNAME 2>/dev/null)
  if [ -z "${sysname}" ]; then
    # works for z/OS and most Linux with hostname command
    sysname=$(hostname -s 2>/dev/null)
  fi
  if [ -z "${sysname}" ]; then
    # this could be a wild guess for container, check the last entry of /etc/hosts
    # works for containers not running in Kubernetes, and Linux without hostname command, like ubi-minimal
    sysname=$(cat /etc/hosts | tail -1 | awk '{print $2}')
  fi
  echo "${sysname}" | tr '[:upper:]' '[:lower:]'
}

###############################
# Check if script is running on z/OS
#
# Output          true if it's z/OS
is_on_zos() {
  if [ `uname` = "OS/390" ]; then
    echo "true"
  fi
}

###############################
# List direct children PIDs of a process
#
# @param string   PID to list
# @param string   optional, process hierarchy list
# Output          pid list separated by space
find_direct_child_processes() {
  parent=$1
  tree=$2

  if [ -z "${tree}" ]; then
    tree=$(ps -o pid,ppid,comm -A | tail -n +2)
  fi

  while read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    ppid=$(echo "$line" | awk '{print $2}')
    comm=$(echo "$line" | awk '{print $3}')
    if [ "${ppid}" = "${parent}" -a "${comm}" != "ps" -a "${comm}" != "/bin/ps" -a "${comm}" != "tail" ]; then
      printf "${pid} "
    fi
  done <<EOF
$(echo "${tree}")
EOF
}

###############################
# List all children PIDs of a process
#
# @param string   PID to list
# @param string   optional, process hierarchy list
# Output          pid list separated by space
find_all_child_processes() {
  parent=$1
  tree=$2

  if [ -z "${tree}" ]; then
    tree=$(ps -o pid,ppid,comm -A | tail -n +2)
  fi

  for child in $(find_direct_child_processes "${parent}" "${tree}"); do
    printf "${child} "
    find_all_child_processes "${child}" "${tree}"
  done
}

###############################
# Wait until a single process exits
#
# @param string   PID to check
# @return         0 - process exits normally
#                 1 - process does not exit before timeout (30 seconds)
# Output          message about how this PID exits
wait_for_process_exit() {
  pid=$1

  iterator_index=0
  max_iterator_index=30
  found=$(ps -p ${pid} -o pid 2>/dev/null | tail -n +2)
  while [ -n "${found}" -a $iterator_index -lt $max_iterator_index ]; do
    sleep 1
    iterator_index=`expr $iterator_index + 1`
    found=$(ps -p ${pid} -o pid 2>/dev/null | tail -n +2)
  done
  if [ -n "${found}" ]; then
    echo "process $pid does NOT exit before timeout"
    return 1
  elif [ ${iterator_index} -eq 0 ]; then
    echo "process $pid does NOT exist or already exited"
    return 0
  else
    echo "process $pid exited gracefully"
    return 0
  fi
}

###############################
# Gracefully shutdown - send SIGTERM to all child processes before shutting down
#
# Usage: trap SIGTERM (15) signal and do gracefully shutdown
#     trap gracefully_shutdown 15
#
# @param string   PID to shutdown
# Output          process shutdown information
gracefully_shutdown() {
  pid=${1:-${current_process_id:-$$}}

  if [ -n "${pid}" ]; then
    children=$(find_all_child_processes $pid)
    echo "process ${pid} has children: ${children}"
    # send SIGTERM to all children
    kill -15 ${children} 2>/dev/null
    for pid in ${children}; do
      wait_for_process_exit $pid
    done
  fi

  exit 0
}
