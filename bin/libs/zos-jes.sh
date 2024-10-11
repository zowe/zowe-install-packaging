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

  # cat seems to work more reliably. sometimes, submit by itself just says it cannot find a real dataset.
  result=$(cat "${jcl}" | submit 2>&1)
  # expected: JOB JOB????? submitted from path '...'
  code=$?
  if [ ${code} -eq 0 ]; then
    jobid=$(echo "${result}" | grep submitted | awk '{print $2}')
    if [ -z "${jobid}" ]; then
      jobid=$(echo "${result}" | grep "$HASP" | head -n 1 | awk '{print $2}')
    fi
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
  is_jes3=
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
    # if it's JES3, we receive this:
    # ...             ISF031I CONSOLE IBMUSER ACTIVATED
    # ...            -$D JOB00132,CC
    # ...  IBMUSER7   IEE305I $D       COMMAND INVALID
    is_jes3=$(echo "${result}" | grep '\$D \+COMMAND INVALID')
    if [ -n "${is_jes3}" ]; then
      print_debug "  * JES3 identified"
      show_jobid=$(echo "${jobid}" | cut -c4-)
      result=$(operator_command "*I J=${show_jobid}")
      # $I J= gives ...
      # ...            -*I J=00132
      # ...  JES3       IAT8674 JOB BPXAS    (JOB00132) P=15 CL=A        OUTSERV(PENDING WTR)
      # ...  JES3       IAT8699 INQUIRY ON JOB STATUS COMPLETE,       1 JOB  DISPLAYED
      jobname=$(echo "${result}" | grep 'IAT8674' | sed 's#^.*IAT8674 *JOB *##' | awk '{print $1}')
      break
    else
      # $DJ gives ...
      # ... $HASP890 JOB(JOB1)      CC=(COMPLETED,RC=0)  <-- accept this value
      # ... $HASP890 JOB(GIMUNZIP)  CC=()  <-- reject this value
      haspline=$(echo "${result}" | grep '$HASP890')
      if [ -n "${haspline}" ]; then
        jobstatus=$(echo "${haspline}" | sed 's#^.*\$HASP890 *JOB(\(.*\)) *CC=(\(.*\)).*$#\1,\2#')
        jobname=$(echo "${jobstatus}" | awk -F, '{print $1}')
        jobcctext=$(echo "${jobstatus}" | awk -F, '{print $2}')
        jobcccode=$(echo "${jobstatus}" | awk -F, '{print $3}' | awk -F= '{print $2}')
        print_trace "  * Job (${jobname}) status is ${jobcctext},RC=${jobcccode}"
        if [ -n "${jobcctext}" -o -n "${jobcccode}" ]; then
          # job have CC state
          break
        fi
      fi
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
  elif [ -n "${is_jes3}" ]; then
    print_trace "  * Cannot determine job complete code. Please check job log manually."
    return 0
  else
    print_error "  * Job (${jobname:-${jobid}}) doesn't finish within max waiting period."
    return 1
  fi
}

print_and_handle_jcl() {
  jcl_location="${1}"
  job_name="${2}"
  jcllib="${3}"
  prefix="${4}"
  remove_jcl_on_finish="${5}"
  continue_on_failure="${6}"
  jcl_contents=$(cat "${jcl_location}")
  job_has_failures=false

  print_message "Template JCL: ${prefix}.SZWESAMP(${job_name}) , Executable JCL: ${jcllib}(${job_name})"
  print_message "--- JCL Content ---"
  print_message "$jcl_contents"
  print_message "--- End of JCL ---"

  if [ -z "${ZWE_CLI_PARAMETER_DRY_RUN}" ]; then
    print_message "Submitting Job ${job_name}"
    jobid=$(submit_job "${jcl_location}")
    code=$?
    if [ ${code} -ne 0 ]; then
      job_has_failures=true
      if [ "${continue_on_failure}" = "true" ]; then
        print_error "Warning ZWEL0161W: Failed to run JCL ${jcllib}(${job_name})"
        jobid=
      else
        if [ "${remove_jcl_on_finish}" = "true" ]; then
          rm "${jcl_location}"
        fi
        print_error_and_exit "Error ZWEL0161E: Failed to run JCL ${jcllib}(${job_name})." "" 161
      fi
    fi
    print_debug "- job id ${jobid}"

    jobstate=$(wait_for_job "${jobid}")
    code=$?
    if [ ${code} -eq 1 ]; then
      job_has_failures=true
      if [ "${continue_on_failure}" = "true" ]; then
        print_error "Warning ZWEL0162W: Failed to find job ${jobid} result."
      else
        if [ "${remove_jcl_on_finish}" = "true" ]; then
          rm "${jcl_location}"
        fi
        print_error_and_exit "Error ZWEL0162E: Failed to find job ${jobid} result." "" 162
      fi
    fi
    jobname=$(echo "${jobstate}" | awk -F, '{print $2}')
    jobcctext=$(echo "${jobstate}" | awk -F, '{print $3}')
    jobcccode=$(echo "${jobstate}" | awk -F, '{print $4}')

    if [ "${code}" -eq 0 ]; then
    else
      job_has_failures=true
      if [ "${continue_on_failure}" = "true" ]; then
        print_error "Warning ZWEL0163W: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})."
      else
        if [ "${remove_jcl_on_finish}" = "true" ]; then
          rm "${jcl_location}"
        fi
        print_error_and_exit "Error ZWEL0163E: Job ${jobname}(${jobid}) ends with code ${jobcccode} (${jobcctext})." "" 163
      fi
    fi
    if [ "${remove_jcl_on_finish}" = "true" ]; then
      rm "${jcl_location}"
    fi
    if [ "${job_has_failures}" = "true" ]; then
      print_level2_message "Job ended with some failures. Please check job log for details."
    fi
    return 0
  else
    print_message "JCL not submitted, command run with dry run flag."
    print_message "To perform command, re-run command without dry run flag, or submit the JCL directly"
    print_level2_message "Command run successfully."
    if [ "${remove_jcl_on_finish}" = "true" ]; then
      rm "${jcl_location}"
    fi
    return 0
  fi
}
