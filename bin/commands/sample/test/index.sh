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

print_level0_message "Command: sample sub test"
print_message "I'm the sample sub test command"
print_message

print_level1_message "execute_command"
result=$(execute_command "ls /var/zowe")
code=$?
print_message "code=${code}" "console"
print_message "result=${result}" "console"
print_message

print_level1_message "tso_command"
result=$(tso_command listds "'USER.PROCLIB'")
code=$?
print_message "code=${code}" "console"
print_message "result=${result}" "console"
print_message

print_level1_message "operator_command"
result=$(operator_command "D A,L")
code=$?
print_message "code=${code}" "console"
print_message "result=${result}" "console"
print_message

print_level1_message "get_data_set_volume"
result=$(get_data_set_volume "USER.PROCLIB")
code=$?
print_message "code=${code}" "console"
print_message "result=${result}" "console"
print_message

print_level1_message "is_data_set_sms_managed"
result=$(is_data_set_sms_managed "USER.PROCLIB")
code=$?
print_message "code=${code}" "console"
print_message "result=${result}" "console"
print_message

print_level1_message "apf_authorize_data_set"
result=$(apf_authorize_data_set "IBMUSER.ZWE.SZWEAUTH")
code=$?
print_message "code=${code}" "console"
print_message "result=${result}" "console"
print_message

print_level1_message "submit_job TSTFAST"
jobid=$(submit_job "${ZWE_zowe_runtimeDirectory}/bin/commands/sample/test/TSTFAST.jcl")
code=$?
print_message "code=${code}" "console"
print_message "jobid=${jobid}" "console"
if [ -n "${jobid}" ]; then
  result=$(wait_for_job "${jobid}")
  code=$?
  print_message "code=${code}" "console"
  print_message "result=${result}" "console"
fi
print_message

print_level1_message "submit_job TSTFAST"
jobid=$(submit_job "${ZWE_zowe_runtimeDirectory}/bin/commands/sample/test/TSTFAIL.jcl")
code=$?
print_message "code=${code}" "console"
print_message "jobid=${jobid}" "console"
if [ -n "${jobid}" ]; then
  result=$(wait_for_job "${jobid}")
  code=$?
  print_message "code=${code}" "console"
  print_message "result=${result}" "console"
fi
print_message


print_level1_message "submit_job TSTFAST"
jobid=$(submit_job "${ZWE_zowe_runtimeDirectory}/bin/commands/sample/test/TSTSLOW.jcl")
code=$?
print_message "code=${code}" "console"
print_message "jobid=${jobid}" "console"
if [ -n "${jobid}" ]; then
  result=$(wait_for_job "${jobid}")
  code=$?
  print_message "code=${code}" "console"
  print_message "result=${result}" "console"
fi
print_message
