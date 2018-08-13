#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

# Assign default values that will be filled in as we parse the yaml file

echo "<zowe-parse-yaml.sh>" >> $LOG_FILE 

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
# these are the headings.  There are three, install-path, liberty-server and node-server
       if [[ $lastCharacter == ":" ]]
       then
            headingLength=`expr $lineLength - 1`
            heading=$(echo $line | head -c $headingLength)
            section=$heading
# If we are not a heading then look for one of three key=value pairings
# rootDir if we are part of the install-path
# httpPort or httpsPort if we are part of the node-server or liberty-server
        else
# Look for rootDir= beneath install:
            if [[ $key == "rootDir" ]] && [[ $section == "install" ]]
            then
# If the value starts with a ~ for the home variable then evaluate it
                ZOWE_ROOT_DIR=`sh -c "echo $value"` 
                echo "  Zowe runtime root directory="$ZOWE_ROOT_DIR
                export ZOWE_ROOT_DIR
            fi
# Look for httpPort= beneath libertyServer:
            if [[ $key == "httpPort" ]] && [[ $section == "explorer-server" ]] 
            then
                ZOWE_EXPLORER_SERVER_HTTP_PORT=$value
                echo "  explorer-server http port="$ZOWE_EXPLORER_SERVER_HTTP_PORT
                export ZOWE_EXPLORER_SERVER_HTTP_PORT
            fi
# Look for httpSPort= beneath libertyServer:
            if [[ $key == "httpsPort" ]] && [[ $section == "explorer-server" ]] 
            then
                ZOWE_EXPLORER_SERVER_HTTPS_PORT=$value
                echo "  explorer-server https port="$ZOWE_EXPLORER_SERVER_HTTPS_PORT              
                export ZOWE_EXPLORER_SERVER_HTTPS_PORT
            fi
# Look for httpPort= beneath zlux-server:
            if [[ $key == "httpPort" ]] && [[ $section == "zlux-server" ]] 
            then
                ZOWE_ZLUX_SERVER_HTTP_PORT=$value
               echo "  zlux-server http port"=$ZOWE_ZLUX_SERVER_HTTP_PORT
                export ZOWE_ZLUX_SERVER_HTTP_PORT
            fi
# Look for httpsPort= beneath zlux-server:
            if [[ $key == "httpsPort" ]] && [[ $section == "zlux-server" ]] 
            then
                ZOWE_ZLUX_SERVER_HTTPS_PORT=$value
                echo "  zlux-server https port="$ZOWE_ZLUX_SERVER_HTTPS_PORT
                export ZOWE_ZLUX_SERVER_HTTPS_PORT
            fi
# Look for httpsPort= beneath zlux-server:
            if [[ $key == "zssPort" ]] && [[ $section == "zlux-server" ]] 
            then
                ZOWE_ZSS_SERVER_PORT=$value
                echo "  zss server http port="$ZOWE_ZSS_SERVER_PORT
                export ZOWE_ZSS_SERVER_PORT
            fi
# Look for sshPort= beneath terminals:
            if [[ $key == "sshPort" ]] && [[ $section == "terminals" ]] 
            then
                ZOWE_ZLUX_SSH_PORT=$value
                export ZOWE_ZLUX_SSH_PORT
            fi
# Look for telnetPort= beneath libertyServer:
            if [[ $key == "telnetPort" ]] && [[ $section == "terminals" ]] 
            then
                ZOWE_ZLUX_TELNET_PORT=$value
                export ZOWE_ZLUX_TELNET_PORT
            fi
