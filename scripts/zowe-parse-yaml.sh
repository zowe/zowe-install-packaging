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
# Look for zssPort= beneath zlux-server:
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
# Look for telnetPort= beneath terminals:
            if [[ $key == "telnetPort" ]] && [[ $section == "terminals" ]] 
            then
                ZOWE_ZLUX_TELNET_PORT=$value
                export ZOWE_ZLUX_TELNET_PORT
            fi
# Look for explorerJESUI= beneath explorer-ui:
            if [[ $key == "explorerJESUI" ]] && [[ $section == "explorer-ui" ]] 
            then
                ZOWE_EXPLORER_JES_UI_PORT=$value
                echo "  JES explorer UI https port="$ZOWE_EXPLORER_JES_UI_PORT
                export ZOWE_EXPLORER_JES_UI_PORT
            fi
# Look for explorerMVSUI= beneath explorer-ui:
            if [[ $key == "explorerMVSUI" ]] && [[ $section == "explorer-ui" ]] 
            then
                ZOWE_EXPLORER_MVS_UI_PORT=$value
                echo "  MVS explorer UI https port="$ZOWE_EXPLORER_MVS_UI_PORT
                export ZOWE_EXPLORER_MVS_UI_PORT
            fi
# Look for explorerUSSUI= beneath explorer-ui:
            if [[ $key == "explorerUSSUI" ]] && [[ $section == "explorer-ui" ]] 
            then
                ZOWE_EXPLORER_USS_UI_PORT=$value
                echo "  USS explorer UI https port="$ZOWE_EXPLORER_USS_UI_PORT
                export ZOWE_EXPLORER_USS_UI_PORT
            fi
# Look for security= beneath terminals:
            if [[ $key == "security" ]] && [[ $section == "terminals" ]] 
            then
                ZOWE_ZLUX_SECURITY_TYPE=$value
                echo "  zowe zlux security type="$ZOWE_ZLUX_SECURITY_TYPE
                export ZOWE_ZLUX_SECURITY_TYPE
            fi
