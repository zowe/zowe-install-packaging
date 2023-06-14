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

if [ "$#" -eq 2 ]; then
  message_id=$2
else
  print_error_and_exit "Error: Invalid arguments provided. Usage: zwe help <messageID>." "" 150
fi


case "$message_id" in
  "ID1")
    help_message="This is the help message for ID1."
    ;;
  "ID2")
    help_message="This is the help message for ID2."
    ;;
  *)
    print_error_and_exit "Error: Invalid message ID provided." "" 150
    ;;
esac

print_message "$help_message"

