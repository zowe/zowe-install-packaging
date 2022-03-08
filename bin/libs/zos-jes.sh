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

submit_job() {
  jcl="${1}"

  print_debug "- submit job ${jcl}"

  print_trace "- content of ${jcl}"
  result=$(cat "${jcl}" 2>&1)
  code=$?
  if [ ${code} -eq 0 ]; then
    print_trace "$(padding_left "${result}" "    ")"
  else
    print_trace "  * Failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi

    return ${code}
  fi

  result=$(submit "${jcl}")
  # expected: JOB JOB????? submitted from path '...'
  code=$?
  if [ ${code} -eq 0 ]; then
    jobid=$(echo "${result}" | grep submitted | awk '{print $2}')
    if [ -z "${jobid}" ]; then
      print_debug "  * Failed to find job ID"
      print_error "  * Exit code: ${code}"
      print_error "  * Output:"
      if [ -n "${result}" ]; then
        print_error "$(padding_left "${result}" "    ")"
      fi
      return 1
    else
      echo "${jobid}"
      print_debug "  * Succeeded with job ID ${jobid}"
      print_trace "  * Exit code: ${code}"
      print_trace "  * Output:"
      if [ -n "${result}" ]; then
        print_trace "$(padding_left "${result}" "    ")"
      fi
      return 0
    fi
  else
    print_debug "  * Failed"
    print_error "  * Exit code: ${code}"
    print_error "  * Output:"
    if [ -n "${result}" ]; then
      print_error "$(padding_left "${result}" "    ")"
    fi

    return ${code}
  fi
}

wait_for_job() {
  jobid="${1}"
  jobstatus=
  jobname=
  jobcctext=
  jobcccode=

  print_debug "- Wait for job ${jobid} completed, starting at $(date)."
  # wait for job to finish
  for secs in 1 5 10 30 100 300 500 ; do
    print_trace "  * Wait for ${secs} seconds"
    sleep ${secs}
    result=$(operator_command "\$D ${jobid},CC")
    # $DJ gives ...
    # ... $HASP890 JOB(JOB1)      CC=(COMPLETED,RC=0)  <-- accept this value
    # ... $HASP890 JOB(GIMUNZIP)  CC=()  <-- reject this value
    jobstatus=$(echo "${result}" | grep '$HASP890' | sed 's#^.*\$HASP890 *JOB(\(.*\)) *CC=(\(.*\)).*$#\1,\2#')
    jobname=$(echo "${jobstatus}" | awk -F, '{print $1}')
    jobcctext=$(echo "${jobstatus}" | awk -F, '{print $2}')
    jobcccode=$(echo "${jobstatus}" | awk -F, '{print $3}' | awk -F= '{print $2}')
    print_trace "  * Job (${jobname}) status is ${jobcctext},RC=${jobcccode}"
    if [ -n "${jobcctext}" -o -n "${jobcccode}" ]; then
      # job have CC state
      break
    fi
  done
  print_trace "  * Job status check done at $(date)."

  echo "${jobid},${jobname},${jobcctext},${jobcccode}"
  if [ -n "${jobcctext}" -o -n "${jobcccode}" ]; then
    print_debug "  * Job (${jobname}) exits with code ${jobcccode} (${jobcctext})."
    if [ "${jobcccode}" = "0" ]; then
      return 0
    else
      # ${jobcccode} could be greater than 255
      return 2
    fi
  else
    print_error "  * Job (${jobname:-${jobid}}) doesn't finish within max waiting period."
    return 1
  fi
}
