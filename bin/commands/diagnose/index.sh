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

USE_CONFIGMGR=$(check_configmgr_enabled)
if [ "${USE_CONFIGMGR}" = "true" ]; then
  _CEE_RUNOPTS="XPLINK(ON),HEAPPOOLS(OFF)" ${ZWE_zowe_runtimeDirectory}/bin/utils/configmgr -script "${ZWE_zowe_runtimeDirectory}/bin/commands/diagnose/cli.js"
else

  error_code="${ZWE_CLI_PARAMETER_ERROR_CODE}"

  print_message ""

  if echo $error_code | grep -q -E "^[zZ][wW][eE][AaSsDdLl][A-Za-z]?[0-9]{3,4}[A-Za-z]$"; then
    server_code=$(echo "${error_code}" | cut -c4)
    if [[ "$server_code" == [Dd] ]]; then
      print_message "This code corresponds to the errors related to the ZOWE Desktop and the App Server."
      print_message ""
      print_message "To find the description of this error code, refer to the:"
      print_message ""
      print_message "  Zowe documentation for Application framework"
      print_message "    https://docs.zowe.org/stable/troubleshoot/app-framework/appserver-error-codes"
    elif [[ "$server_code" == [Ss] ]]; then
      print_message "This code corresponds to the errors related to the Zowe Subsystem Services (ZSS) and Zowe Installation Services (ZIS)."
      print_message ""
      print_message "To find the description of this error code, refer to the:"
      print_message ""
      print_message "  Zowe documentation for ZSS"
      print_message "    https://docs.zowe.org/stable/troubleshoot/app-framework/zss-error-codes"
      print_message "  Zowe documentation for ZIS"
      print_message "    https://docs.zowe.org/stable/troubleshoot/app-framework/zis-error-codes"
    elif [[ "$server_code" == [Aa] ]]; then
      print_message "This code corresponds to the errors related to the Zowe API Mediation Layer (APIML)."
      print_message ""
      print_message "To find the description of this error code, refer to the:"
      print_message ""
      print_message "  Zowe documentation for API Mediation Layer"
      print_message "    https://docs.zowe.org/stable/troubleshoot/troubleshoot-apiml-error-codes"
    elif [[ "$server_code" == [Ll] ]]; then
      print_message "This code corresponds to the errors related to the Zowe Launcher and ZWE."
      print_message ""
      print_message "To find the description of this error code, refer to the:"
      print_message ""
      print_message "  Zowe documentation for Launcher"
      print_message "    https://docs.zowe.org/stable/troubleshoot/launcher/launcher-error-codes"
      print_message "  Launcher error codes"
      print_message "    https://github.com/zowe/launcher/blob/v2.x/master/src/msg.h"
      print_message "  Zowe documentation for ZWE"
      print_message "    https://docs.zowe.org/stable/appendix/zwe_server_command_reference/zwe/"
    fi
    print_message ""
    print_message "You may also explore reports from other users experiencing the same error by searching"
    print_message "https://github.com/search?q=org%3Azowe+${error_code}&type=discussions"
  else
    print_error_and_exit "ZWEL0102E: Invalid parameter --error-code='${error_code}'" "" 102
  fi

  print_message ""

fi
