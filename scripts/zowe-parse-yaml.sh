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
            if [[ $key == "rootDir" ]] && [[ $section == "install" ]]
            then
# If the value starts with a ~ for the home variable then evaluate it
                ZOWE_ROOT_DIR=`sh -c "echo $value"` 
                export ZOWE_ROOT_DIR
            fi
# Look for prefix= beneath install:
            if [[ $key == "prefix" ]] && [[ $section == "install" ]]
            then
                ZOWE_PREFIX=$value
                export ZOWE_PREFIX
            fi
# Look for instance= beneath install:
            if [[ $key == "instance" ]] && [[ $section == "install" ]]
            then
                ZOWE_INSTANCE=$value
                export ZOWE_INSTANCE
            fi            
# Look for jobsAPIPort= beneath zos-services:
            if [[ $key == "jobsAPIPort" ]] && [[ $section == "zos-services" ]] 
            then
                ZOWE_EXPLORER_SERVER_JOBS_PORT=$value
                export ZOWE_EXPLORER_SERVER_JOBS_PORT
            fi
# Look for mvsAPIPort= beneath zos-services:
            if [[ $key == "mvsAPIPort" ]] && [[ $section == "zos-services" ]] 
            then
                ZOWE_EXPLORER_SERVER_DATASETS_PORT=$value
                export ZOWE_EXPLORER_SERVER_DATASETS_PORT
            fi
# Look for httpsPort= beneath zlux-server:
            if [[ $key == "httpsPort" ]] && [[ $section == "zlux-server" ]] 
            then
                ZOWE_ZLUX_SERVER_HTTPS_PORT=$value
                export ZOWE_ZLUX_SERVER_HTTPS_PORT
            fi
# Look for zssPort= beneath zlux-server:
            if [[ $key == "zssPort" ]] && [[ $section == "zlux-server" ]] 
            then
                ZOWE_ZSS_SERVER_PORT=$value
                export ZOWE_ZSS_SERVER_PORT
            fi
# Look for privilegedServerName= beneath zlux-server:
            if [[ $key == "zssCrossMemoryServerName" ]] && [[ $section == "zlux-server" ]] 
            then
                ZOWE_ZSS_XMEM_SERVER_NAME=$value
                export ZOWE_ZSS_XMEM_SERVER_NAME
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
# Look for jobsExplorerPort= beneath zowe-desktop-apps:
            if [[ $key == "jobsExplorerPort" ]] && [[ $section == "zowe-desktop-apps" ]] 
            then
                ZOWE_EXPLORER_JES_UI_PORT=$value
                export ZOWE_EXPLORER_JES_UI_PORT
            fi
# Look for mvsExplorerPort= beneath zowe-desktop-apps:
            if [[ $key == "mvsExplorerPort" ]] && [[ $section == "zowe-desktop-apps" ]] 
            then
                ZOWE_EXPLORER_MVS_UI_PORT=$value
                export ZOWE_EXPLORER_MVS_UI_PORT
            fi
# Look for ussExplorerPort= beneath zowe-desktop-apps:
            if [[ $key == "ussExplorerPort" ]] && [[ $section == "zowe-desktop-apps" ]] 
            then
                ZOWE_EXPLORER_USS_UI_PORT=$value
                export ZOWE_EXPLORER_USS_UI_PORT
            fi
# Look for security= beneath terminals:
            if [[ $key == "security" ]] && [[ $section == "terminals" ]] 
            then
                ZOWE_ZLUX_SECURITY_TYPE=$value
                export ZOWE_ZLUX_SECURITY_TYPE
            fi
