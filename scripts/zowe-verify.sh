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

# Verify that an installed Zowe build is healthy after you install it on z/OS
# Note:  This script does not change anything on your system.

echo Script zowe-verify.sh started
echo

# This script is expected to be located in ${ZOWE_ROOT_DIR}/scripts,
# otherwise you must set ZOWE_ROOT_DIR to where the Zowe runtime is installed before you run this script
# e.g. export ZOWE_ROOT_DIR=/u/userid/zowe/1.0.0       

if [[ -n "${ZOWE_ROOT_DIR}" ]]
then 
    echo Info: ZOWE_ROOT_DIR environment variable is set to ${ZOWE_ROOT_DIR}
else 
    echo Info: ZOWE_ROOT_DIR environment variable is empty
    if [[ `basename $PWD` != scripts ]]
    then
        echo Warning: You are not in the ZOWE_ROOT_DIR/scripts directory
        echo Warning: '${ZOWE_ROOT_DIR} is not set'
        echo Warning: '${ZOWE_ROOT_DIR} must be set to where Zowe runtime is installed'
        echo Warning: script will run, but with errors
    else
        ZOWE_ROOT_DIR=`dirname $PWD`
        echo Info: ZOWE_ROOT_DIR environment variable is now set to ${ZOWE_ROOT_DIR}
    fi    
fi

echo
echo Check SAF security settings are correct

# 2.1 RACF 
tsocmd lg izuadmin 2>/dev/null |grep IZUSVR >/dev/null
if [[ $? -ne 0 ]]
then
  echo Error: userid IZUSVR is not in RACF group IZUADMIN
fi

echo Check IZUSVR has UPDATE access to BPX.SERVER and BPX.DAEMON
# For zssServer to be able to operate correctly 
profile_error=0
for profile in SERVER DAEMON
do
    tsocmd rl facility "*" 2>/dev/null | grep BPX\.$profile >/dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: profile BPX\.$profile is not defined
        profile_error=1
    fi

    tsocmd rl facility bpx.$profile authuser 2>/dev/null |grep "IZUSVR *UPDATE" >/dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: User IZUSVR does not have UPDATE access to profile BPX\.$profile
        profile_error=1
    fi
done
if [[ profile_error -eq 0 ]]
then
    echo OK
fi

echo Check IZUSVR/IZUADMIN has at least READ access to BPX.JOBNAME
tsocmd "rl facility bpx.jobname authuser" 2>/dev/null | grep -e "IZUADMIN" -e "IZUSVR" | grep -E "READ|UPDATE|ALTER" > /dev/null
if [[ $? -ne 0 ]]
then
    echo Warning: User IZUSVR does not have access to profile BPX\.JOBNAME
    echo You will not be able to set job names using the _BPX_JOBNAME environment variable
else
    echo OK
fi

# 2.1.1 RDEFINE STARTED ZOESVR.* UACC(NONE) 
#  STDATA(USER(IZUSVR) GROUP(IZUADMIN) PRIVILEGED(NO) TRUSTED(NO) TRACE(YES)) 

# Discover ZOWESVR name for this runtime
# # Look in zowe-start.sh
# serverName=`sed -n 's/.*opercmd.*S \([^ ]*\),SRVRPATH=.*/\1/p' zowe-start.sh 2> /dev/null`

# if [[ $? -eq 0 && -n "$serverName" ]]
# then 
#     ZOWESVR=$serverName
#     # echo Info: ZOWESVR name is ${ZOWESVR}
# else 
#     echo Error: Failed to find ZOWESVR name in zowe-start.sh, defaulting to ZOWESVR for this check 
#     ZOWESVR=ZOWESVR
# fi
# echo
# echo Check ${ZOWESVR} processes are runnning ${ZOWE_ROOT_DIR} code

# # Look in processes that are runnning ${ZOWE_ROOT_DIR} code - there may be none
# ./internal/opercmd "d omvs,a=all" \
#     | sed "{/ ${ZOWESVR}/N;s/\n */ /;}" \
#     | grep -v CMD=grep \
#     | grep ${ZOWESVR}.*LATCH.*${ZOWE_ROOT_DIR} \
#     | awk '{ print $2 }'\
#     | sed 's/[1-9]$//' | sort | uniq > /tmp/zowe.omvs.ps 
# n=$((`cat /tmp/zowe.omvs.ps | wc -l`))
# case $n in
    
#     0) echo Warning: No ${ZOWESVR} jobs are running ${ZOWE_ROOT_DIR} code
#     ;;
#     1) # is it the right job?
#     jobname=`cat /tmp/zowe.omvs.ps`
#     if [[ $jobname != ${ZOWESVR} ]]
#     then 
#         echo Warning: Found PROC ${ZOWESVR} in zowe-start.sh, but ${ZOWE_ROOT_DIR} code is running in $jobname instead
#         echo Info: Switching to job $jobname
#         ZOWESVR=$jobname
#     else
#         echo OK: ${ZOWE_ROOT_DIR} code is running in $jobname
#     fi 
#     ;;
#     *) echo Warning: $n different jobs are running ${ZOWE_ROOT_DIR} code
#     echo List of jobs
#     cat /tmp/zowe.omvs.ps
#     echo End of list
# esac 
# rm /tmp/zowe.omvs.ps 2> /dev/null

# echo
# echo Check ${ZOWESVR} processes are runnning nodeCluster code

# for cluster in nodeCluster zluxCluster
# do
#     count=$((`./internal/opercmd "d omvs,a=all" \
#             | sed "{/ ${ZOWESVR}/N;s/\n */ /;}" \
#             | grep -v CMD=grep \
#             | grep ${ZOWESVR}.*LATCH.*${cluster} \
#             | awk '{ print $2 }'\
#             | wc -l`))
#     if [[ $count -ne 0 ]]
#     then
#         echo $cluster OK
#     else
#         echo Error: $cluster is not running in ${ZOWESVR}
#     fi
# done

# echo
# echo Check ${ZOWESVR} is defined as STC to RACF and is assigned correct userid and group.

# # similar function as in pre-install.sh ...
# match_profile ()        # match a RACF profile entry to the ZOWESVR task name.
# {
#     set -f
#   entry=$1                  # the RACF definition entry in the list

