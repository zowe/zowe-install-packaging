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
  echo "Message ID: $message_id"

  if [[ $message_id == ZWE* ]]; then
    echo "STARTS WITH ZWE"

    fourth_letter=${message_id:3:1}
    echo "fourth_letter: $fourth_letter"

    case "$fourth_letter" in
      "A")
        echo "Starts with A"
        ;;
      "D")
        echo "Starts with D"
        ;;
      "S")
        echo "Starts with S"
        ;;
      *)
        echo "Invalid fourth letter"
        ;;
    esac
  else
    echo "Invalid message ID"
  fi
else
  print_error_and_exit "Error: Invalid arguments provided. Usage: zwe help <messageID>." "" 150
fi
