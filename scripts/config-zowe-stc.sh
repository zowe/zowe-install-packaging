#!/bin/sh
#  Configure Zowe as a started task

# The user of this script must be authorized to issue the necessary commands to the installed security product

# • If you use RACF, issue the following commands:
# RDEFINE STARTED ${ZOWESVR}.* UACC(NONE) STDATA(USER(IZUSVR) GROUP(IZUADMIN)
# PRIVILEGED(NO) TRUSTED(NO) TRACE(YES))
# SETROPTS REFRESH RACLIST(STARTED)

# • If you use CA ACF2, issue the following commands:
# SET CONTROL(GSO)
# INSERT STC.${ZOWESVR} LOGONID(IZUSVR) GROUP(IZUADMIN) STCID(${ZOWESVR})
# F ACF2,REFRESH(STC)

# • If you use CA Top Secret, issue the following commands:
# TSS ADDTO(STC) PROCNAME(${ZOWESVR}) ACID(IZUSVR)

echo Script config-zowe-stc.sh started

if [[ -n "$ZOWESVR" ]]
then
    echo Zowe server name is $ZOWESVR
else
    echo Zowe server name is not set, defaulting to ZOWESVR
    ZOWESVR=ZOWESVR
fi

echo
echo Detecting active SAF security product

function checkJob {
jobname=$1
tsocmd status ${jobname} 2> /dev/null | grep "JOB ${jobname}(S.*[0-9]*) EXECUTING" >/dev/null
if [[ $? -ne 0 ]]
then 
    echo Info: job ${jobname} is not executing
    return 1
else 
    echo OK: job ${jobname} is executing
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
        tsocmd "RDEFINE STARTED ${ZOWESVR}.* UACC(NONE) STDATA(USER(IZUSVR) GROUP(IZUADMIN) PRIVILEGED(NO) TRUSTED(NO) TRACE(YES))" \
            1> /tmp/cmd.out 2> /tmp/cmd.err 
        if [[ $? -ne 0 ]]
        then
            echo Error: RDEFINE failed
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
            echo Error: "SET CONTROL(GSO) failed"
            cat /tmp/cmd.out /tmp/cmd.err
        else
            tsocmd "INSERT STC.${ZOWESVR} LOGONID(IZUSVR) GROUP(IZUADMIN) STCID(${ZOWESVR})" \
                1> /tmp/cmd.out 2> /tmp/cmd.err 
            if [[ $? -ne 0 ]]
            then
                echo Error: "INSERT STC failed"
                cat /tmp/cmd.out /tmp/cmd.err
            else
                if [[ -n "$ZOWE_ROOT_DIR" ]]
                then
                    if [[ -x $ZOWE_ROOT_DIR/scripts/internal/opercmd ]]
                    then 
                        $ZOWE_ROOT_DIR/scripts/internal/opercmd "F ACF2,REFRESH(STC)" 1> /dev/null 2> /dev/null \
                            1> /tmp/cmd.out 2> /tmp/cmd.err 
                        if [[ $? -ne 0 ]]
                        then
                            echo Error: "ACF2 REFRESH failed"
                            cat /tmp/cmd.out /tmp/cmd.err
                        else
                            echo OK: ACF2 setup complete
                        fi
                    else 
                        echo Error: opercmd is missing or not executable
                    fi 
                else
                    echo Error: ZOWE_ROOT_DIR is not set, ACF2 REFRESH not run
                fi
            fi            
        fi 
        ;;

    TSS)
        tsocmd "TSS ADDTO(STC) PROCNAME(${ZOWESVR}) ACID(IZUSVR)" \
            1> /tmp/cmd.out 2> /tmp/cmd.err 
        if [[ $? -ne 0 ]]
        then
            echo Error: "TSS ADDTO(STC) failed"
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
echo Script config-zowe-stc.sh ended