# api-mediation settings:
            if [[ $key == "catalogPort" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_CATALOG_PORT=$value
                export ZOWE_APIM_CATALOG_HTTP_PORT
            fi
            if [[ $key == "discoveryPort" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_DISCOVERY_PORT=$value
                export ZOWE_APIM_DISCOVERY_PORT
            fi
            if [[ $key == "gatewayPort" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_GATEWAY_PORT=$value
                export ZOWE_APIM_GATEWAY_PORT
            fi
            if [[ $key == "externalCertificate" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_EXTERNAL_CERTIFICATE=$value
                export ZOWE_APIM_EXTERNAL_CERTIFICATE
            fi
            if [[ $key == "externalCertificateAlias" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS=$value
                export ZOWE_APIM_EXTERNAL_CERTIFICATE_ALIAS
            fi
            if [[ $key == "externalCertificateAuthorities" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES=$value
                export ZOWE_APIM_EXTERNAL_CERTIFICATE_AUTHORITIES
            fi
            if [[ $key == "verifyCertificatesOfServices" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_VERIFY_CERTIFICATES=$value
                export ZOWE_APIM_VERIFY_CERTIFICATES
            fi
            if [[ $key == "enableSso" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_APIM_ENABLE_SSO=$value
                export ZOWE_APIM_ENABLE_SSO
            fi
            if [[ $key == "zosmfKeyring" ]] && [[ $section == "api-mediation" ]]
            then
                ZOWE_ZOSMF_KEYRING=$value
                export ZOWE_ZOSMF_KEYRING
            fi

            if [[ $key == "zosmfUserid" ]] && [[ $section == "zosmf" ]]
            then
                ZOWE_ZOSMF_USERID=$value
                export ZOWE_ZOSMF_USERID
            fi
            if [[ $key == "zosmfAdminGroup" ]] && [[ $section == "zosmf" ]]
            then
                ZOWE_ZOSMF_ADMIN_GROUP=$value
                export ZOWE_ZOSMF_ADMIN_GROUP
            fi

            if [[ $key == "dsName" ]] && [[ $section == "zowe-server-proclib" ]]
            then
                ZOWE_SERVER_PROCLIB_DSNAME=$value
                export ZOWE_SERVER_PROCLIB_DSNAME
            fi
            if [[ $key == "memberName" ]] && [[ $section == "zowe-server-proclib" ]]
            then
                ZOWE_SERVER_PROCLIB_MEMBER=$value
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
if [[ $ZOWE_PREFIX == "" ]]
then
    ZOWE_PREFIX="ZOWE"
    echo "  ZOWE_PREFIX not specified:  Defaulting to ZOWE"
fi
if [[ $ZOWE_INSTANCE == "" ]]
then
    ZOWE_INSTANCE="1"
    echo "  ZOWE_INSTANCE not specified:  Defaulting to 1"
fi
if [[ $ZOWE_EXPLORER_SERVER_JOBS_PORT == "" ]]
then
    ZOWE_EXPLORER_SERVER_JOBS_PORT=7080
    echo "  ZOWE_EXPLORER_SERVER_JOBS_PORT not specified:  Defaulting to 7080"
fi
if [[ $ZOWE_EXPLORER_SERVER_DATASETS_PORT == "" ]]
then
    ZOWE_EXPLORER_SERVER_DATASETS_PORT=8547
    echo "  ZOWE_EXPLORER_SERVER_DATASETS_PORT not specified:  Defaulting to 8547"
fi
if [[ $ZOWE_ZLUX_SERVER_HTTPS_PORT == "" ]]
then
    ZOWE_ZLUX_SERVER_HTTPS_PORT=8544
    echo "  ZOWE_ZLUX_SERVER_HTTPS_PORT not specified:  Defaulting to 8544"
fi
if [[ $ZOWE_ZSS_SERVER_PORT == "" ]]
then
    ZOWE_ZSS_SERVER_PORT=8542
    echo "  ZOWE_ZSS_SERVER_PORT not specified:  Defaulting to 8542"
fi
if [[ $ZOWE_ZSS_XMEM_SERVER_NAME == "" ]]
then
    ZOWE_ZSS_XMEM_SERVER_NAME=ZWESIS_STD
    echo "  ZOWE_ZSS_XMEM_SERVER_NAME not specified:  Defaulting to ZWESIS_STD"
fi
if [[ $ZOWE_EXPLORER_JES_UI_PORT == "" ]]
then
    ZOWE_EXPLORER_JES_UI_PORT=8546
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
if [[ $ZOWE_APIM_ENABLE_SSO == "" ]]
then
    ZOWE_APIM_ENABLE_SSO="false"
    echo "  ZOWE_APIM_ENABLE_SSO not specified:  Defaulting to false"
fi
if [[ $ZOWE_ZOSMF_KEYRING == "" ]]
then
    ZOWE_ZOSMF_KEYRING="IZUKeyring.IZUDFLT"
    echo "  ZOWE_ZOSMF_KEYRING not specified:  Defaulting to IZUKeyring.IZUDFLT"
fi
if [[ $ZOWE_ZOSMF_USERID == "" ]]
then
    ZOWE_ZOSMF_USERID="IZUSVR"
    echo "  ZOWE_ZOSMF_USERID not specified:  Defaulting to IZUSVR"
fi
if [[ $ZOWE_ZOSMF_ADMIN_GROUP == "" ]]
then
    ZOWE_ZOSMF_ADMIN_GROUP="IZUADMIN"
    echo "  ZOWE_ZOSMF_ADMIN_GROUP not specified:  Defaulting to IZUADMIN"
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
echo "  ZOWE_PREFIX="$ZOWE_PREFIX >> $LOG_FILE
echo "  ZOWE_ZLUX_SERVER_HTTPS_PORT="$ZOWE_ZLUX_SERVER_HTTPS_PORT >> $LOG_FILE
echo "  ZOWE_EXPLORER_SERVER_JOBS_PORT="$ZOWE_EXPLORER_SERVER_JOBS_PORT >> $LOG_FILE
echo "  ZOWE_EXPLORER_SERVER_DATASETS_PORT="$ZOWE_EXPLORER_SERVER_DATASETS_PORT >> $LOG_FILE
echo "  ZOWE_ZSS_SERVER_PORT="$ZOWE_ZSS_SERVER_PORT >> $LOG_FILE
echo "  ZOWE_ZSS_XMEM_SERVER_NAME="$ZOWE_ZSS_XMEM_SERVER_NAME >> $LOG_FILE
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
echo "  ZOWE_APIM_ENABLE_SSO="$ZOWE_APIM_ENABLE_SSO >> $LOG_FILE
echo "  ZOWE_ZOSMF_KEYRING="$ZOWE_ZOSMF_KEYRING >> $LOG_FILE
echo "  ZOWE_ZOSMF_USERID="$ZOWE_ZOSMF_USERID >> $LOG_FILE
echo "  ZOWE_ZOSMF_ADMIN_GROUP="$ZOWE_ZOSMF_ADMIN_GROUP >> $LOG_FILE
echo "  ZOWE_APIM_CATALOG_HTTP_PORT="$ZOWE_APIM_CATALOG_HTTP_PORT >> $LOG_FILE
echo "  ZOWE_APIM_DISCOVERY_HTTP_PORT="$ZOWE_APIM_DISCOVERY_HTTP_PORT >> $LOG_FILE
echo "  ZOWE_APIM_GATEWAY_HTTPS_PORT="$ZOWE_APIM_GATEWAY_HTTPS_PORT >> $LOG_FILE
echo "  ZOWE_SERVER_PROCLIB_MEMBER="$ZOWE_SERVER_PROCLIB_MEMBER >> $LOG_FILE
echo "  ZOWE_SERVER_PROCLIB_DSNAME="$ZOWE_SERVER_PROCLIB_DSNAME >> $LOG_FILE
echo "</zowe-parse-yaml.sh>" >> $LOG_FILE
