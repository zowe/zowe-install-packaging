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


if [ "$#" -eq 0 ]; then
    echo "No command-line arguments provided."
else
    echo "Command-line arguments were provided."
fi

if [ "$#" -eq 1 ]; then
   message_id1=$1
   echo "Message ID1: $message_id1"
else
  echo "Not just one parameter"
fi

if [ "$#" -eq 1 ]; then
  argument="$1"
  echo "Command-line argument: $argument"
else
  echo "No command-line argument provided or too many arguments."
fi

if [ "$#" -ge 1 ]; then
  echo "Command-line arguments:"
  for arg in "$@"; do
    echo "$arg"
  done
else
  echo "No command-line arguments provided."
fi

if [ "$#" -eq 2 ]; then
  message_id2=$2
  echo "Message ID2: $message_id2"

  if [[ $message_id == ZWE* ]]; then
    echo "STARTS WITH ZWE"
  else
    echo "Invalid message ID"
  fi
else
  print_error_and_exit "Error: Invalid arguments provided. Usage: zwe help <messageID>." "" 150
fi