#   if [[ $entry = '*' ]]     # RLIST syntax does not permit listing of just the '*' profile
#   then
#     return 1    # no strings matched
#   fi  
  
#   profileName=${ZOWESVR}  # the profile that we want to match in that list



#   l=$((`echo $profileName | wc -c`))  # length of profile we're looking for, including null terminator e.g. "ZOWESVR"

#     i=1
#     while [[ $i -lt $l ]]
#     do
#         r=`echo $entry        | cut -c $i,$i` # ith char from RACF definition
#         p=`echo $profileName  | cut -c $i,$i` # ith char from profile we're looking for

#         if [[ $r = '*' ]]
#         then
#           return 0  # asterisk matches rest of string
#         fi

#         if [[ $r != $p ]]
#         then
#           break   # mismatch char for this profile, quit
#         fi

#         i=$((i+1))
#     done

#     if [[ $i -eq $l ]]
#     then
#       return 0  # whole string matched
#     fi

#   return 1    # no strings matched
# }               #` # needed for VS code

# izusvr=0        # set success flag
# izuadmin=0      # set success flag

# # # find names of STARTED profiles
# set -f

#   tsocmd rl started \* 2>/dev/null |sed -n 's/STARTED *\([^ ]*\) .*/\1/p' > /tmp/find_profile.out
#   while read entry 
#   do
#         match_profile ${entry}
#         if [[ $? -eq 0 ]]
#         then
#                 echo OK: Found matching STARTED profile entry $entry for task ${ZOWESVR}

#                 tsocmd rl started $entry stdata 2>/dev/null | grep "^USER= IZUSVR" > /dev/null    # is the profile user name IZUSVR?
#                 if [[ $? -ne 0 ]]
#                 then 
#                     echo Error: profile $entry is not assigned to user IZUSVR
#                 else
#                     echo OK: Profile $entry is assigned to user IZUSVR
#                     izusvr=1        # set success flag
#                 fi

#                 tsocmd rl started $entry stdata 2>/dev/null | grep "^GROUP= IZUADMIN" > /dev/null # is the profile group name IZUADMIN?
#                 if [[ $? -ne 0 ]]
#                 then 
#                     echo Warning: profile $entry is not assigned to group IZUADMIN
#                     # This is not a barrier to correct execution, but if the group is not null, we think it must be IZUADMIN.
#                 else
#                     echo OK: Profile $entry is assigned to group IZUADMIN
#                     izuadmin=1        # set success flag
#                 fi
            
#                 break   # don't look for any more matches        
#         fi
#   done <    /tmp/find_profile.out
#   rm        /tmp/find_profile.out

# if [[ $izusvr -eq 0 || $izuadmin -eq 0 ]]
# then    
#     echo Warning: Started task $ZOWESVR not assigned to the correct RACF user or group
# else
#     echo OK: Started task $ZOWESVR is assigned to the correct RACF user and group
# fi

set +f 


# 2.1.2  Activate the SDSF RACF class and add the following 3 profiles your system:
    # - GROUP.ISFSPROG
    # - GROUP.ISFSPROG.SDSF                 
    # - ISF.CONNECT.**
    # - ISF.CONNECT.sysname (e.g. TVT6019)
# 2.1.3 external scripts (amended)

# 2.2    ACF2
# 2.3    TOPSECRET


# Users must belong to a group that has READ access to these profiles.
# have the following ISF profile defined:
# class profile SDSF ISF.CONNECT.** (G)




# 4. Hostname is correct in 
# web directory:
#  in the index.html file in the web directory of atlasJES, atlasMVS and atlasUSS 
#  to point to the hostname of your machine
# plugin config:  
# Check hostname of the plugin configuration per "Giza zD&T boxnote.pdf"
# (File: /zaas1/giza/zluxexampleserver/
# deploy/instance/ZLUX/pluginStorage/com.rs.mvd.tn3270/sessions/_defaultTN3270.json)

# 6. localhost is defined for real, VM and zD&T systems:
# Add “127.0.0.1 localhost” to ADCD.Z23A.TCPPARMS(GBLIPNOD)

# 1.2.2.	function
#  

# echo
# echo Info: ZOWE job name is ${ZOWESVR}
# echo Check ${ZOWESVR} job is started with user IZUSVR

# # 0.  Check user of ZOWESVR is IZUSVR

# if [[ -n "${ZOWE_ROOT_DIR}" ]]
# then 
#     echo Info: ZOWE_ROOT_DIR is set to ${ZOWE_ROOT_DIR} 
# else
#     echo Error: ZOWE_ROOT_DIR is not set
#     echo Info: Some parts of this script will not work as a result
# fi 

