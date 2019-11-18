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

# TODO - review this and see if we can tidy it up

# The environment variables
# ZOWE_ZOSMF_PORT https port of the zOSMF server
# ZOWE_JAVA_HOME points to Java to be used
# ZOWE_EXPLORER_HOST points to the current host name
# ZOWE_IP_ADDRESS is the external IP address of the host ZOWE_EXPLORER_HOST where Zowe is installed 
# ZOWE_NODE_HOME points to the node directory

# This script checks to see whether they are set, and if not tries to locate them, 
# and if they can't be found prompt for them before setting them

echo "<zowe-init.sh>" >> $LOG_FILE

#set-x

getZosmfHttpsPort() {
    ZOWE_ZOSMF_PORT=`netstat -b -E IZUSVR1 2>/dev/null|grep .*Listen | awk '{ print $4 }'`
    if [[ "$ZOWE_ZOSMF_PORT" == "" ]]
    then
        echo "    Unable to detect z/OS MF HTTPS port"
        echo "    Please enter the HTTPS port of z/OS MF server on this system"
        read ZOWE_ZOSMF_PORT
    fi
    export ZOWE_ZOSMF_PORT
}

promptNodeHome(){
loop=1
while [ $loop -eq 1 ]
do
    if [[ "$ZOWE_NODE_HOME" == "" ]]
    then
        echo "    ZOWE_NODE_HOME was not set "
        echo "    Please enter a path to where node is installed.  This is the a directory that contains /bin/node "
        read ZOWE_NODE_HOME
    fi
    if [[ -f $ZOWE_NODE_HOME/"./bin/node" ]] 
    then
        export ZOWE_NODE_HOME=$ZOWE_NODE_HOME
        loop=0
    else
        echo "        No /bin/node found in directory "$ZOWE_NODE_HOME
        echo "        Press Y or y to accept location, or Enter to choose another location"
        read rep
        if [ "$rep" = "Y" ] || [ "$rep" = "y" ]
        then
            export ZOWE_NODE_HOME=$ZOWE_NODE_HOME
            loop=0
        else
            ZOWE_NODE_HOME=
        fi
    fi
done
}

