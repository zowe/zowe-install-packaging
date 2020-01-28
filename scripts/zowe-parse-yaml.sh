#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

# Assign default values that will be filled in as we parse the yaml file

echo "<zowe-parse-yaml.sh>" >> $LOG_FILE 
echo "Reading variables from zowe-install.yaml"

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
# Ignore comments if the first character is a #
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
            if [[ $key == "rootDir" ]] && [[ $section == "install" ]]
            then
# If the value starts with a ~ for the home variable then evaluate it
                ZOWE_ROOT_DIR=`sh -c "echo $value"` 
                export ZOWE_ROOT_DIR
            fi    
# Look for datasetPrefix= beneath install:
            if [[ $key == "datasetPrefix" ]] && [[ $section == "install" ]]
            then
                ZOWE_DSN_PREFIX=`echo "$value" | sed "s/{userid}/${USER:-${USERNAME:-${LOGNAME}}}/"`
                export ZOWE_DSN_PREFIX
            fi      
            if [[ $key == "zoweAdminGroup" ]] && [[ $section == "install" ]]
            then
                ZOWE_GROUP=$value
                export ZOWE_GROUP
            fi
        fi
    fi
#    echo "--- End of loop ---"
done < $1
}
parseConfiguationFile ./zowe-install.yaml

# If the values are not set default them
if [[ $ZOWE_ROOT_DIR == "" ]] 
then
    ZOWE_ROOT_DIR="~/zowe/$ZOWE_VERSION"
    echo "  ZOWE_ROOT_DIR not specified:  Defaulting to ~/zowe/$ZOWE_VERSION" | tee -a $LOG_FILE
fi
if [[ $ZOWE_GROUP == "" ]]
then
    ZOWE_GROUP="IZUADMIN"
    echo "  ZOWE_GROUP not specified:  Defaulting to IZUADMIN" | tee -a $LOG_FILE
fi 

echo "  ZOWE_ROOT_DIR="$ZOWE_ROOT_DIR >> $LOG_FILE
echo "  ZOWE_DSN_PREFIX="$ZOWE_DSN_PREFIX >> $LOG_FILE
echo "  ZOWE_GROUP="$ZOWE_GROUP >> $LOG_FILE
echo "</zowe-parse-yaml.sh>" >> $LOG_FILE
