#!/bin/sh

################################################################################
# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
################################################################################

# Assign default values that will be filled in as we parse the yaml file

echo "Reading install variables from zowe-install-apf-server.yaml"

parseConfiguationFile() {
while read line
do
    key=${line%%"="*}
    lineLength=${#line}
    keyLength=${#key}
    lastCharacter=$(echo $line | tail -c 2)
    firstCharacter=$(echo $line | head -c 1)
    valueLength=`expr $lineLength - $keyLength`
    value=$(echo $line | tail -c $valueLength | head -c `expr $valueLength - 1`)
    # Ignore comments if the first characater is a #
    if [[ ! $firstCharacter == "#" ]]
    then
        # Look for lines ending in :
        # these are the headings.  There are three, install-path and node-server
        if [[ $lastCharacter == ":" ]]
        then
            headingLength=`expr $lineLength - 1`
            heading=$(echo $line | head -c $headingLength)
            section=$heading
        # If we are not a heading then look for one of three key=value pairings
        # rootDir if we are part of the install-path
        else
        # Look for rootDir= beneath install:
            if [[ $section == "install" ]]
            then
                if [[ $key == "proclib" ]] && [[ $value != "" ]]
                then
                    XMEM_PROCLIB=$value
                    echo "  APF server PROCLIB dataset="${XMEM_PROCLIB}
                fi
                if [[ $key == "parmlib" ]] && [[ $value != "" ]]
                then
                    XMEM_PARMLIB=$value
                    echo "  APF server PARMLIB dataset="${XMEM_PARMLIB}
                fi
                if [[ $key == "loadlib" ]] && [[ $value != "" ]]
                then
                    XMEM_LOADLIB=$value
                    echo "  APF server LOADLIB dataset="${XMEM_LOADLIB}
                fi
                if [[ $key == "zssServerName" ]] && [[ $value != "" ]]
                then
                    XMEM_SERVER_NAME=$value
                    echo "  APF server NAME="${XMEM_SERVER_NAME}
                fi                
            fi
            if [[ $section == "users" ]]
            then
                if [[ $key == "stcUser" ]] && [[ $value != "" ]]
                then
                    XMEM_STC_USER=$value
                    echo "  APF server STC user="${XMEM_STC_USER}
                fi
                if [[ $key == "stcUserUid" ]] && [[ $value != "" ]]
                then
                    XMEM_STC_USER_UID=$value
                    echo "  APF server STC user UID="${XMEM_STC_USER_UID}
                fi
                if [[ $key == "zoweUser" ]] && [[ $value != "" ]]
                then
                    ZOWE_USER=$value
                    echo "  User to run Zowe server="${ZOWE_USER}
                fi
                if [[ $key == "stcGroup" ]] && [[ $value != "" ]]
                then
                    XMEM_STC_GROUP=$value
                    echo "  STC user group="${XMEM_STC_GROUP}
                fi
                if [[ $key == "tssFacilityOwner" ]] && [[ $value != "" ]]
                then
                    if [[ $value = "auto" ]]
                    then
                        ZOWE_TSS_FAC_OWNER=`id -u -n`
                    else
                        ZOWE_TSS_FAC_OWNER=$value
                    fi
                    echo "  TSS Facility Owner(if applicable)="${ZOWE_TSS_FAC_OWNER}
                fi
            fi
        fi
    fi
#    echo "--- End of loop ---"
done < $1
}
parseConfiguationFile ./zowe-install-apf-server.yaml


XMEM_ELEMENT_ID=ZWES

# If the values are not set default them
if [[ ${XMEM_PROCLIB} == "" ]]
then
    echo "  ERROR: APF server PROCLIB dataset not specified, exiting"
    exit 1
fi
if [[ ${XMEM_PARMLIB} == "" ]]
then
    XMEM_PARMLIB=${USER}.PARMLIB
    echo "  APF server PARMLIB dataset: defaulting to ${XMEM_PARMLIB}"
fi
if [[ ${XMEM_LOADLIB} == "" ]]
then
    XMEM_LOADLIB=${USER}.LOADLIB
    echo "  APF server LOADLIB dataset: defaulting to ${XMEM_LOADLIB}"
fi
if [[ ${XMEM_SERVER_NAME} == "" ]]
then
    XMEM_SERVER_NAME=ZWESIS_STD
    echo "  APF server SERVER NAME defaulting to ${XMEM_SERVER_NAME}"
fi
if [[ ${ZOWE_USER} == "" ]]
then
    echo "  ERROR: User to run Zowe server not specified, exiting"
    exit 1
fi
if [[ ${XMEM_STC_USER_UID} == "" ]]
then
    echo "  APF server STC user UID not specified"
fi
if [[ ${XMEM_STC_USER} == "" ]]
then
    XMEM_STC_USER=ZWESISTC
    echo "  APF server STC user: defaulting to ZWESISTC"
fi
if [[ ${XMEM_STC_GROUP} == "" ]]
then
    echo "  STC user group not specified"
fi
if [[ ${ZOWE_TSS_FAC_OWNER} == "" ]]
then
    echo "  ERROR: TSS Facility Owner not specified, exiting. If you are not running TSS, please set this field to 'auto'."
    exit 1
fi