# api-mediation ports
            if [[ $key == "catalogHttpPort" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_CATALOG_HTTP_PORT=$value
                echo "  api-mediation catalog http port="$ZOWE_APIM_CATALOG_HTTP_PORT
                export ZOWE_APIM_CATALOG_HTTP_PORT
            fi
            if [[ $key == "discoveryHttpPort" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_DISCOVERY_HTTP_PORT=$value
                echo "  api-mediation discovery http port="$ZOWE_APIM_DISCOVERY_HTTP_PORT
                export ZOWE_APIM_DISCOVERY_HTTP_PORT
            fi
            if [[ $key == "gatewayHttpsPort" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_GATEWAY_HTTPS_PORT=$value
                echo "  api-mediation gateway https port="$ZOWE_APIM_GATEWAY_HTTPS_PORT
                export ZOWE_APIM_GATEWAY_HTTPS_PORT
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
    $ZOWE_ROOT_DIR = "~/zowe/0.9.0"
    echo "  ZOWE_ROOT_DIR not specified:  Defaulting to ~/zowe/0.9.0"
fi
if [[ $ZOWE_EXPLORER_SERVER_HTTP_PORT == "" ]]
then
    $ZOWE_EXPLORER_SERVER_HTTP_PORT = 7080
    echo "  ZOWE_EXPLORER_SERVER_HTTP_PORT not specified:  Defaulting to 7080"
fi
if [[ $ZOWE_EXPLORER_SERVER_HTTPS_PORT == "" ]]
then
    $ZOWE_EXPLORER_SERVER_HTTPS_PORT = 7443
    echo "  ZOWE_EXPLORER_SERVER_HTTPS_PORT not specified:  Defaulting to 7443"
fi
if [[ $ZOWE_ZLUX_SERVER_HTTPS_PORT == "" ]]
then
    $ZOWE_ZLUX_SERVER_HTTPS_PORT = 8544
    echo "  ZOWE_ZLUX_SERVER_HTTPS_PORT not specified:  Defaulting to 8544"
fi
if [[ $ZOWE_ZLUX_SERVER_HTTP_PORT == "" ]]
then
    $ZOWE_ZLUX_SERVER_HTTP_PORT = 8543
    echo "  ZOWE_ZLUX_SERVER_HTTP_PORT not specified:  Defaulting to 8543"
fi
if [[ $ZOWE_ZSS_SERVER_PORT == "" ]]
then
    $ZOWE_ZSS_SERVER_PORT = 8542
    echo "  ZOWE_ZSS_SERVER_PORT not specified:  Defaulting to 8542"
fi
if [[ ZOWE_APIM_CATALOG_HTTP_PORT == "" ]]
then
    $ZOWE_APIM_CATALOG_HTTP_PORT = 7552
    echo "  ZOWE_APIM_CATALOG_HTTP_PORT not specified:  Defaulting to 7552"
fi
if [[ ZOWE_APIM_DISCOVERY_HTTP_PORT == "" ]]
then
    $ZOWE_APIM_DISCOVERY_HTTP_PORT = 7553
    echo "  ZOWE_APIM_DISCOVERY_HTTP_PORT not specified:  Defaulting to 7553"
fi
if [[ ZOWE_APIM_GATEWAY_HTTPS_PORT == "" ]]
then
    $ZOWE_APIM_GATEWAY_HTTPS_PORT = 7554
    echo "  ZOWE_APIM_GATEWAY_HTTPS_PORT not specified:  Defaulting to 7554"
fi
# Do not echo the ssh and terminal ports because unlike the others, that Zowe needs free to alllocate and use
# The ssh and telnet ports are there and already being used and exploited by the apps
# and echoing them may create confusion
if [[ $ZOWE_ZLUX_SSH_PORT == "" ]]
then
    $ZOWE_ZLUX_SSH_PORT = 22
fi
if [[ $ZOWE_ZLUX_TELNET_PORT == "" ]]
then
    $ZOWE_ZLUX_TELNET_PORT = 23
fi

echo "  ZOWE_ROOT_DIR="$ZOWE_ROOT_DIR >> $LOG_FILE
echo "  ZOWE_EXPLORER_SERVER_HTTP_PORT="$ZOWE_EXPLORER_SERVER_HTTPS_PORT >> $LOG_FILE
echo "  ZOWE_EXPLORER_SERVER_HTTPS_PORT="$ZOWE_EXPLORER_SERVER_HTTPS_PORT >> $LOG_FILE
echo "  ZOWE_ZLUS_SERVER_HTTP_PORT="$ZOWE_ZLUX_SERVER_HTTPS_PORT >> $LOG_FILE
echo "  ZOWE_ZLUX_SERVER_HTTPS_PORT="$ZOWE_ZLUX_SERVER_HTTPS_PORT >> $LOG_FILE
echo "  ZOWE_ZSS_SERVER_PORT="$ZOWE_ZLUX_SERVER_HTTPS_PORT >> $LOG_FILE
echo "  ZOWE_ZLUX_SSH_PORT="$ZOWE_ZLUX_SSH_PORT >> $LOG_FILE
echo "  ZOWE_ZLUX_TELNET_PORT="$ZOWE_ZLUX_TELNET_PORT >> $LOG_FILE
echo "  ZOWE_APIM_CATALOG_HTTP_PORT="$ZOWE_APIM_GATEWAY_HTTP_PORT >> $LOG_FILE
echo "  ZOWE_APIM_DISCOVERY_HTTP_PORT="$ZOWE_APIM_GATEWAY_HTTP_PORT >> $LOG_FILE
echo "  ZOWE_APIM_GATEWAY_HTTPS_PORT="$ZOWE_APIM_GATEWAY_HTTPS_PORT >> $LOG_FILE
echo "</zowe-parse-yaml.sh>" >> $LOG_FILE
