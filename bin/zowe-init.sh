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
# JAVA_HOME points to Java to be used
# ZOWE_EXPLORER_HOST points to the current host name
# ZOWE_IP_ADDRESS is the external IP address of the host ZOWE_EXPLORER_HOST where Zowe is installed 
# NODE_HOME points to the node directory

# This script checks to see whether they are set, and if not tries to locate them, 
# and if they can't be found prompt for them before setting them

echo "<zowe-init.sh>" >> $LOG_FILE

# process input parameters.
OPTIND=1
while getopts "s" opt; do
  case $opt in
    s) SKIP_NODE=1;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift "$(($OPTIND-1))"

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
  . ${ZOWE_ROOT_DIR}/bin/utils/zosmf-utils.sh
  prompt_zosmf_port_if_required
else 
    echo "  ZOWE_ZOSMF_PORT variable value="$ZOWE_ZOSMF_PORT >> $LOG_FILE
fi

. ${ZOWE_ROOT_DIR}/bin/utils/java-utils.sh
prompt_java_home_if_required

if [[ ${SKIP_NODE} != 1 ]]
then
  . ${ZOWE_ROOT_DIR}/bin/utils/node-utils.sh
  prompt_for_node_home_if_required
fi

###identify ping
getPing_bin


ZOWE_EXPLORER_HOST_INITIAL=$ZOWE_EXPLORER_HOST
if [[ $ZOWE_EXPLORER_HOST == "" ]]
then
    # ZOWE_EXPLORER_HOST=$(hostname -c)
    hn=`hostname`
    rc=$?
    if [[ -n "$hn" && $rc -eq 0 ]]
    then
        full_hostname=`$ping_bin -A ipv4 $hn|sed -n 's/.* host \(.*\) (.*/\1/p'`
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
        if [[ ! -n "$ZOWE_EXPLORER_HOST" ]]
        then
            echo Info: User entered blank ZOWE_EXPLORER_HOST
        fi
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
$ping_bin -A ipv4 $hostname | grep $ip 1> /dev/null
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
          ZOWE_IP_ADDRESS=`$ping_bin -A ipv4 $hn|sed -n 's/.* (\(.*\)).*/\1/p'`
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
    fi  
    export ZOWE_IP_ADDRESS
fi 

checkHostnameResolves $ZOWE_EXPLORER_HOST $ZOWE_IP_ADDRESS
rc=$?
case $rc in
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
if [[ $rc -ne 0 && ! -n "$ZOWE_EXPLORER_HOST_INITIAL" ]] # if error AND hostname was blank at entry
then
    echo "    Defaulting hostname to value of ZOWE_IP_ADDRESS $ZOWE_IP_ADDRESS" 
    export ZOWE_EXPLORER_HOST=$ZOWE_IP_ADDRESS                
fi

echo "  ZOWE_IP_ADDRESS    variable value="$ZOWE_IP_ADDRESS
echo "  ZOWE_EXPLORER_HOST variable value="$ZOWE_EXPLORER_HOST

if [[ $ZOWE_ZOSMF_HOST == "" ]]
then
    ZOWE_ZOSMF_HOST=$ZOWE_EXPLORER_HOST
    echo "  ZOWE_ZOSMF_HOST variable not specified, value defaults to "$ZOWE_ZOSMF_HOST >> $LOG_FILE
    export ZOWE_ZOSMF_HOST
else
    echo "  ZOWE_ZOSMF_HOST variable value="$ZOWE_ZOSMF_HOST >> $LOG_FILE
fi
    

echo "</zowe-init.sh>" >> $LOG_FILE