# api-mediation settings:
            if [[ $key == "catalogPort" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_CATALOG_PORT=$value
                echo "  api-mediation catalog port="$ZOWE_APIM_CATALOG_PORT
                export ZOWE_APIM_CATALOG_HTTP_PORT
            fi
            if [[ $key == "discoveryPort" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_DISCOVERY_PORT=$value
                echo "  api-mediation discovery port="$ZOWE_APIM_DISCOVERY_PORT
                export ZOWE_APIM_DISCOVERY_PORT
            fi
            if [[ $key == "gatewayPort" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_GATEWAY_PORT=$value
                echo "  api-mediation gateway port="$ZOWE_APIM_GATEWAY_PORT
                export ZOWE_APIM_GATEWAY_PORT
            fi
            if [[ $key == "externalCertificate" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_EXTERNAL_CERTIFICATE=$value
                echo "  api-mediation external certificate="$ZOWE_APIM_EXTERNAL_CERTIFICATE
                export ZOWE_APIM_EXTERNAL_CERTIFICATE
            fi
            if [[ $key == "externalCertificateAlias" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS=$value
                echo "  api-mediation external certificate alias="$ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS
                export ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS
            fi
            if [[ $key == "externalCertificateAuthorities" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES=$value
                echo "  api-mediation external certificate authorities="$ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES
                export ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES
            fi
            if [[ $key == "verifyCertificatesOfServices" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_VERIFY_CERTIFICATES=$value
                echo "  api-mediation verify certificates of services="$ZOWE_APIM_VERIFY_CERTIFICATES
                export ZOWE_APIM_VERIFY_CERTIFICATES
            fi

            if [[ $key == "dsName" ]] && [[ $section == "zowe-server-proclib" ]]
            then
                ZOWE_SERVER_PROCLIB_DSNAME=$value
                echo "  server PROCLIB dataset name="$ZOWE_SERVER_PROCLIB_DSNAME
                export ZOWE_SERVER_PROCLIB_DSNAME
            fi
            if [[ $key == "memberName" ]] && [[ $section == "zowe-server-proclib" ]]
            then
                ZOWE_SERVER_PROCLIB_MEMBER=$value
                echo "  server PROCLIB member name="$ZOWE_SERVER_PROCLIB_MEMBER
                export ZOWE_SERVER_PROCLIB_MEMBER
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
    echo "  ZOWE_ROOT_DIR not specified:  Defaulting to ~/zowe/$ZOWE_VERSION"
fi
if [[ $ZOWE_EXPLORER_SERVER_HTTP_PORT == "" ]]
then
    ZOWE_EXPLORER_SERVER_HTTP_PORT=7080
    echo "  ZOWE_EXPLORER_SERVER_HTTP_PORT not specified:  Defaulting to 7080"
fi
if [[ $ZOWE_EXPLORER_SERVER_HTTPS_PORT == "" ]]
then
    ZOWE_EXPLORER_SERVER_HTTPS_PORT=7443
    echo "  ZOWE_EXPLORER_SERVER_HTTPS_PORT not specified:  Defaulting to 7443"
fi
if [[ $ZOWE_ZLUX_SERVER_HTTPS_PORT == "" ]]
then
    ZOWE_ZLUX_SERVER_HTTPS_PORT=8544
    echo "  ZOWE_ZLUX_SERVER_HTTPS_PORT not specified:  Defaulting to 8544"
fi
if [[ $ZOWE_ZLUX_SERVER_HTTP_PORT == "" ]]
then
    ZOWE_ZLUX_SERVER_HTTP_PORT=8543
    echo "  ZOWE_ZLUX_SERVER_HTTP_PORT not specified:  Defaulting to 8543"
fi
if [[ $ZOWE_ZSS_SERVER_PORT == "" ]]
then
    ZOWE_ZSS_SERVER_PORT=8542
    echo "  ZOWE_ZSS_SERVER_PORT not specified:  Defaulting to 8542"
fi
if [[ $ZOWE_EXPLORER_JES_UI_PORT == "" ]]
then
    ZOWE_ZSS_SERVER_PORT=8546
    echo "  ZOWE_EXPLORER_JES_UI_PORT not specified:  Defaulting to 8546"
fi
if [[ $ZOWE_EXPLORER_MVS_UI_PORT == "" ]]
then
    ZOWE_EXPLORER_MVS_UI_PORT=8548
    echo "  ZOWE_EXPLORER_MVS_UI_PORT not specified:  Defaulting to 8548"
fi
if [[ $ZOWE_EXPLORER_USS_UI_PORT == "" ]]
then
    ZOWE_EXPLORER_USS_UI_PORT=8550
    echo "  ZOWE_EXPLORER_USS_UI_PORT not specified:  Defaulting to 8550"
fi
if [[ $ZOWE_APIM_CATALOG_PORT == "" ]]
then
    ZOWE_APIM_CATALOG_PORT=7552
    echo "  ZOWE_APIM_CATALOG_PORT not specified:  Defaulting to 7552"
fi
if [[ $ZOWE_APIM_DISCOVERY_PORT == "" ]]
then
    ZOWE_APIM_DISCOVERY_PORT=7553
    echo "  ZOWE_APIM_DISCOVERY_PORT not specified:  Defaulting to 7553"
fi
if [[ $ZOWE_APIM_GATEWAY_PORT == "" ]]
then
    ZOWE_APIM_GATEWAY_PORT=7554
    echo "  ZOWE_APIM_GATEWAY_PORT not specified:  Defaulting to 7554"
fi
if [[ $ZOWE_APIM_VERIFY_CERTIFICATES == "" ]]
then
    ZOWE_APIM_VERIFY_CERTIFICATES="true"
    echo "  ZOWE_APIM_VERIFY_CERTIFICATES not specified:  Defaulting to true"
fi
# Do not echo the ssh and terminal ports because unlike the others, that Zowe needs free to alllocate and use
# The ssh and telnet ports are there and already being used and exploited by the apps
# and echoing them may create confusion
if [[ $ZOWE_ZLUX_SSH_PORT == "" ]]
then
    ZOWE_ZLUX_SSH_PORT=22
fi
if [[ $ZOWE_ZLUX_TELNET_PORT == "" ]]
then
    ZOWE_ZLUX_TELNET_PORT=23
fi 
if [[ $ZOWE_SERVER_PROCLIB_MEMBER == "" ]]
then
    ZOWE_SERVER_PROCLIB_MEMBER=ZOWESVR 
    echo "  ZOWE_SERVER_PROCLIB_MEMBER not specified:  Defaulting to ZOWESVR"
fi
if [[ $ZOWE_SERVER_PROCLIB_DSNAME == "" ]]
then
    ZOWE_SERVER_PROCLIB_DSNAME=auto
    echo "  ZOWE_SERVER_PROCLIB_DSNAME not specified:  PROCLIB DSNAME will be selected automatically"
fi

echo "  ZOWE_ROOT_DIR="$ZOWE_ROOT_DIR >> $LOG_FILE
echo "  ZOWE_EXPLORER_SERVER_HTTP_PORT="$ZOWE_EXPLORER_SERVER_HTTP_PORT >> $LOG_FILE
echo "  ZOWE_EXPLORER_SERVER_HTTPS_PORT="$ZOWE_EXPLORER_SERVER_HTTPS_PORT >> $LOG_FILE
echo "  ZOWE_ZLUX_SERVER_HTTP_PORT="$ZOWE_ZLUX_SERVER_HTTP_PORT >> $LOG_FILE
echo "  ZOWE_ZLUX_SERVER_HTTPS_PORT="$ZOWE_ZLUX_SERVER_HTTPS_PORT >> $LOG_FILE
echo "  ZOWE_ZSS_SERVER_PORT="$ZOWE_ZSS_SERVER_PORT >> $LOG_FILE
echo "  ZOWE_ZLUX_SSH_PORT="$ZOWE_ZLUX_SSH_PORT >> $LOG_FILE
echo "  ZOWE_ZLUX_TELNET_PORT="$ZOWE_ZLUX_TELNET_PORT >> $LOG_FILE
echo "  ZOWE_EXPLORER_JES_UI_PORT="$ZOWE_EXPLORER_JES_UI_PORT >> $LOG_FILE
echo "  ZOWE_EXPLORER_MVS_UI_PORT="$ZOWE_EXPLORER_MVS_UI_PORT >> $LOG_FILE
echo "  ZOWE_EXPLORER_USS_UI_PORT="$ZOWE_EXPLORER_USS_UI_PORT >> $LOG_FILE
echo "  ZOWE_ZLUX_SECURITY_TYPE="$ZOWE_ZLUX_SECURITY_TYPE >> $LOG_FILE
echo "  ZOWE_APIM_CATALOG_PORT="$ZOWE_APIM_CATALOG_PORT >> $LOG_FILE
echo "  ZOWE_APIM_DISCOVERY_PORT="$ZOWE_APIM_DISCOVERY_PORT >> $LOG_FILE
echo "  ZOWE_APIM_GATEWAY_PORT="$ZOWE_APIM_GATEWAY_PORT >> $LOG_FILE
echo "  ZOWE_APIM_EXTERNAL_CERTIFICATE="$ZOWE_APIM_EXTERNAL_CERTIFICATE >> $LOG_FILE
echo "  ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS="$ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS >> $LOG_FILE
echo "  ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES="$ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES >> $LOG_FILE
echo "  ZOWE_APIM_VERIFY_CERTIFICATES="$ZOWE_APIM_VERIFY_CERTIFICATES >> $LOG_FILE
echo "  ZOWE_APIM_CATALOG_HTTP_PORT="$ZOWE_APIM_CATALOG_HTTP_PORT >> $LOG_FILE
echo "  ZOWE_APIM_DISCOVERY_HTTP_PORT="$ZOWE_APIM_DISCOVERY_HTTP_PORT >> $LOG_FILE
echo "  ZOWE_APIM_GATEWAY_HTTPS_PORT="$ZOWE_APIM_GATEWAY_HTTPS_PORT >> $LOG_FILE
echo "  ZOWE_SERVER_PROCLIB_MEMBER="$ZOWE_SERVER_PROCLIB_MEMBER >> $LOG_FILE
echo "  ZOWE_SERVER_PROCLIB_DSNAME="$ZOWE_SERVER_PROCLIB_DSNAME >> $LOG_FILE
echo "</zowe-parse-yaml.sh>" >> $LOG_FILE
