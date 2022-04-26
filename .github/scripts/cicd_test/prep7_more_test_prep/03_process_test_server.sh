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

TEST_SERVER=$(echo "$MATRIX_SERVER" | cut -d "-" -f2)

case $TEST_SERVER in

"zzow02")
    TEST_SERVER_NICKNAME=marist-2
    ;;

"zzow03")
    TEST_SERVER_NICKNAME=marist-3
    ;;

"zzow04")
    TEST_SERVER_NICKNAME=marist-4
    ;;

*)
    printf "${RED}[Check 2 ERROR] Something went wrong when parsing test server nickname\n"
    exit 1
    ;;
esac

assert_env_var "TEST_SERVER"
assert_env_var "TEST_SERVER_NICKNAME"
printf "${GREEN}[Check 2/$TOTAL_CHECK] Test server name processing complete!${NC}\n"