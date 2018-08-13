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


#TODO - Get the host name working correctly
#TODO - Get the script to try and locate the 64 bit Java 8

# The environment variables
# ZOWE_ZOSMF_PATH    points to the /lib directory of the zOSMF install
# ZOWE_JAVA_HOME points to Java to be used
# ZOWE_SDSF_PATH points to SDSF location
# ZOWE_EXPLORER_HOST points to the current host name
# NODE_HOME points to the node directory

# This script checks to see whether they are set, and if not tries to locate them, 
# and if they can't be found prompt for them before setting them

echo "<zowe-init.sh>" >> $LOG_FILE


#set-x
export ZOWE_ZOSMF_PATH
export ZOWE_JAVA_HOME
export ZOWE_EXPLORER_HOST
export NODE_HOME

if [[ $PROFILE == "" ]]
then    
    PROFILE=".profile"
fi

if [[ ! -f $PROFILE ]]
then
    touch $PROFILE
fi

. ~/$PROFILE > /dev/null

# Run the .profile so that any set environment variables from a previous install 
# in the same shell are not set again.  send results to /dev/null to squelch any output
# so the user sees a clean log
# . ~/$PROFILE  > /dev/null
# Failure to run the script causes the install to abort

locateZOSMFBootstrapProperties() {
# $1$2$3$4 together are the full path to an expected bootstrap.properties file used to create a symlink
    if [[ -f $1$2$3$4 ]] 
    then
        echo "  Liberty "$4" found  at "$1$2$3
        ZOWE_ZOSMF_PATH=$1$2$3
        persist "ZOWE_ZOSMF_PATH" $1$2$3
    else 
# on some machines the user may not have permission to look into $3, in which case if $1$2 exists set the variable
# as the symlink permission will be allowed by the IZUUSR user ID that starts the explorer-server
        echo "  Unable to determine whether "$1$2$3$4 "exists"
        echo "  This may be because the current user is not authorized to look into "$1$2
        echo "  The runtime user for the liberty-server needs to have sufficient authority"
        ZOWE_ZOSMF_PATH=$1$2$3
        persist "ZOWE_ZOSMF_PATH" $1$2$3
    fi
}

promptNodeHome(){
loop=1
while [ $loop -eq 1 ]
do
    echo "    NODE_HOME was not set "
    echo "    Please enter a path to where node is installed.  This is the a directory that contains /bin/node "
    read NODE_HOME
    if [[ -f $NODE_HOME/"./bin/node" ]] 
    then
        persist "NODE_HOME" $NODE_HOME
        loop=0
    else
        echo "        No /bin/node found in directory "$NODE_HOME
        echo "        Press Y or y to accept location, or Enter to choose another location"
        read rep
        if [ "$rep" = "Y" ] || [ "$rep" = "y" ]
        then
            persist "NODE_HOME" $NODE_HOME
            loop=0
        fi
    fi
done
}

javaVersion=-1
locateJavaHome() {
    getJavaVersion $1
    if [ "$javaVersion" -ge "18" ]
        then
            echo "   java version $version found at " $1
            persist "ZOWE_JAVA_HOME" $1
        else
            loop=1
            while [ $loop -eq 1 ]
            do
                echo "    Please enter home directory where Java 8, or newer is installed.  This is the a directory that contains /bin/java"
                read ZOWE_JAVA_HOME
                getJavaVersion $ZOWE_JAVA_HOME
                if [ "$javaVersion" = "-1" ]
                    then
                        echo "        No executable file found in $ZOWE_JAVA_HOME/bin/java"
                        echo "        Press Y or y to accept location, or Enter to choose another location"
                        read rep
                        if [ "$rep" = "Y" ] || [ "$rep" = "y" ]
                            then
                                persist "ZOWE_JAVA_HOME" $ZOWE_JAVA_HOME
                                loop=0
                        fi
                    else
                        if [ "$javaVersion" -lt "18" ]
                            then
                                echo "        The version of java at $ZOWE_JAVA_HOME is $version, and must be Java 8, or newer"
                                echo "        Press Y or y to accept location, or Enter to choose another location"
                                read rep
                                if [ "$rep" = "Y" ] || [ "$rep" = "y" ]
                                    then
                                        persist "ZOWE_JAVA_HOME" $ZOWE_JAVA_HOME
                                        loop=0
                                fi
                            else
                                persist "ZOWE_JAVA_HOME" $ZOWE_JAVA_HOME
                                loop=0
                        fi
                fi
            done
    fi
}

getJavaVersion() {
    java_bin="$1/bin/java"
    if [[ -x $java_bin ]]; then
        version=$("$java_bin" -version 2>&1 | sed -n ';s/.* version "\(.*\)\.\(.*\)\..*"/\1\2/p;')
        javaVersion=$version
    else
        javaVersion=-1
    fi
}

persist() {
    echo "** Adding line: export "$1"="$2" to "~/$PROFILE " **"
    echo "** Adding line: export "$1"="$2" to "~/$PROFILE " **" >> $LOG_FILE
    echo "export $1="$2 >> ~/$PROFILE
}

# Run the main shell script logic
echo "Locating z/OSMF ..."
if [[ $ZOWE_ZOSMF_PATH == "" ]]
then
    locateZOSMFBootstrapProperties "/var/zosmf/" "configuration" "/servers/zosmfServer/" "bootstrap.properties"
else 
    echo "ZOWE_ZOSMF_PATH value of "$ZOWE_ZOSMF_PATH" will be used"
    echo "  ZOWE_ZOSMF_PATH variable value="$ZOWE_ZOSMF_PATH >> $LOG_FILE
fi

echo "Locating Java Home ..."
if [[ $ZOWE_JAVA_HOME == "" ]]
then    
    locateJavaHome "/usr/lpp/java/J8.0_64"
else    
    echo "ZOWE_JAVA_HOME value of "$ZOWE_JAVA_HOME" will be used"
    echo "  ZOWE_JAVA_HOME variable value="$ZOWE_JAVA_HOME >> $LOG_FILE
fi

echo "Locating Node Home ..."
if [[ $NODE_HOME == "" ]]
then
    promptNodeHome
else
    echo "NODE_HOME value of "$NODE_HOME" will be used"
    echo "  NODE_HOME environment variable was set="$NODE_HOME >> $LOG_FILE
fi

echo "Locating host name ..."
if [[ $ZOWE_EXPLORER_HOST == "" ]]
then
    ZOWE_EXPLORER_HOST=$(hostname -c)
    persist "ZOWE_EXPLORER_HOST" $ZOWE_EXPLORER_HOST
else    
    echo "ZOWE_EXPLORER_HOST value of "$ZOWE_EXPLORER_HOST" will be used"
    echo "  ZOWE_EXPLORER_HOST variable value="$ZOWE_EXPLORER_HOST >> $LOG_FILE
fi

echo "Locating host IP Address..."
if [[ $ZOWE_IPADDRESS == "" ]]
then
    ZOWE_IPADDRESS=$(host ${ZOWE_EXPLORER_HOST} | sed 's/.*addresses\ //g')
    persist "ZOWE_IPADDRESS" $ZOWE_IPADDRESS
else
    echo "ZOWE_IPADDRESS value of "$ZOWE_IPADDRESS" will be used"
    echo " ZOWE_IPADDRESS variable value="$ZOWE_IPADDRESS >> $LOG_FILE
fi
echo "</zowe-init.sh>" >> $LOG_FILE