${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d t" 1> /dev/null 2> /dev/null  # is 'opercmd' available and working?
if [[ $? -ne 0 ]]
then
  echo Error: Unable to run opercmd REXX exec from # >> $LOG_FILE
  ls -l ${ZOWE_ROOT_DIR}/scripts/internal/opercmd # try to list opercmd
  echo Error: No Zowe jobs will be checked
  echo Error: Correct this error and re-run this script
else
    echo OK: opercmd is available

    # Check STCs

    # There could be >1 STC named ZOWESVR

    # echo
    # echo Check all ZOWESVR jobs have userid IZUSVR

    # check status first ...

    # checkJob ${ZOWESVR}
    # if [[ $? -ne 0 ]]
    # then    
    #     echo Error:  job ${ZOWESVR} is not executing, ${ZOWESVR} userid and STCs will not be checked
    # else 
    #     # check userid is IZUSVR
    #     ${ZOWE_ROOT_DIR}/scripts/internal/opercmd d j,${ZOWESVR} | grep "USERID=IZUSVR" > /dev/null
    #     if [[ $? -ne 0 ]]
    #     then    
    #         echo Error:  USERID of ${ZOWESVR} is not IZUSVR

    #     else    # we found >0 zowe STCs, do any of them NOT have USERID=IZUSVR?
    #         ${ZOWE_ROOT_DIR}/scripts/internal/opercmd d j,${ZOWESVR} | grep "USERID=" | grep -v "USERID=IZUSVR" > /dev/null
    #         if [[ $? -eq 0 ]]
    #         then    
    #             echo Error:  Some USERID of ${ZOWESVR} is not IZUSVR
    #         else
    #             echo OK:  All USERIDs of ${ZOWESVR} are IZUSVR
    #         fi
    #     fi

    #     # number of ZOESVR started tasks expected to be active in a running system
    #     echo
    #     echo Check ${ZOWESVR} jobs in execution

    # check Zowe jobs are running
    echo
    echo Check Zowe jobs are running

    function check_jobs {
        if  [[ $# -lt 2 ]]
        then
            echo Error: No jobname supplied for checking
            return 1
        fi
        jobname=$1

        enj=$2  # expected number of jobs with this jobname
        ${ZOWE_ROOT_DIR}/scripts/internal/opercmd d j,${jobname}|grep " ${jobname} .* A=[0-9,A-F][0-9,A-F][0-9,A-F][0-9,A-F] " >/tmp/${jobname}.dj
        nj=`cat /tmp/${jobname}.dj | wc -l`     # set nj to actual number of jobs found
        rm /tmp/${jobname}.dj >/dev/null

        # check we found the expected number of jobs
        if [[ $nj -ne $enj ]]
        then
            echo Error: "Expecting $enj job(s) for $jobname, found $nj"
            return 1
        else
            # echo "Found $nj job(s) for $jobname"
            return 0
        fi
    }
    # discover zowe job names

    # In scripts/zowe-start.template.sh or /scripts/zowe-start.sh we should find 
    # ZOWESVR job name
    # 
    # $ZOWE_ROOT_DIR/scripts/internal/opercmd \
    #     "S {{stc_name}},SRVRPATH='"$ZOWE_ROOT_DIR"'",JOBNAME={{zowe_prefix}}SV

    zowe_start=${ZOWE_ROOT_DIR}/scripts/zowe-start.sh
    if [[ ! -r $zowe_start ]]
    then
        echo Error: Unable to read file $zowe_start
        echo Warning: No Zowe jobs will be checked
    else 
        grep JOBNAME= $zowe_start > /dev/null
        if [[ $? -ne 0 ]]
        then
            echo Error: Failed to find JOBNAME in $zowe_start
        else 
            ZOWE_PREFIX=`sed -n 's/.*JOBNAME=\([^ ]*\)SV *$/\1/p' $zowe_start`   # JOBNAME must end with SV
            if [[ ! -n "${ZOWE_PREFIX}" ]]
            then
                echo Error: Failed to find ZOWE_PREFIX in $zowe_start
                echo Warning: Using ZOWE instead
                ZOWE_PREFIX=ZWE1   # best guess, allow us to proceed                
            fi

            ZOWESVR_job_name=${ZOWE_PREFIX}SV
            ZOWE_ZLUX_SVR=${ZOWE_PREFIX}SZ1
            ZOWE_NODE_SVR=${ZOWE_PREFIX}DS1

            # must be same list as in run-zowe.template.sh
            ZOWE_API_GW=${ZOWE_PREFIX}AG
            ZOWE_API_DS=${ZOWE_PREFIX}AD
            ZOWE_API_CT=${ZOWE_PREFIX}AC
            ZOWE_DESKTOP=${ZOWE_PREFIX}DT
            ZOWE_EXPL_JOBS=${ZOWE_PREFIX}EJ
            ZOWE_EXPL_DATA=${ZOWE_PREFIX}EF
            ZOWE_EXPL_UI_JES=${ZOWE_PREFIX}UJ
            ZOWE_EXPL_UI_MVS=${ZOWE_PREFIX}UD
            ZOWE_EXPL_UI_USS=${ZOWE_PREFIX}UU

            #now check zowe jobs
            zoweJobErrors=0
            check_jobs    $ZOWESVR_job_name     1
            zoweJobErrors=$((zoweJobErrors+$?))
            # check_jobs    ${ZOWESVR_job_name}2  1
            # zoweJobErrors=$((zoweJobErrors+$?))
            check_jobs    $ZOWE_API_GW          1
            zoweJobErrors=$((zoweJobErrors+$?))
            check_jobs    $ZOWE_ZLUX_SVR        1
            zoweJobErrors=$((zoweJobErrors+$?))
            check_jobs    $ZOWE_NODE_SVR        5
            zoweJobErrors=$((zoweJobErrors+$?))
            check_jobs    $ZOWE_API_DS          1      
            zoweJobErrors=$((zoweJobErrors+$?))
            check_jobs    $ZOWE_API_CT          1
            zoweJobErrors=$((zoweJobErrors+$?))
            check_jobs    $ZOWE_DESKTOP         2
            zoweJobErrors=$((zoweJobErrors+$?))
            check_jobs    $ZOWE_EXPL_JOBS       1
            zoweJobErrors=$((zoweJobErrors+$?))
            check_jobs    $ZOWE_EXPL_DATA       1
            zoweJobErrors=$((zoweJobErrors+$?))
            check_jobs    $ZOWE_EXPL_UI_JES     1
            zoweJobErrors=$((zoweJobErrors+$?))
            check_jobs    $ZOWE_EXPL_UI_MVS     1
            zoweJobErrors=$((zoweJobErrors+$?))
            check_jobs    $ZOWE_EXPL_UI_USS     1
            zoweJobErrors=$((zoweJobErrors+$?))

            if [[ $zoweJobErrors -eq 0 ]]
            then
                echo OK
            fi

            echo
            echo Check Zowe ports are assigned to jobs 

            function check_ports {
                if  [[ $# -eq 0 ]]
                then
                    echo Error: No jobname supplied
                    return 0
                fi

                jobname=$1
                shift 
                
                if  [[ $# -eq 0 ]]
                then
                    echo Error: No port supplied for $jobname
                    return 0
                fi

                portsAssigned=0
                while [[ $# -ne 0 ]] 
                do
                    port=$1
                    # check port
                    netstat -b -E $jobname 2>/dev/null \
                        | grep Listen | awk '{printf("%d\n", $4)}' \
                        | grep ^${port}$ > /dev/null
                    if [[ $? -ne 0 ]]
                    then
                        echo Error: Port $port not assigned to $jobname
                    else 
                        # echo port $port is in use by job $jobname
                        portsAssigned=$((portsAssigned+1))
                    fi 
                    # continue to next port in parameter list 
                    shift
                done
                # echo ports assigned = $portsAssigned
                return $portsAssigned
            }
            #                           

            # yaml
            yaml=${ZOWE_ROOT_DIR}/scripts/configure/zowe-install.yaml

            if [[ ! -r $yaml ]]
            then
                echo Error: Unable to read $yaml
                echo Warning: Ports will not be checked
            else  
                # obtain ports from yaml file

                api_mediation_catalog_http_port=`sed -n 's/ *catalogPort=\(.*\)/\1/p' $yaml` # 7552      
                api_mediation_discovery_http_port=`sed -n 's/ *discoveryPort=\(.*\)/\1/p' $yaml` # 7553  
                api_mediation_gateway_https_port=`sed -n 's/ *gatewayPort=\(.*\)/\1/p' $yaml` # 7554     
                explorer_server_jobsPort=`sed -n 's/ *jobsAPIPort=\(.*\)/\1/p' $yaml` # 8545             
                explorer_server_dataSets_port=`sed -n 's/ *mvsAPIPort=\(.*\)/\1/p' $yaml` # 8547        
                zlux_server_https_port=`sed -n 's/ *httpsPort=\(.*\)/\1/p' $yaml` # 8544               
                zss_server_http_port=`sed -n 's/ *zssPort=\(.*\)/\1/p' $yaml` # 8542                 
                jes_explorer_server_port=`sed -n 's/ *jobsExplorerPort=\(.*\)/\1/p' $yaml` # 8546            
                mvs_explorer_server_port=`sed -n 's/ *mvsExplorerPort=\(.*\)/\1/p' $yaml` # 8548            
                uss_explorer_server_port=`sed -n 's/ *ussExplorerPort=\(.*\)/\1/p' $yaml` # 8550            
            #                                                                                   here are the defaults:
                totPortsAssigned=0
                check_ports    $ZOWE_API_GW         $api_mediation_gateway_https_port               # 7554
                totPortsAssigned=$((totPortsAssigned+$?))
                check_ports    $ZOWE_API_DS         $api_mediation_discovery_http_port              # 7553
                totPortsAssigned=$((totPortsAssigned+$?))
                check_ports    $ZOWE_API_CT         $api_mediation_catalog_http_port                # 7552
                totPortsAssigned=$((totPortsAssigned+$?))
                check_ports    $ZOWE_NODE_SVR       $zlux_server_https_port                         # 8544 
                totPortsAssigned=$((totPortsAssigned+$?))
                check_ports    $ZOWE_ZLUX_SVR       $zss_server_http_port                           # 8542
                totPortsAssigned=$((totPortsAssigned+$?))
                check_ports    $ZOWE_EXPL_JOBS      $explorer_server_jobsPort                       # 8545
                totPortsAssigned=$((totPortsAssigned+$?))
                check_ports    $ZOWE_EXPL_DATA      $explorer_server_dataSets_port                  # 8547
                totPortsAssigned=$((totPortsAssigned+$?))
                check_ports    $ZOWE_EXPL_UI_JES    $jes_explorer_server_port                       # 8546
                totPortsAssigned=$((totPortsAssigned+$?))
                check_ports    $ZOWE_EXPL_UI_MVS    $mvs_explorer_server_port                       # 8548
                totPortsAssigned=$((totPortsAssigned+$?))
                check_ports    $ZOWE_EXPL_UI_USS    $uss_explorer_server_port                       # 8550
                totPortsAssigned=$((totPortsAssigned+$?))

                zowenports=10       # how many ports Zowe uses
                if [[ $totPortsAssigned -ne $zowenports ]]  
                then
                    echo Error: Found $totPortsAssigned ports assigned, expecting $zowenports
                else
                    echo OK
                fi
            fi  

        fi 
    fi 

    # fi

    echo 
    echo Check ZSS server is running

    zss_error_status=0  # no errors yet
    IZUSVR=IZUSVR   # remove this line when IZUSVR is an env variable

    # Is program ZWESIS01 running?
    ${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d omvs,a=all" | grep -v "grep CMD=ZWESIS01" | grep CMD=ZWESIS01  > /dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: Program ZWESIS01 is not running
        zss_error_status=1
        else
            # Is program ZWESIS01 running under user ${IZUSVR}?
            ${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d omvs,u=${IZUSVR}" | grep CMD=ZWESIS01 > /dev/null
            if [[ $? -ne 0 ]]
            then
                echo Error: Program ZWESIS01 is not running under user ${IZUSVR}
                zss_error_status=1
            fi
    fi

    # Try to determine ZSS server job name
    ${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d omvs,a=all" > /tmp/d.omvs.all.$$.txt
    ZSSSVR=`sed -n '/LATCHWAITPID/!h;/CMD=ZWESIS01/{x;p;}' /tmp/d.omvs.all.$$.txt | awk '{ print $2 }'`
    rm /tmp/d.omvs.all.$$.txt > /dev/null
    if [[ -n "$ZSSSVR" ]] then
        echo ZSS server job name is $ZSSSVR
        ${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d j,${ZSSSVR}" | grep WUID=STC > /dev/null
        if [[ $? -ne 0 ]]
        then
            echo Error: Job "${ZSSSVR}" is not running as a started task
            zss_error_status=1
        fi
    else 
        echo Error:  Could not determine ZSSSVR job name
        zss_error_status=1
    fi

    # # Is the status of the ZSS server OK?
    ls ${ZOWE_ROOT_DIR}/zlux-app-server/log/zssServer-* > /dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: No ZSS server logs found in ${ZOWE_ROOT_DIR}/zlux-app-server/log
        zss_error_status=1
    else
        grep "ZIS status - Ok" `ls  -t ${ZOWE_ROOT_DIR}/zlux-app-server/log/zssServer-* | head -1` > /dev/null
        if [[ $? -ne 0 ]]
        then
            echo Error: The status of the ZSS server is not OK in ${ZOWE_ROOT_DIR}/zlux-app-server/log/zssServer log
            zss_error_status=1
            grep "ZIS status " `ls  -t ${ZOWE_ROOT_DIR}/zlux-app-server/log/zssServer-*` 
            if [[ $? -ne 0 ]]
            then
                echo Error: Could not determine the status of the ZSS server 
            fi
        fi
    fi

    if [[ $zss_error_status -eq 0 ]]
    then
        echo OK
    fi

fi


# 3. Ports are available

    # explorer-server:
    #   httpPort=7080
    #   httpsPort=7443
    # http and https ports for the node server
    #   zlux-server:
    #   httpsPort=8544
    #   zssPort=8542


# 0. check netstat portlist or other view of pre-allocated ports    


# 0. Extract port settings from Zowe config files.  

# echo 
# echo Check port settings from Zowe config files


# for file in \
#  "api-mediation/scripts/api-mediation-start-catalog.sh" \
#  "api-mediation/scripts/api-mediation-start-discovery.sh" \
#  "api-mediation/scripts/api-mediation-start-gateway.sh" \
#  "explorer-jobs-api/scripts/jobs-api-server-start.sh" \
#  "explorer-data-sets-api/scripts/data-sets-api-server-start.sh" \
#  "zlux-app-server/config/zluxserver.json" \
#  "vt-ng2/_defaultVT.json" \
#  "tn3270-ng2/_defaultTN3270.json" \
#  "jes_explorer/server/configs/config.json" \
#  "mvs_explorer/server/configs/config.json" \
#  "uss_explorer/server/configs/config.json"
# do
#     case $file in
#     ### WIP MARKER ###
#         tn3270*) 
#         # echo Checking tn3270
#         # fragile search
#         terminal_telnetPort=`sed -n 's/.*"port" *: *\([0-9]*\).*/\1/p' ${ZOWE_ROOT_DIR}/$file`
#         if [[ -n "$terminal_telnetPort" ]]
#         then 
#             echo OK: terminal_telnetPort is $terminal_telnetPort
#         else
#             echo Error: terminal_telnetPort not found in ${ZOWE_ROOT_DIR}/$file
#         fi 
        
#         ;;

#         vt*) 
#         # echo Checking vt
#         # fragile search
#         terminal_sshPort=`sed -n 's/.*"port" *: *\([0-9]*\).*/\1/p' ${ZOWE_ROOT_DIR}/$file`
#         if [[ -n "$terminal_sshPort" ]]
#         then
#             echo OK: terminal_sshPort is $terminal_sshPort
#         else
#             echo Error: terminal_sshPort not found in ${ZOWE_ROOT_DIR}/$file
#         fi 
        
#         ;;

#         *\.sh) 
#         # echo Checking .sh files  
#         port=`sed -n 's/.*port=\([0-9]*\) .*/\1/p'  ${ZOWE_ROOT_DIR}/$file`
#         case $file in 
#             *catalog*)
#                 if [[ -n "$port" ]]
#                 then
#                     api_mediation_catalog_http_port=$port
#                     echo OK: api catalog port is $port
#                 else
#                     echo Error: api catalog port not found in ${ZOWE_ROOT_DIR}/$file
#                 fi    
#                 ;;
#             *discovery*)
#                 if [[ -n "$port" ]]
#                 then
#                     echo OK: api discovery port is $port
#                     api_mediation_discovery_http_port=$port
#                 else
#                     echo Error: api discovery port not found in ${ZOWE_ROOT_DIR}/$file
#                 fi    
                
#                 ;;
#             *gateway*)
#                 if [[ -n "$port" ]]
#                 then
#                     echo OK: api gateway port is $port
#                     api_mediation_gateway_https_port=$port
#                 else
#                     echo Error: api gateway port not found in ${ZOWE_ROOT_DIR}/$file
#                 fi   

#                 ;;
#             *jobs*)
#                 if [[ -n "$port" ]]
#                 then
#                     echo OK: explorer jobs api server port is $port
#                     explorer_server_jobsPort=$port
#                 else
#                     echo Error: explorer jobs api server port not found in ${ZOWE_ROOT_DIR}/$file
#                 fi 

#                 ;;
#             *data-sets*)
#                 if [[ -n "$port" ]]
#                 then
#                     echo OK: explorer datasets api server port is $port
#                     explorer_server_dataSets_port=$port
#                 else
#                     echo Error: explorer datasets api server port not found in ${ZOWE_ROOT_DIR}/$file
#                 fi 
  

#         esac
        
#         ;;

#         *\.xml) 
#         # echo Checking .xml files
        
#         explorer_server_http_port=`iconv -f IBM-850 -t IBM-1047 ${ZOWE_ROOT_DIR}/$file | sed -n 's/.*httpPort="\([0-9]*\)" .*/\1/p'`
#         if [[ -n "$explorer_server_http_port" ]]
#         then
#             echo OK: explorer server httpPort is $explorer_server_http_port
#         else
#             echo Error: explorer server httpPort not found in ${ZOWE_ROOT_DIR}/$file
#         fi 
        
#         explorer_server_https_port=`iconv -f IBM-850 -t IBM-1047 ${ZOWE_ROOT_DIR}/$file | sed -n 's/.*httpsPort="\([0-9]*\)" .*/\1/p'`
#         if [[ -n "$explorer_server_https_port" ]]
#         then
#             echo OK: explorer server httpsPort is $explorer_server_https_port
#         else
#             echo Error: explorer server httpsPort not found in ${ZOWE_ROOT_DIR}/$file
#         fi 
        
#         ;;

#         *\.json) 
#         # echo Checking .json files 
#         case $file in
#         zlux*)
#             # fragile search
#             zlux_server_https_port=`sed -n 's/.*"port" *: *\([0-9]*\) *,.*/\1/p; /}/q' ${ZOWE_ROOT_DIR}/$file`
#             if [[ -n "$zlux_server_https_port" ]]
#             then
#                 echo OK: zlux server httpsPort is $zlux_server_https_port
#             else
#                 echo Error: zlux server httpsPort not found in ${ZOWE_ROOT_DIR}/$file
#             fi         
            
#             agent_http_port=`sed -n 's/.*"port": \([0-9]*\)$/\1/p' ${ZOWE_ROOT_DIR}/$file`
#             if [[ -n "$agent_http_port" ]]
#             then
#                 echo OK: zss server port is $agent_http_port
#             else
#                 echo Error: agent http port not found in ${ZOWE_ROOT_DIR}/$file
#             fi 

#             zss_server_http_port=`sed -n 's/.*"zssPort" *: *\([0-9]*\) *$/\1/p'   ${ZOWE_ROOT_DIR}/$file`
#             if [[ -n "$zss_server_http_port" ]]
#             then
#                 echo OK: zss server port is $zss_server_http_port
#             else
#                 echo Error: zss server port not found in ${ZOWE_ROOT_DIR}/$file
#             fi         
#             echo 

#             ;;

#         jes_explorer*)
#             # fragile search
#             jes_explorer_server_port=`sed -n 's/.*"port" *: *\([0-9]*\) *,.*/\1/p;' ${ZOWE_ROOT_DIR}/$file`
#             if [[ -n "$jes_explorer_server_port" ]]
#             then
#                 echo OK: jes explorer server port is $jes_explorer_server_port
#             else
#                 echo Error: jes explorer server port not found in ${ZOWE_ROOT_DIR}/$file
#             fi       

#             ;;

#         mvs_explorer*)
#             # fragile search
#             mvs_explorer_server_port=`sed -n 's/.*"port" *: *\([0-9]*\) *,.*/\1/p;' ${ZOWE_ROOT_DIR}/$file`
#             if [[ -n "$mvs_explorer_server_port" ]]
#             then
#                 echo OK: mvs explorer server port is $mvs_explorer_server_port
#             else
#                 echo Error: mvs explorer server port not found in ${ZOWE_ROOT_DIR}/$file
#             fi    
#             ;;

#         uss_explorer*)
#             # fragile search
#             uss_explorer_server_port=`sed -n 's/.*"port" *: *\([0-9]*\) *,.*/\1/p;' ${ZOWE_ROOT_DIR}/$file`
#             if [[ -n "$uss_explorer_server_port" ]]
#             then
#                 echo OK: uss explorer server port is $uss_explorer_server_port
#             else
#                 echo Error: uss explorer server port not found in ${ZOWE_ROOT_DIR}/$file
#             fi    
#             ;;

#         esac

#         ;;

#         *) 
#         echo Error:  Unexpected file $file
        
#     esac
#     echo
# done

# # check MVD web index files
# echo
# echo Check explorer server https port in the 3 explorer web/index.html files 

# # sed -n 's+.*https:\/\/.*:\([0-9]*\)/explorer-..s.*+\1+p' `ls ${ZOWE_ROOT_DIR}/explorer-??S/web/index.html`    

# for file in  `ls ${ZOWE_ROOT_DIR}/??s_explorer/web/index.html`
# do
#     port=`sed -n 's+.*https:\/\/.*:\([0-9]*\)/.*+\1+p' $file`  


#     if [[ -n "$port" ]]  
#     then
#         if [[ $port -ne $api_mediation_gateway_https_port ]]
#         then 
#             echo Error: Found $port expecting $api_mediation_gateway_https_port
#             echo in file $file
#         else 
#             echo OK: Port $port
#         fi
#     else
#         echo Error: Could not determine port in file $file
#     fi

#     #
#     #   0.  TBD: also check hostname or IP is right for this machine
#     #
# done                                       


echo
echo Check Node is at right version

# evaluate NODE_HOME from potential sources ...

# 1. run-zowe.sh?
# Zowe uses the version of Node.js located in NODE_HOME as set in run-zowe.sh
if [[ ! -n "$nodehome" ]]
then 
    ls $ZOWE_ROOT_DIR/scripts/internal/run-zowe.sh 1> /dev/null
    if [[ $? -ne 0 ]]
    then 
        echo Error: run-zowe.sh not found
    else
        grep " *export *NODE_HOME=.* *$" $ZOWE_ROOT_DIR/scripts/internal/run-zowe.sh 1> /dev/null
        if [[ $? -ne 0 ]]
        then 
            echo Info: \"export NODE_HOME\" not found in run-zowe.sh
        else
            node_set=`sed -n 's/^ *export *NODE_HOME=\(.*\) *$/\1/p' $ZOWE_ROOT_DIR/scripts/internal/run-zowe.sh`
            if [[ ! -n "$node_set" ]]
            then
                echo Error: NODE_HOME is empty in run-zowe.sh
            else
                nodehome=$node_set
                echo Info: Found in run-zowe.sh 
            fi 
        fi
    fi    
fi 

# 2. configure log?
if [[ ! -n "$nodehome" ]]
then 
    ls $ZOWE_ROOT_DIR/configure_log/*.log 1> /dev/null
    if [[ $? -eq 0 ]]
    then
        # configure log exists
        configure_log=`ls -t $ZOWE_ROOT_DIR/configure_log/*.log | head -1`
        node_set=`sed -n 's/NODE_HOME environment variable was set=\(.*\) *$/\1/p' $configure_log`
        if [[ -n "node_set" ]]
        then 
            nodehome=$node_set
            echo Info: Found in configure_log
        else 
            echo Error: NODE_HOME environment variable was not set in $configure_log
        fi 
    else 
        echo Error: no configure_log found in $ZOWE_ROOT_DIR/configure_log
    fi
fi


# 3. /etc/profile?
if [[ ! -n "$nodehome" ]]
then 
    ls /etc/profile 1> /dev/null
    if [[ $? -ne 0 ]]
    then 
        echo Info: /etc/profile not found
    else
        grep "^ *export *NODE_HOME=.* *$" /etc/profile 1> /dev/null
        if [[ $? -ne 0 ]]
        then 
            echo Info: \"export NODE_HOME\" not found in /etc/profile
        else
            node_set=`sed -n 's/^ *export *NODE_HOME=\(.*\) *$/\1/p' /etc/profile`
            if [[ ! -n "$node_set" ]]
            then
                echo Warning: NODE_HOME is empty in /etc/profile
            else
                nodehome=$node_set
                echo Info: Found in /etc/profile
            fi 
        fi
    fi    
fi 

echo
echo Check version of z/OS

release=`${ZOWE_ROOT_DIR}/scripts/internal/opercmd 'd iplinfo'|grep RELEASE`
# the selected line will look like this ...
# RELEASE z/OS 02.03.00    LICENSE = z/OS

vrm=`echo $release | sed 's+.*RELEASE z/OS \(........\).*+\1+'`
echo Info: release of z/OS is $release
if [[ $vrm < "02.02.00" ]]
    then echo Error: version $vrm not supported
    else echo OK: version $vrm is supported
fi

# 4. z/OSMF is up 

# echo
# echo Check Zowe environment variables are set correctly.

# # • ZOWE_JAVA_HOME: The path where 64 bit Java 8 or later is installed. Defaults to /usr/lpp/java/
# # J8.0_64
# if [[ -n "${ZOWE_JAVA_HOME}" ]]
# then 
#     echo OK: ZOWE_JAVA_HOME is not empty 
#     ls ${ZOWE_JAVA_HOME}/bin | grep java$ > /dev/null    # pick a file to check
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: ZOWE_JAVA_HOME does not point to a valid install of Java
#     fi
# else 
#     echo Error: ZOWE_JAVA_HOME is empty
# fi


# # • ZOWE_EXPLORER_HOST: The IP address of where the explorer servers are launched from. Defaults to
# # running hostname
# if [[ -n "${ZOWE_EXPLORER_HOST}" ]]
# then 
#     echo OK: ZOWE_EXPLORER_HOST is not empty 
#     ping ${ZOWE_EXPLORER_HOST} > /dev/null    # check host
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: ZOWE_EXPLORER_HOST does not point to a valid hostname
#     fi
# else 
#     echo Error: ZOWE_EXPLORER_HOST is empty
# fi

# # ZOE_SDSF_PATH="/usr/lpp/sdsf/java"
# if [[ -n "${ZOE_SDSF_PATH}" ]]
# then 
#     echo OK: ZOE_SDSF_PATH is not empty 
#     ls ${ZOE_SDSF_PATH}/classes | grep 'isfjcall\.jar'  > /dev/null    # check one .jar file
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: ZOE_SDSF_PATH does not point to a valid SDSF path
#     fi
# else 
#     echo Error: ZOE_SDSF_PATH is empty
# fi



# # ZOWE_IPADDRESS="9.20.5.48"
# if [[ -n "${ZOWE_IPADDRESS}" ]]
# then 
#     echo OK: ZOWE_IPADDRESS is not empty 
#     echo ${ZOWE_IPADDRESS} | grep '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*'  > /dev/null    # check one .jar file
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: ZOWE_IPADDRESS does not point to a numeric IP address
#     fi
        
#     ping ${ZOWE_IPADDRESS} > /dev/null    # check host
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: can not ping ZOWE_IPADDRESS ${ZOWE_IPADDRESS}
#     else
#         echo OK: can ping ZOWE_IPADDRESS ${ZOWE_IPADDRESS}
#     fi
# else 
#     echo Error: ZOWE_IPADDRESS is empty
# fi

# # • localhost: The IP address of this host
# # 
#     ping localhost > /dev/null    # check host
#     if [[ $? -ne 0 ]]
#     then    
#         echo Error: can not ping localhost
#     else
#         echo OK: can ping localhost
#     fi


# 0. IZUFPROC
echo
echo Check IZUFPROC

fPROC=1
# The PROC that z/OSMF uses to run your request
# It requires access to a link lib, and this is usually provided via a DD statement
#
# //ISPLLIB  DD DISP=SHR,DSN=SYS1.SIEALNKE <----extra dataset
#
# tsocmd listc "ent('SYS1.SIEALNKE')" 2>/dev/null| sed -n 's/^N.*- \(.*\)/\1/p'
tsocmd listd "('sys1.SIEALNKE')" 2> /dev/null 1> /dev/null
if [[ $? -eq 0 ]]
then
    : # echo OK: Dataset SYS1.SIEALNKE exists
else
    echo Warning: SYS1.SIEALNKE not found
    echo Another *.SIEALNKE dataset must be allocated in IZUFPROC, or link-listed
    fPROC=0
fi

# find IZUFPROC in PROCLIB concatenation
# ${ZOWE_ROOT_DIR}/scripts/internal/opercmd '$d proclib'

IZUFPROC_found=0        # set initial condition

# fetch a list of PROCLIBs
${ZOWE_ROOT_DIR}/scripts/internal/opercmd '$d proclib'| sed -n 's/.*DSNAME=\(.*[A-Z0-9]\).*/\1/p' > /tmp/proclib.list
while read dsn 
do
    tsocmd listd "('$dsn')" mem 2> /dev/null | grep IZUFPROC 1> /dev/null 2> /dev/null
    if [[ $? -ne 0 ]]
    then
        : # echo IZUFPROC not found in $dsn
    else
        : # echo OK: IZUFPROC found in $dsn
        IZUFPROC_found=1
        break
    fi
done <      /tmp/proclib.list
rm          /tmp/proclib.list

if [[ IZUFPROC_found -eq 0 ]]
then
    echo Error: PROC IZUFPROC not found in any active PROCLIB
    fPROC=0
else
    : # echo Check contents of IZUFPROC
    tsocmd "oput '$dsn(izufproc)' '/tmp/izufproc.txt'" 1> /dev/null 2> /dev/null
    SIEALNKE_DSN=`sed -n 's/.*DS.*=\(.*SIEALNKE\).*/\1/p' /tmp/izufproc.txt`    # check for DSN (but not ISPLLIB DD)

    if [[ $? -ne 0 ]]
    then
        echo Error: SIEALNKE not found in $dsn"(IZUFPROC)"
        fPROC=0
    else
        : # echo OK: Reference to SIEALNKE dataset $SIEALNKE_DSN found in $dsn"(IZUFPROC)"
        tsocmd listd "('$SIEALNKE_DSN')" 1> /dev/null 2> /dev/null
        if [[ $? -ne 0 ]]
        then
            echo Error: $SIEALNKE_DSN not found
            fPROC=0
        fi

        : # echo check that ISPLLIB is present # ... 
        grep "\/\/ISPLLIB *DD *" /tmp/izufproc.txt > /dev/null
        if [[ $? -ne 0 ]]
        then
            echo Error : No ISPLLIB DD statement found in IZUFPROC
            fPROC=0
        else
            : # echo OK: ISPLLIB DD statement found in IZUFPROC
            grep "\/\/ISPLLIB *DD *.*DS.*=.*SIEALNKE" /tmp/izufproc.txt > /dev/null
            if [[ $? -eq 0 ]]
            then
                : # echo OK: SIEALNKE dataset is allocated to ISPLLIB
            fi
        fi


    fi
fi
rm /tmp/izufproc.txt 2> /dev/null

if [[ $fPROC -eq 1 ]]
then    
    echo OK
fi

# 5. z/OSMF
echo
echo Check zosmfServer is ready to run a smarter planet
#  is zosmfServer ready to run a smarter planet?
zosmfMsgLog=/var/zosmf/data/logs/zosmfServer/logs/messages.log
ls $zosmfMsgLog 1> /dev/null 
if [[ $? -eq 0 ]]
then    
    # log file could be large ... msg is normally at record number 79.  Allow for 200.
    head -200 $zosmfMsgLog | iconv -f IBM-850 -t IBM-1047 | grep "zosmfServer is ready to run a smarter planet" > /dev/null
    if [[ $? -ne 0 ]]
    then    
        echo Error: zosmfServer is not ready to run a smarter planet # > /dev/null
    else
        echo OK
    fi
fi

echo 

# 6. Other required jobs
echo
echo Check servers are up


 echo
  echo Check jobs AXR CEA ICSF CSF  # jobs with no JCT
  jobsOK=1

  ICSF=0        #   neither ICSF nor CSF is running?
  for jobname in AXR CEA ICSF CSF
  do
    ${ZOWE_ROOT_DIR}/scripts/internal/opercmd d j,${jobname}|grep " ${jobname} .* A=[0-9,A-F][0-9,A-F][0-9,A-F][0-9,A-F] " >/dev/null
      # the selected line will look like this ...
      #  AXR      AXR      IEFPROC  NSW  *   A=001B   PER=NO   SMC=000
      
    if [[ $? -eq 0 ]]
    then 
        : # echo Job ${jobname} is executing
        if [[ ${jobname} = ICSF || ${jobname} = CSF ]]
        then
            ICSF=1
        fi
    else 
        if [[ ${jobname} = ICSF || ${jobname} = CSF ]]
        then
            :
        else 
            echo Error: Job ${jobname} is not executing
            jobsOK=0
        fi
        
    fi
  done

    if [[ ${ICSF} -eq 1 ]]
    then
    : # echo OK:  ICSF or CSF is running
    else
        echo Error:  neither ICSF nor CSF is running
        jobsOK=0
    fi

# 4.2 Jobs with JCT

for jobname in IZUANG1 IZUSVR1 # RACF
do
  tsocmd status ${jobname} 2>/dev/null | grep "JOB ${jobname}(S.*[0-9]*) EXECUTING" >/dev/null
  if [[ $? -eq 0 ]]
  then 
      : # echo Job ${jobname} is executing
  else 
      echo Error: Job ${jobname} is not executing
      jobsOK=0
  fi
done

if [[ $jobsOK -eq 1 ]]      
then 
    echo OK
fi

echo
echo Check CIM server is running

cim_error_status=0  # no errors yet

# Try to determine CIM server job name
${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d omvs,a=all" > /tmp/d.omvs.all.$$.txt
CIMSVR=`sed -n '/LATCHWAITPID/!h;/CMD=.*\/cimserver /{x;p;}' /tmp/d.omvs.all.$$.txt | awk '{ print $2 }'`
rm /tmp/d.omvs.all.$$.txt > /dev/null
if [[ -n "$CIMSVR" ]] then
    # echo CIM server job name is $CIMSVR
    ${ZOWE_ROOT_DIR}/scripts/internal/opercmd "d j,${CIMSVR}" | grep WUID=STC > /dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: CIMSVR job "${CIMSVR}" is not running as a started task
        cim_error_status=1
    fi
else
    echo Error:  Could not determine CIMSVR job name
    cim_error_status=1
fi
if [[ $cim_error_status -eq 0 ]]
then
    echo OK
fi

echo
echo Check relevant -s extattr bits 
ls -RE ${ZOWE_ROOT_DIR} |grep " [-a][-p]s[^ ] " > /tmp/extattr.s.list
bitsOK=1

for file in \
    zssServer 
do
    grep " ${file}$" /tmp/extattr.s.list 1>/dev/null 2>/dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: File $file does not have the -s extattr bit set
        bitsOK=0
    else
        : # echo File $file is OK
    fi
done
if [[ $bitsOK -eq 1 ]]
then
    echo OK
fi

echo
echo Check relevant -p extattr bits 
ls -RE ${ZOWE_ROOT_DIR} |grep " [-a]p[-s][^ ] " > /tmp/extattr.p.list
bitsOK=1
for file in \
    zssServer 
do
    grep " ${file}$" /tmp/extattr.p.list 1>/dev/null 2>/dev/null
    if [[ $? -ne 0 ]]
    then
        echo Error: File $file does not have the -p extattr bit set
        bitsOK=0
    else
        : # echo File $file is OK
    fi
done
if [[ $bitsOK -eq 1 ]]
then
    echo OK
fi

rm /tmp/extattr.*.list

echo
echo Check files are executable 
filesxeq=1
find ${ZOWE_ROOT_DIR} -name bin -exec ls -l {} \; \
    | grep ^- | grep -v \.bat$ | grep -v \.txt$ \
    | grep -v "^-r.xr.xr.x " | grep -v "^-r.xr.x... .* IZUADMIN " 2> /dev/null
if [[ $? -ne 0 ]]
then    
    : # echo OK: 
else 
    echo Error: the bin files above in ${ZOWE_ROOT_DIR} are not readable and executable 
    filesxeq=0
fi 

# check permission of parent directories.  Iterate back up to root directory, checking each is executable.
savedir=$PWD    # save CWD

cd ${ZOWE_ROOT_DIR}
while [[ 1 ]]
do
    ls -l ${PWD} | grep "^dr.x..x..x " 1> /dev/null 2> /dev/null
    if [[ $? -eq 0 ]]
    then    
        : # echo OK: ${PWD} is executable
    else 
        echo Error: ${PWD} is not executable
        filesxeq=0
    fi 
    if  [[ $PWD = "/" ]]
    then
        break
    fi
    cd ..
done

if [[ $filesxeq -eq 1 ]]
then 
    echo OK
fi

cd $savedir # restore CWD

echo
echo Script zowe-verify.sh finished
