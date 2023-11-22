#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2022
################################################################################

case $install_test_choice in

"Convenience Pax")
  test_file="$CONVENIENCE_PAX_TESTFILE"
  ;;

"SMPE FMID")
  test_file="$SMPE_FMID_TESTFILE"
  ;;

"SMPE PTF")
  test_file="$SMPE_PTF_TESTFILE"
  ;;

"Extensions")
  test_file="$EXTENSIONS_TESTFILE"
  ;;

"Keyring")
  test_file="$KEYRING_TESTFILE"
  ;;

"z/OS node v18")
  test_file="$ZOS_NODE_V18_TESTFILE"
  test_force_system="zzow04"
  ;;

"Non-strict Verify External Certificate")
  test_file="$NON_STRICT_VERIFY_EXTERNAL_CERTIFICATE_TESTFILE"
  ;;

"Install PTF Twice")
  test_file="$INSTALL_PTF_TWICE_TESTFILE"
  ;;

"VSAM Caching Storage Method")
  test_file="$VSAM_CACHING_STORAGE_METHOD_TESTFILE"
  ;;

"Infinispan Caching Storage Method")
  test_file="$INFINISPAN_CACHING_STORAGE_METHOD_TESTFILE"
  ;;

"Generate API Documentation")
  test_file="$GENERAL_API_DOCUMENTATION_TESTFILE"
  ;;

"Config Manager")
  test_file="$CONFIG_MANAGER_TESTFILE"
  ;;

"Zowe Nightly Tests")
  test_file="$ZOWE_NIGHTLY_TESTS_FULL"
  dont_parse_test_server=true
  ;;

"Zowe Release Tests")
  test_file="$ZOWE_RELEASE_TESTS_FULL"
  dont_parse_test_server=true
  ;;

*)
  echo "Something went wrong when parsing install test choice input"
  exit 1
  ;;
esac

# this variable may be set for individual tests above. If using nightly/release, see cicd-test.yml workflow
if [[ ! -z "$test_force_system" ]]; then
  TEST_FILE_SERVER="$test_file($test_force_system)"
else
  if [[ -z "$dont_parse_test_server" ]]; then
    if [[ "$test_server" == "Any zzow servers" ]]; then
      test_server="zzow0"$(echo $(($RANDOM % 3 + 2)))
    fi
    TEST_FILE_SERVER="$test_file($test_server)"
  else
    any_occurrence=$(echo $test_file | grep -o "(any)" | wc -l)
    interim_test_file_server=$test_file
    for i in $(seq $any_occurrence); do
      interim_test_file_server=$(echo $interim_test_file_server | sed "s#(any)#(zzow0$(echo $(($RANDOM % 3 + 2))))#")
    done

    TEST_FILE_SERVER=$(echo $interim_test_file_server | sed "s#(all)#(zzow02,zzow03,zzow04)#g")
  fi
fi

# this is the final string that can be recognizable by the matrix processing script down below
echo "TEST_FILE_SERVER is "$TEST_FILE_SERVER

# sanitize all whitespaces just in case
TEST_FILE_SERVER=$TEST_FILE_SERVER | tr -d "[:space:]"

MATRIX_JSON_STRING="{\"include\":["
for each_test_file_server in $(echo "$TEST_FILE_SERVER" | sed "s/;/ /g"); do
  test_file=$(echo "$each_test_file_server" | cut -d "(" -f1)
  for test_server in $(echo "$each_test_file_server" | cut -d "(" -f2 | cut -d ")" -f1 | sed "s/,/ /g"); do
    MATRIX_JSON_STRING="$MATRIX_JSON_STRING{\"test\":\"$test_file\",\"server\":\"marist-$test_server\"},"
  done
done

# remove trailing comma
MATRIX_JSON_STRING=$(echo $MATRIX_JSON_STRING | sed 's/,$//g')

MATRIX_JSON_STRING="$MATRIX_JSON_STRING]}"
echo "matrix=$MATRIX_JSON_STRING" >>$GITHUB_OUTPUT
