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

if [[ -n "$INPUT_CUSTOM_ZOWE_ART_PAT_OR_BLDNUM" ]]; then
    if [[ "$INPUT_CUSTOM_ZOWE_ART_PAT_OR_BLDNUM" =~ ^[0-9]+$ ]]; then
        echo "[Check 1 INFO] Build number $INPUT_CUSTOM_ZOWE_ART_PAT_OR_BLDNUM is entered"
        custom_build_number=$INPUT_CUSTOM_ZOWE_ART_PAT_OR_BLDNUM
        use_defaut=true
    elif [[ "$INPUT_CUSTOM_ZOWE_ART_PAT_OR_BLDNUM" =~ ^.+\/.+$ ]]; then
        echo "[Check 1 INFO] Custom artifactory pattern is entered, now figuring out pax or smpe..."
        custom_pattern=$INPUT_CUSTOM_ZOWE_ART_PAT_OR_BLDNUM

        # first extract the filename of the artifactory path to avoid string check confusion in later steps
        # filename is after the last forward slash
        file_name=${custom_pattern##*/}

        if [[ "$MATRIX_TEST" == *install-fmid.ts ]] || [[ "$MATRIX_TEST" == *install-ptf.ts ]]; then
            if [[ "$file_name" == *"zowe-smpe"*zip ]] ; then
                # if it is valid *zowe-smpe*.zip format, and test run is smpe related, we will hornour this custom input
                zowe_artifactory_pattern_interim="$custom_pattern"
                echo "[Check 1 INFO] SMPE!"
            else
                printf "${RED}[Check 1 ERROR] You are running smpe related test but the file name included in your custom zowe artifactory pattern is not a proper *zowe-smpe*.zip format\n"
                exit 1
            fi
        else
            if [[ "$file_name" == *"zowe"* ]] && [[ "$file_name" == *pax ]]; then
                # if it is valid *zowe*.pax format, and test run is not smpe related, we will hornour this custom input
                zowe_artifactory_pattern_interim="$custom_pattern"
                echo "[Check 1 INFO] PAX!"
            else
                printf "${RED}[Check 1 ERROR] You are running pax related test but the file name included in your custom zowe artifactory pattern is not a proper *zowe*.pax format\n"
                exit 1
            fi
        fi
    else
        printf "${RED}[Check 1 ERROR] You should enter either a build number on current running branch or a proper zowe artifactory pattern\n"
        printf "${RED}[Check 1 ERROR] Examples:\n"
        printf "${RED}[Check 1 ERROR] 491 meaning build number 491 on $CURRENT_BRANCH\n"
        printf "${RED}[Check 1 ERROR] my/path/to/file\n"
        exit 1
    fi
else
    use_defaut=true
fi

if [[ -n "$use_defaut" ]]; then
    if [[ "$MATRIX_TEST" == *install-fmid.ts ]] || [[ "$MATRIX_TEST" == *install-ptf.ts ]]; then
        zowe_artifactory_pattern_interim="$DEFAULT_ZOWE_SMPE_ARTIFACTORY_PATTERN"
    else
        zowe_artifactory_pattern_interim="$DEFAULT_ZOWE_PAX_ARTIFACTORY_PATTERN"
    fi      
fi

echo "[Check 1 INFO] Interim zowe artifactory pattern is $zowe_artifactory_pattern_interim"

# note that below if-else does not always get to run the sed part, as we only replace if {branch-name} exists in the pattern,
#   which isn't the case for customized path. In either case, $zowe_artifactory_pattern_final should be filled
if [[ "$CURRENT_BRANCH_NEW" =~ ^v([0-9])\.x-master$ ]] ; then
    zowe_artifactory_pattern_final=$(echo "$zowe_artifactory_pattern_interim" | sed "s#{branch-name}#${BASH_REMATCH[1]}.*snapshot#g")
elif [[ "$CURRENT_BRANCH_NEW" =~ ^v([0-9])\.x-staging$ ]] ; then
    zowe_artifactory_pattern_final=$(echo "$zowe_artifactory_pattern_interim" | sed "s#{branch-name}#${BASH_REMATCH[1]}.*staging#g")
elif [[ "$CURRENT_BRANCH_NEW" =~ ^v([0-9])\.x-rc$ ]] ; then
    zowe_artifactory_pattern_final=$(echo "$zowe_artifactory_pattern_interim" | sed "s#{branch-name}#${BASH_REMATCH[1]}.*rc#g")
else
    zowe_artifactory_pattern_final=$(echo "$zowe_artifactory_pattern_interim" | sed "s#{branch-name}#$CURRENT_BRANCH_NEW#g")
fi

echo "[Check 1 INFO] Final zowe artifactory pattern (before jfrog search) is $zowe_artifactory_pattern_final"

if [[ -z "$custom_build_number" ]]; then
    # we will search the latest build exists on current running branch
    ZOWE_ARTIFACTORY_FINAL=$(jfrog_search_latest $zowe_artifactory_pattern_final)
else
    # we will search according to the build number provided (on current running branch)
    ZOWE_ARTIFACTORY_FINAL=$(jfrog_search_build $zowe_artifactory_pattern_final "zowe-install-packaging/$CURRENT_BRANCH" $custom_build_number)
fi

# try to know if this SMPE artifact comes from latest or older build
if [[ "$ZOWE_ARTIFACTORY_FINAL" == *"zowe-smpe"*zip ]]; then
    smpe_out=$(jfrog rt search "$ZOWE_ARTIFACTORY_FINAL")
    smpe_bld_name=$(echo "$smpe_out" | jq -r '.[].props."build.name"[]')
    smpe_bld_num=$(echo "$smpe_out" | jq -r '.[].props."build.number"[]')

    # encode '/' or ' ' in smpe build name as they may be confusing for jfrog REST API
    if [[ "$smpe_bld_name" == *"/"* ]]; then
        smpe_bld_name_encoded=$(echo "$smpe_bld_name" | sed "s|/|\%2F|g")
    elif [[ "$smpe_bld_name" == *"::"* ]]; then
        smpe_bld_name_encoded=$(echo "$smpe_bld_name" | sed "s| |\%20|g")
    fi

    latest_pax_bld_num=$(jfrog rt curl -s -XGET "/api/build/$smpe_bld_name_encoded" | jq '.buildsNumbers[0].uri' | sed "s|/||g" | sed "s|\"||g" )

    if [[ "$latest_pax_bld_num" != "$smpe_bld_num" ]]; then
        if [[ -z "$INPUT_CUSTOM_ZOWE_ART_PAT_OR_BLDNUM" ]]; then
            # when no custom input, we will throw error and fail the build
            printf "${RED}[Check 1 ERROR] Latest build $latest_pax_bld_num on current branch does not contain a SMPE artifact.\n"
            printf "${RED}[Check 1 ERROR] If you want to test install smpe, you should make sure latest build has SMPE packaged.\n"
            printf "${RED}[Check 1 ERROR] Please specify exact build number on $smpe_bld_name or any other smpe.zip artifactory path.\n"
            printf "${RED}[Check 1 ERROR] FYI latest build that contains SMPE artifact is $smpe_bld_num\n"
            exit 1
        else
            # when there is custom input, we will give warnings instead but still proceed
            printf "${YELLOW}[Check 1 WARNING] I see that you are trying to grab an older SMPE build $smpe_bld_num on $smpe_bld_name.\n"
            printf "${YELLOW}[Check 1 WARNING] However just be aware that there are more code changes (newer builds) after $smpe_bld_num, which is $latest_pax_bld_num.\n"
            printf "${YELLOW}[Check 1 WARNING] You should always test latest code on your branch unless you want to compare with older builds for regression.\n"
        fi
    fi
fi

# next line is just to get the pax file name - extract the part after last occurance of slash
ZOWE_ARTIFACTORY_FINAL_FILENAME=${ZOWE_ARTIFACTORY_FINAL##*/}

assert_env_var "ZOWE_ARTIFACTORY_FINAL"
assert_env_var "ZOWE_ARTIFACTORY_FINAL_FILENAME"
printf "${GREEN}[Check 1/$TOTAL_CHECK] Zowe pax or smpe.zip artifactory full path processing complete!${NC}\n"
