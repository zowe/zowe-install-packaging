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

if [[ -z "$CUSTOM_ZOWE_CLI_ARTIFACTORY_PATTERN" ]]; then
    zowe_cli_artifactory_pattern="$DEFAULT_ZOWE_CLI_ARTIFACTORY_PATTERN"
    # determine if we shall use libs-snapshot-local or libs-release-local
    if [[ "$CURRENT_BRANCH" =~ ^v([0-9])\.x\/rc$ ]] || [[ "$CURRENT_BRANCH" =~ ^v([0-9])\.x\/master$ ]] ; then
        zowe_cli_artifactory_pattern=$(echo "$zowe_cli_artifactory_pattern" | sed "s#PLACE_HOLDER#libs-release-local#g")
    else
        zowe_cli_artifactory_pattern=$(echo "$zowe_cli_artifactory_pattern" | sed "s#PLACE_HOLDER#libs-snapshot-local#g")
    fi
else
    zowe_cli_artifactory_pattern="$CUSTOM_ZOWE_CLI_ARTIFACTORY_PATTERN"
fi

echo "[Check 3 INFO] Zowe cli artifactory pattern before jfrog search is $zowe_cli_artifactory_pattern"

ZOWE_CLI_ARTIFACTORY_FINAL=$(jfrog_search_latest $zowe_cli_artifactory_pattern)
assert_env_var ZOWE_CLI_ARTIFACTORY_FINAL
printf "${GREEN}[Check 3/$TOTAL_CHECK] Zowe CLI artifactory full path processing complete!${NC}\n"
