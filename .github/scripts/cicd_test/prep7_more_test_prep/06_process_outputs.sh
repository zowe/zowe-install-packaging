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

# Set outputs
echo ::set-output name=ZOWE_ARTIFACTORY_FINAL::$ZOWE_ARTIFACTORY_FINAL
echo ::set-output name=ZOWE_ARTIFACTORY_FINAL_FILENAME::$ZOWE_ARTIFACTORY_FINAL_FILENAME
echo ::set-output name=NODE_HOME_PATTERN::/ZOWE/node/node-$ZOS_NODE_VERSION-os390-s390x
echo ::set-output name=TEST_SERVER::$TEST_SERVER
echo ::set-output name=TEST_SERVER_NICKNAME::$TEST_SERVER_NICKNAME
echo ::set-output name=EXTENSION_LIST::$EXTENSION_LIST
echo ::set-output name=ZOWE_CLI_ARTIFACTORY_FINAL::$ZOWE_CLI_ARTIFACTORY_FINAL

# Echo all processed outputs
echo
echo "#######################Summary of outputs:#######################"
printf "Zowe artifactory path: ${CYAN}$ZOWE_ARTIFACTORY_FINAL${NC}\n"
printf "Zowe artifactory file name: ${CYAN}$ZOWE_ARTIFACTORY_FINAL_FILENAME${NC}\n"
printf "Zowe CLI artifactory path: ${CYAN}$ZOWE_CLI_ARTIFACTORY_FINAL${NC}\n"
printf "Zowe extension list: ${CYAN}$EXTENSION_LIST${NC}\n"
printf "Test server: ${CYAN}$TEST_SERVER${NC}\n"
printf "Test server nickname: ${CYAN}$TEST_SERVER_NICKNAME${NC}\n"
printf "Node home pattern on z/OS: ${CYAN}/ZOWE/node/node-$ZOS_NODE_VERSION-os390-s390x${NC}\n"