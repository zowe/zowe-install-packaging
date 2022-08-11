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

if [[ "$MATRIX_TEST" == *"install-ext"* ]]; then
    EXTENSION_LIST=
    if [[ -z "$CUSTOM_EXTENSION_LIST" ]]; then
        printf "${RED}[Check 4 ERROR] You are running install-ext test, but input 'custom-extension-list' is missing\n"
        exit 1
    fi

    # validate extension list input
    if [[ "$CUSTOM_EXTENSION_LIST" =~ ^([^;()]+(\([^;()]+\))*)(;[^;()]+(\([^;()]+\))*)*$ ]]; then
        echo "[Check 4 INFO] Extension list syntax validation success!"
    else
        printf "${RED}[Check 4 ERROR] Extension list validation failed\n"
        printf "${RED}[Check 4 ERROR] You must follow the format: {ext-name}[({custom-ext-pattern})][;...]\n"
        printf "${RED}[Check 4 ERROR] Example input will be\n"
        printf "${RED}[Check 4 ERROR] sample-ext;sample-ext2;sample-myext\n"
        printf "${RED}[Check 4 ERROR] sample-ext(myown/path);sample-myext\n"
        exit 1
    fi

    for each_ext in $(echo "$CUSTOM_EXTENSION_LIST" | sed "s/;/ /g")
    do
        echo "[Check 4 INFO] Now processing $each_ext ..."
        if [[ "$each_ext" == *"("* ]] && [[ "$each_ext" == *")"* ]] ; then
            # user provides custom artifactory pattern
            ext_name=$(echo "$each_ext" | cut -d "(" -f1)
            ext_pattern=$(echo "$each_ext" | cut -d "(" -f2 | cut -d ")" -f1)
        else
            # use default
            ext_name="$each_ext"
            ext_pattern=$(echo "$DEFAULT_ZOWE_EXT_ARTIFACTORY_PATTERN" | sed "s#{ext-name}#$ext_name#g")
        fi

        echo "[Check 4 INFO] extension name is $ext_name"
        echo "[Check 4 INFO] extension pattern before jfrog search is $ext_pattern"

        if [[ "$ext_pattern" != *"http"* ]]; then
            ext_full_path=$(jfrog_search_latest $ext_pattern)
        else
            ext_full_path=$ext_pattern
        fi
        echo "[Check 4 INFO] extension full path after jfrog search is $ext_full_path"
        EXTENSION_LIST="$EXTENSION_LIST$ext_name($ext_full_path);"
    done

    # remove trailing comma
    EXTENSION_LIST=$(echo $EXTENSION_LIST | sed 's/;$//g')
    assert_env_var EXTENSION_LIST
    printf "${GREEN}[Check 4/$TOTAL_CHECK] Zowe extension list processing complete!${NC}\n"
fi