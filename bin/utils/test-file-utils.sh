#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

. file-utils.sh

tests=0
test(){
  let "tests=$tests+1"
}

failures=0
failed() {
  let "failures=$failures+1"
}

assert_equals() {
  test
  expected=$1
  actual=$2
  message=$3

  if [[ "${actual}" != "${expected}" ]] then
    echo "${message} - ${expected} != ${actual}"
    failed
  fi 
}

###### Test get_full_path

# Test home directory is expanded
input="~/test"
expected="$HOME/test"
get_full_path "${input}" actual
assert_equals ${expected} ${actual} "Home expansion of ${input} to ${expected} failed."

# Test full path not modified
input="$PWD"
expected="$input"
get_full_path "${input}" actual
assert_equals ${expected} ${actual} "Full path ${input} should be unchanged."

# Test relative path
CHILD_DIR="child_123124"
TEST_DIR="test_dir123124"
input="../${TEST_DIR}"
expected="$PWD/$TEST_DIR"
mkdir -p "child" && cd "child"
get_full_path "${input}" temp
mkdir -p ${temp}
actual=$(cd ${temp};pwd)
assert_equals ${expected} ${actual} "Relative path ${input} should be expanded to ${expected}."
cd ../ && rm -rf ${CHILD_DIR}


##### Summary

echo "Ran ${tests} tests with ${failures} failures"

exit ${failures}