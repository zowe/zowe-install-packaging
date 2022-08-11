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

if [[ "$MATRIX_TEST" == *"install-docker"* ]]; then
    if [[ -n "$ZOWE_ARTIFACTORY_FINAL" ]]; then
        # note that in here, $ZOWE_ARTIFACTORY_FINAL must be pax because smpe.zip should already be ruled out and fail before reaching here
        # get the build name and build number of the zowe pax we processed.
        json_output=$(jfrog rt search "$ZOWE_ARTIFACTORY_FINAL")
        processed_zowe_art_bldname=$(echo "$json_output" | jq -r '.[].props."build.name"[]')
        processed_zowe_art_bldnum=$(echo "$json_output" | jq -r '.[].props."build.number"[]')
        
        # then get branch name from the build name returned above
        # build name should be either 'zowe-install-packaging/branchname' (GHA) or 'zowe-install-packaging :: branchname' (Jenkins)
        processed_zowe_art_branchname=$(echo "$processed_zowe_art_bldname" | sed "s|zowe-install-packaging/||g")
        if [[ "$processed_zowe_art_branchname" == "$processed_zowe_art_bldname" ]]; then
            # means above sed replacement command didn't work, forward slash does not exists, highly likely this build is made from jenkins
            # try with colon colon as some builds are published from jenkins in the past and expecting to have colon colon in the build name
            processed_zowe_art_branchname=$(echo "$processed_zowe_art_bldname" | sed "s|zowe-install-packaging :: ||g")
            if [[ "$processed_zowe_art_branchname" == "$processed_zowe_art_bldname" ]]; then
                printf "${RED}[Check ${TOTAL_CHECK} ERROR] Unable to parse branch name from $processed_zowe_art_bldname as it is not a valid build name.\n"
                printf "${RED}[Check ${TOTAL_CHECK} ERROR] Just for the record, the zowe artifactory path is $ZOWE_ARTIFACTORY_FINAL\n"
                exit 1
            fi
        fi

        echo "[Check ${TOTAL_CHECK} INFO] Zowe artifactory full path earlier is $ZOWE_ARTIFACTORY_FINAL"
        echo "[Check ${TOTAL_CHECK} INFO] The build name got from above is $processed_zowe_art_bldname"
        echo "[Check ${TOTAL_CHECK} INFO] The build number got from above is $processed_zowe_art_bldnum"
        echo "[Check ${TOTAL_CHECK} INFO] The branch name got from above is $processed_zowe_art_branchname"
        echo "[Check ${TOTAL_CHECK} INFO] We will use build number parsed $processed_zowe_art_bldnum to search if docker build exists in the same build."

        # now use processed build name and build number to search the docker artifact associated with it
        if [[ -n "$processed_zowe_art_bldname" ]] && [[ -n "$processed_zowe_art_bldnum" ]] && [[ -n "$processed_zowe_art_branchname" ]]; then
            if [[ "$processed_zowe_art_branchname" =~ ^v([0-9])\.x\/master$ ]] ; then
                zowe_tp_docker_artifactory_pattern=$(echo "$DEFAULT_ZOWE_TP_DOCKER_ARTIFACTORY_PATTERN" | sed "s#{branch-name}#${BASH_REMATCH[1]}.*snapshot#g")
            elif [[ "$processed_zowe_art_branchname" =~ ^v([0-9])\.x\/rc$ ]] ; then
                zowe_tp_docker_artifactory_pattern=$(echo "$DEFAULT_ZOWE_TP_DOCKER_ARTIFACTORY_PATTERN" | sed "s#{branch-name}#${BASH_REMATCH[1]}.*rc#g")
            elif [[ "$processed_zowe_art_branchname" =~ ^v([0-9])\.x\/staging$ ]] ; then
                zowe_tp_docker_artifactory_pattern=$(echo "$DEFAULT_ZOWE_TP_DOCKER_ARTIFACTORY_PATTERN" | sed "s#{branch-name}#${BASH_REMATCH[1]}.*staging#g")
            else
                processed_zowe_art_branchname=$(echo "$processed_zowe_art_branchname" | sed "s#\/#-#g")
                zowe_tp_docker_artifactory_pattern=$(echo "$DEFAULT_ZOWE_TP_DOCKER_ARTIFACTORY_PATTERN" | sed "s#{branch-name}#$processed_zowe_art_branchname#g")
            fi

            echo "[Check ${TOTAL_CHECK} INFO] TP docker artifactory pattern is $zowe_tp_docker_artifactory_pattern"
            ZOWE_TP_DOCKER_ARTIFACTORY=$(jfrog_search_build "$zowe_tp_docker_artifactory_pattern" "$processed_zowe_art_bldname" "$processed_zowe_art_bldnum")
            ZOWE_TP_DOCKER_ARTIFACTORY_URL="https://zowe.jfrog.io/zowe/$ZOWE_TP_DOCKER_ARTIFACTORY"
        else
            printf "${RED}[Check ${TOTAL_CHECK} ERROR] Either the parsing of build name, build number or branch name of $ZOWE_ARTIFACTORY_FINAL failed.\n"
            exit 1
        fi
    else
        printf "${RED}[Check ${TOTAL_CHECK} ERROR] Zowe artifactory full path is not processed properly. This is extremely rare.\n"
        exit 1
    fi

    # try to know if this docker artifact searched comes from an older build and gives warning
    if [[ "$ZOWE_TP_DOCKER_ARTIFACTORY" == *"server-bundle.amd64"*tar ]]; then
        tpdocker_out=$(jfrog rt search "$ZOWE_TP_DOCKER_ARTIFACTORY")
        tpdocker_bld_name=$(echo "$tpdocker_out" | jq -r '.[].props."build.name"[]')
        tpdocker_bld_num=$(echo "$tpdocker_out" | jq -r '.[].props."build.number"[]')

        # encode '/' or ' ' in tpdocker build name to avoid confusion for jfrog REST API
        if [[ "$tpdocker_bld_name" == *"/"* ]]; then
            tpdocker_bld_name_encoded=$(echo "$tpdocker_bld_name" | sed "s|/|\%2F|g")
        elif [[ "$tpdocker_bld_name" == *"::"* ]]; then
            tpdocker_bld_name_encoded=$(echo "$tpdocker_bld_name" | sed "s| |\%20|g")
        fi

        latest_pax_bld_num=$(jfrog rt curl -s -XGET "/api/build/$tpdocker_bld_name_encoded" | jq '.buildsNumbers[0].uri' | sed "s|/||g" | sed "s|\"||g" )

        if [[ "$latest_pax_bld_num" != "$tpdocker_bld_num" ]]; then            
            printf "${YELLOW}[Check $TOTAL_CHECK WARNING] I see that you are trying to grab an older docker build $tpdocker_bld_num on $tpdocker_bld_name.\n"
            printf "${YELLOW}[Check $TOTAL_CHECK WARNING] However just be aware that there are more code changes (newer builds) after $tpdocker_bld_num, which is $latest_pax_bld_num.\n"
            printf "${YELLOW}[Check $TOTAL_CHECK WARNING] You should always test latest code on your branch unless you want to compare with older builds for regression.\n"            
        fi
    fi

    assert_env_var ZOWE_TP_DOCKER_ARTIFACTORY_URL
    printf "${GREEN}[Check $TOTAL_CHECK/$TOTAL_CHECK] Zowe tech preview docker artifactory full path processing complete!${NC}\n"
fi