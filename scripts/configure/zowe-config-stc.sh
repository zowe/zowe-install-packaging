#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019
################################################################################

#  Configure Zowe as a started task

# Script entry criteria:
# 1. The script must be run from directory $ZOWE_ROOT_DIR/scripts/configure to run this script for ACF2

# The user of this script must be authorized to issue the necessary commands to the installed security product

# If you use RACF, the following commands will be issued:
# RDEFINE STARTED ${ZWESVSTC}.* UACC(NONE) STDATA(USER(IZUSVR) GROUP(IZUADMIN)
# PRIVILEGED(NO) TRUSTED(NO) TRACE(YES))
# SETROPTS REFRESH RACLIST(STARTED)

# If you use CA ACF2, the following commands will be issued:
# SET CONTROL(GSO)
# INSERT STC.${ZWESVSTC} LOGONID(IZUSVR) GROUP(IZUADMIN) STCID(${ZWESVSTC})
# F ACF2,REFRESH(STC)

# If you use CA Top Secret, the following commands will be issued:
# TSS ADDTO(STC) PROCNAME(${ZWESVSTC}) ACID(IZUSVR)

ZWESVSTC={{stc_name}}

echo Script zowe-config-stc.sh started

echo
echo Detecting active SAF security product

function checkJob {
jobname=$1
tsocmd status ${jobname} 2> /dev/null | grep "JOB ${jobname}(S.*[0-9]*) EXECUTING" >/dev/null
if [[ $? -ne 0 ]]
then 
    # echo Info: job ${jobname} is not executing
    return 1
else 
    # echo OK: job ${jobname} is executing
    return 0
fi
}

found_saf=0
for saf in  RACF ACF2 TSS
do
    checkJob $saf
    if [[ $? -eq 0 ]]
    then    
        found_saf=1
        break
    fi
done

if [[ found_saf -eq 1 ]]
then
    echo Info: SAF security product $saf is active
    case $saf in
    
    RACF) 
        tsocmd "RDEFINE STARTED ${ZWESVSTC}.* UACC(NONE) STDATA(USER(IZUSVR) GROUP(IZUADMIN) PRIVILEGED(NO) TRUSTED(NO) TRACE(YES))" \
            1> /tmp/cmd.out 2> /tmp/cmd.err 
        if [[ $? -ne 0 ]]
        then
            echo Error: RDEFINE failed with the following errors
            cat /tmp/cmd.out /tmp/cmd.err
        else
            tsocmd "SETROPTS REFRESH RACLIST(STARTED)"
            echo OK: RACF setup complete
        fi 
        ;;

    ACF2)
        tsocmd "SET CONTROL(GSO)" \
            1> /tmp/cmd.out 2> /tmp/cmd.err 
        if [[ $? -ne 0 ]]
        then
            echo Error: "SET CONTROL(GSO) failed with the following errors"
            cat /tmp/cmd.out /tmp/cmd.err
        else
            tsocmd "INSERT STC.${ZWESVSTC} LOGONID(IZUSVR) GROUP(IZUADMIN) STCID(${ZWESVSTC})" \
                1> /tmp/cmd.out 2> /tmp/cmd.err 
            if [[ $? -ne 0 ]]
            then
                echo Error: "INSERT STC failed with the following errors"
                cat /tmp/cmd.out /tmp/cmd.err
            else

                if [[ -x ../internal/opercmd ]]
                then 
                    ../internal/opercmd "F ACF2,REFRESH(STC)" 1> /dev/null 2> /dev/null \
                        1> /tmp/cmd.out 2> /tmp/cmd.err 
                    if [[ $? -ne 0 ]]
                    then
                        echo Error: "ACF2 REFRESH failed with the following errors"
                        cat /tmp/cmd.out /tmp/cmd.err
                    else
                        echo OK: ACF2 setup complete
                    fi
                else 
                    echo Error: opercmd is missing or not executable
                    echo Error: you must be in $ZOWE_ROOT_DIR/configure directory to run this script for ACF2
                fi 

            fi            
        fi 
        ;;

    TSS)
        tsocmd "TSS ADDTO(STC) PROCNAME(${ZWESVSTC}) ACID(IZUSVR)" \
            1> /tmp/cmd.out 2> /tmp/cmd.err 
        if [[ $? -ne 0 ]]
        then
            echo Error: "TSS ADDTO(STC) failed with the following errors"
            cat /tmp/cmd.out /tmp/cmd.err
        else
            echo OK: Top Secret setup complete
        fi 
        ;;
    *)
        echo Error: Unexpected SAF $saf    
    esac
else
    echo Error: No SAF security product found active
fi

rm /tmp/cmd.out /tmp/cmd.err 1> /dev/null 2> /dev/null

echo
echo Script zowe-config-stc.sh ended
