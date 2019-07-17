#!/bin/sh
# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
BASEDIR=$(dirname "$0")
saf=$1
user=$2
echo "Check if user ${user} is defined (SAF=${saf})"
case $saf in
RACF)
  msg=`tsocmd "LU ${user}" 2>/dev/null | head -1`
  case $msg in
  UNABLE\ TO\ LOCATE\ USER\ *)
    echo "Warning:  User ${user} is not defined"
    return 1
  ;;
  NOT\ AUTHORIZED\ TO\ LIST\ *)
    echo "Error: User ${user} is defined but you are not authorized to list it"
    return 8
  ;;
  USER=${user}\ *)
    echo "Info:  User ${user} is defined and you are authorized to list it"
    return 0
  ;;
  *)
    echo "Error:  Unexpected response to LU command"
    echo $msg
    exreturnit 8
  esac
;;
ACF2)
  echo "Warning:  ACF2 support has not been implemented," \
    "please manually check if user ${user} is defined"
  return 8
;;
TSS)
  tss0314="TSS0314E  ACID DOES NOT EXIST"
  tss0352="TSS0352E  ACID NOT OWNED WITHIN SCOPE"
  msg=`tsocmd "TSS LIST(${user}) DATA(NAME)" 2>/dev/null | head -1 `
  case $msg in
  ${tss0314}*)
    echo "Warning:  User ${user} is not defined"
    return 1
  ;;
  ${tss0352}*)
    echo "Error: User ${user} is defined but you are not authorized to list it"
    return 8
  ;;
  ACCESSORID\ =\ ${user}\ *)
    echo "Info:  User ${user} is defined and you are authorized to list it"
    return 0
  ;;
  *)
    echo "Error:  Unexpected response to TSS LIST command"
    echo $msg
    return 8
  esac
;;
*)
  echo "Error:  Unexpected SAF $saf"
  return 8
esac