javaVersion=-1
locateJavaHome() {
    getJavaVersion $1
    if [ "$javaVersion" -ge "18" ]
        then
            echo "   java version $version found at " $1 >> $LOG_FILE
            export ZOWE_JAVA_HOME=$1
        else
            if [ "$javaVersion" = "-1" ]
            then
                echo "    No executable file found in $1/bin/java"
            else
                echo "    The version of java at $1 is $version, and must be Java 8, or newer"
            fi
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
                                export ZOWE_JAVA_HOME
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
                                        export ZOWE_JAVA_HOME
                                        loop=0
                                fi
                            else
                                export ZOWE_JAVA_HOME
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

getPing_bin() {
#  Identifies name of ping command if ping is not available oping is used
#  populates ping_bin variable with ping or oping
    ping -h 2>/dev/null 1>/dev/null
    if [[ $? -eq 0 ]]
    then
        ping_bin=ping
    else
        echo "Warning: ping command not found trying oping"
        oping -h 2>/dev/null 1>/dev/null
        if [[ $? -eq 0 ]]
        then
            ping_bin=oping
        else
            echo "Error: neither ping nor oping has not been found, add folder with ping or oping on \$PATH, normally they are in /bin"
        fi
    fi
}

# Run the main shell script logic
if [[ $ZOWE_ZOSMF_PORT == "" ]]
then
    getZosmfHttpsPort
else 
    echo "  ZOWE_ZOSMF_PORT variable value="$ZOWE_ZOSMF_PORT >> $LOG_FILE
fi

if [[ $ZOWE_JAVA_HOME == "" ]]
then
    if [[ -z ${JAVA_HOME} ]]
    then
        ZOWE_JAVA_HOME=/usr/lpp/java/J8.0_64
    else
        ZOWE_JAVA_HOME=${JAVA_HOME}
    fi
else    
    echo "  ZOWE_JAVA_HOME variable value="$ZOWE_JAVA_HOME >> $LOG_FILE
fi
locateJavaHome $ZOWE_JAVA_HOME

if [[ $ZOWE_NODE_HOME == "" ]]
then
    if [[ -z ${NODE_HOME} ]]
    then
        ZOWE_NODE_HOME=/usr/lpp/java/J8.0_64
    else
        ZOWE_NODE_HOME=${NODE_HOME}
    fi
else    
    echo "  ZOWE_NODE_HOME variable value="$ZOWE_JAVA_HOME >> $LOG_FILE
fi
promptNodeHome

###identify ping
getPing_bin

if [[ $ZOWE_EXPLORER_HOST == "" ]]
then
    # ZOWE_EXPLORER_HOST=$(hostname -c)
    hn=`hostname`
    rc=$?
    if [[ -n "$hn" && $rc -eq 0 ]]
    then
        full_hostname=`$ping_bin $hn|sed -n 's/.* host \(.*\) (.*/\1/p'`
        if [[ $? -eq 0 && -n "$full_hostname" ]]
        then
            ZOWE_EXPLORER_HOST=$full_hostname
        else
            echo Error: $ping_bin $hn command failed to find hostname
        fi
    else
        echo Error: hostname command returned non-zero RC $rc or empty string
    fi

    if [[ ! -n "$ZOWE_EXPLORER_HOST" ]]
    then
        echo "    Please enter the ZOWE_EXPLORER_HOST of this system"
        read ZOWE_EXPLORER_HOST
    fi 
    export ZOWE_EXPLORER_HOST
else    
    echo "  ZOWE_EXPLORER_HOST variable value="$ZOWE_EXPLORER_HOST >> $LOG_FILE
fi

# Check hostname can be resolved
checkHostnameResolves() {
if [[ $# -ne 2 ]]
then
    return 4
fi

hostname=$1
ip=$2

# return codes
# 0 - OK
# 1 - ping didn't match stated IP
# 2 - dig found hostname and IP but IP didn't match stated IP
# 3 - dig didn't find hostname
# 4 - ip parameter or hostname parameter is an empty string

# Does PING of hostname yield correct IP?
$ping_bin $hostname | grep $ip 1> /dev/null
if [[ $? -eq 0 ]]
then
        # echo ip $ip is OK
        # Does DIG of hostname yield correct IP?
        dig $hostname | grep -i "^$hostname.*$ip" 1> /dev/null
        if [[ $? -eq 0 ]]
        then
            # echo dig is OK
            return 0
        else
            # what's wrong with dig?
            dig $hostname | grep -i "^$hostname" 1> /dev/null
            if [[ $? -eq 0 ]]
            then
                # echo dig is OK
                # echo ERROR: dig of hostname found hostname but does not resolve to external IP $ip
                return 2
            else
                # echo ERROR: dig of hostname does not resolve to external IP $ip
                return 3
            fi
        fi
else
        # echo ERROR: $ping_bin of hostname `hostname` does not resolve to external IP $ip
        return 1
fi
}

if [[ $ZOWE_IP_ADDRESS == "" ]]
then
    # host may return aliases, which may result in ZOWE_IP_ADDRESS with value of "10.1.1.2 EZZ8322I aliases: S0W1"
    # EZZ8321I S0W1.DAL-EBIS.IHOST.COM has addresses 10.1.1.2
    # EZZ8322I aliases: S0W1
    hn=`hostname`
    rc=$?
    if [[ -n "$hn" && $rc -eq 0 ]]
    then
          ZOWE_IP_ADDRESS=`$ping_bin $hn|sed -n 's/.* (\(.*\)).*/\1/p'`
          if [[ ! -n "$ZOWE_IP_ADDRESS" ]]
          then
               echo Error: $ping_bin $hn command failed to find IP
          fi
    else
        echo Error: hostname command returned non-zero RC $rc or empty string
    fi

    checkHostnameResolves $ZOWE_EXPLORER_HOST $ZOWE_IP_ADDRESS
    rc=$?
    case $rc in
        0)        echo OK resolved $ZOWE_EXPLORER_HOST to $ZOWE_IP_ADDRESS >> $LOG_FILE
        ;;
        1)        echo error : "$ping_bin $ZOWE_EXPLORER_HOST did not match stated IP address $ZOWE_IP_ADDRESS"
        ;;
        2)        echo error : "dig found hostname $ZOWE_EXPLORER_HOST and IP but IP did not match $ZOWE_IP_ADDRESS"
        ;;
        3)        echo error : "dig could not find IP of hostname $ZOWE_EXPLORER_HOST"
        ;;
        4)        echo error : ZOWE_EXPLORER_HOST or ZOWE_IP_ADDRESS is an empty string
        ;;    
    esac
    
    if [[ $rc -ne 0 ]]  # ask the user to enter the external IP
    then
            echo "    Please enter the ZOWE_IP_ADDRESS of this system"
            read ZOWE_IP_ADDRESS_INPUT
            if [[ ! -n "$ZOWE_IP_ADDRESS_INPUT" ]]
            then
               echo Error: User entered blank ZOWE_IP_ADDRESS    # leave ZOWE_IP_ADDRESS unchanged,
               echo Info: Using ZOWE_IP_ADDRESS=$ZOWE_IP_ADDRESS  # as discovered above
            else
               echo Info: User entered ZOWE_IP_ADDRESS=$ZOWE_IP_ADDRESS_INPUT
               ZOWE_IP_ADDRESS=$ZOWE_IP_ADDRESS_INPUT             # take what the user entered
            fi
            checkHostnameResolves $ZOWE_EXPLORER_HOST $ZOWE_IP_ADDRESS
            case $? in
                0)  echo OK resolved $ZOWE_EXPLORER_HOST to $ZOWE_IP_ADDRESS >> $LOG_FILE
                ;;
                1)  echo warning : "$ping_bin $ZOWE_EXPLORER_HOST did not match stated IP address $ZOWE_IP_ADDRESS"
                ;;
                2)  echo error : "dig found hostname $ZOWE_EXPLORER_HOST and IP but IP did not match $ZOWE_IP_ADDRESS"
                ;;
                3)  echo warning : "dig could not find IP of hostname $ZOWE_EXPLORER_HOST"
                ;;  
                4)  echo error : ZOWE_EXPLORER_HOST or ZOWE_IP_ADDRESS is an empty string
                ;;   
            esac
    fi  

    export ZOWE_IP_ADDRESS
else
    checkHostnameResolves $ZOWE_EXPLORER_HOST $ZOWE_IP_ADDRESS

    case $? in
        0)        echo OK resolved $ZOWE_EXPLORER_HOST to $ZOWE_IP_ADDRESS >> $LOG_FILE
        ;;
        1)        echo warning : "$ping_bin $ZOWE_EXPLORER_HOST did not match stated IP address $ZOWE_IP_ADDRESS"
        ;;
        2)        echo error : "dig found hostname $ZOWE_EXPLORER_HOST and IP but IP did not match $ZOWE_IP_ADDRESS"
        ;;
        3)        echo warning : "dig could not find IP of hostname $ZOWE_EXPLORER_HOST"
        ;;
        4)        echo error : ZOWE_EXPLORER_HOST or ZOWE_IP_ADDRESS is an empty string
        ;; 
    esac
    echo "  ZOWE_IP_ADDRESS variable value="$ZOWE_IP_ADDRESS >> $LOG_FILE
fi

if [[ $ZOWE_ZOSMF_HOST == "" ]]
then
    ZOWE_ZOSMF_HOST=$ZOWE_EXPLORER_HOST
    echo "  ZOWE_ZOSMF_HOST variable not specified, value defaults to "$ZOWE_ZOSMF_HOST >> $LOG_FILE
    export ZOWE_ZOSMF_HOST
else
    echo "  ZOWE_ZOSMF_HOST variable value="$ZOWE_ZOSMF_HOST >> $LOG_FILE
fi
    

echo "</zowe-init.sh>" >> $LOG_FILE
