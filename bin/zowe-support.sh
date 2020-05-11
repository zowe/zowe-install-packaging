#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019, 2020
################################################################################

while getopts "l:" opt; do
  case $opt in
    l) INSTALL_LOG_DIR=$OPTARG;;
    \?)
      echo "Invalid option: -$opt" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

. ${ROOT_DIR}/bin/internal/zowe-set-env.sh

# Get the log directory either from -l, or from default locations setting INSTALL_LOG_DIR
. ${ROOT_DIR}/bin/utils/setup-log-dir.sh
get_install_log_directory ${INSTALL_LOG_DIR}

RUNTIME_LOG_DIR=${INSTANCE_DIR}/logs

DATE=`date +%Y-%m-%d-%H-%M-%S`
SUPPORT_ARCHIVE_LOCATION=$RUNTIME_LOG_DIR
SUPPORT_ARCHIVE_NAME="zowe_support_${DATE}.pax"
SUPPORT_ARCHIVE=${SUPPORT_ARCHIVE_LOCATION}/${SUPPORT_ARCHIVE_NAME}
SUPPORT_ARCHIVE_LOG="${SUPPORT_ARCHIVE_LOCATION}/zowe_support_${DATE}.log"
PS_OUTPUT_FILE=${SUPPORT_ARCHIVE_LOCATION}"/ps_output"
VERSION_FILE=${SUPPORT_ARCHIVE_LOCATION}"/version_output"

ZOWE_STC=${ZOWE_PREFIX}${ZOWE_INSTANCE}SV

function psgrep {
    pattern=[^]]${1};
    # [^]] used to concatenate a static string to the pattern. Done to remove grep command from output
    ps -A -o pid,ppid,time,etime,user,jobname,args | grep -e "^[[:space:]]*PID" -e ${pattern}
}

function write_to_log {
    echo $1 | tee -a ${SUPPORT_ARCHIVE_LOG}
}

function add_to_pax {
    case $2 in
        process_info)
            SUBSTITUTION="-s#${SUPPORT_ARCHIVE_LOCATION}#PS_OUTPUT_FILE#"
        ;;
        version_file)
            SUBSTITUTION="-s#${SUPPORT_ARCHIVE_LOCATION}#VERSION_FILE#"
        ;;
        support_archive_log)
            SUBSTITUTION="-s#${SUPPORT_ARCHIVE_LOCATION}#SUPPORT_LOG#"
        ;;
        zlux_server_log)
            SUBSTITUTION="-s#${ZOWE_INSTALL_ZLUX_SERVER_LOG}#ZLUX_SERVER_LOG-#"
        ;;
        *)  # basic command (no substitution is applied)
            SUBSTITUTION=""
        ;;
    esac
    pax -wva -o saveext ${SUBSTITUTION} -s#${ROOT_DIR}#ROOT_DIR# -s#${INSTANCE_DIR}#INSTANCE_DIR# -s#${INSTALL_LOG_DIR}#INSTALL_LOG_DIR# -s#${KEYSTORE_DIRECTORY}#KEYSTORE_DIR# -s#${TMPDIR:-/tmp}#TEMP_DIR# -f ${SUPPORT_ARCHIVE}  $1 2>&1 | tee -a ${SUPPORT_ARCHIVE_LOG}
}

function add_file_to_pax_if_found {
    FILE_PATH=$1
    if [[ -f ${FILE_PATH} ]];then
        write_to_log "Collecting ${FILE_PATH}"
        add_to_pax ${FILE_PATH}
    else
        write_to_log "File ${FILE_PATH} was not found."
    fi
}

# Collecting software versions
write_to_log "Collecting version of z/OS, Java, NodeJS"
ZOS_VERSION=`${ROOT_DIR}/scripts/internal/opercmd "D IPLINFO" | grep -i release | xargs`
write_to_log "  - z/OS: $ZOS_VERSION"
JAVA_VERSION=`$JAVA_HOME/bin/java -version 2>&1 | head -n 1`
write_to_log "  - Java: $JAVA_VERSION"
NODE_VERSION=`$NODE_HOME/bin/node --version`
write_to_log "  - NodeJS: $NODE_VERSION"
echo "z/OS version: "$ZOS_VERSION > $VERSION_FILE
echo "Java version: "$JAVA_VERSION >> $VERSION_FILE
echo "NodeJS version: "$NODE_VERSION >> $VERSION_FILE
add_to_pax $VERSION_FILE version_file
rm $VERSION_FILE

# Collect process information
write_to_log "Collecting current process information based on the following prefix: ${ZOWE_PREFIX}$ZOWE_INSTANCE"
psgrep $ZOWE_PREFIX$ZOWE_INSTANCE > $PS_OUTPUT_FILE
write_to_log "Adding ${PS_OUTPUT_FILE}"
add_to_pax $PS_OUTPUT_FILE process_info
rm $PS_OUTPUT_FILE

# Collect STC output
export TEMP_DIR=${TMPDIR:-/tmp}

tsocmd status ${ZOWE_STC} 2>/dev/null | \
    sed -n 's/.*JOB *\([^ ]*\)(\([^ ]*\)) ON OUTPUT QUEUE.*/\1 \2/p' > ${TEMP_DIR}/jobname.jobid.$$.list
while read jobname jobid
do
    write_to_log "Collecting output for Zowe started task $jobname($jobid)"
    STC_FILE=${TEMP_DIR}/$jobname-$jobid.log   # print-joblog-to-file.sh will create a file of this name    
    ${ROOT_DIR}/bin/utils/print-joblog-to-file.sh $jobname $jobid $STC_FILE | tee -a ${SUPPORT_ARCHIVE_LOG}
    write_to_log "Return code from print-joblog-to-file.sh was $?"
    add_to_pax $STC_FILE
    rm $STC_FILE
done < ${TEMP_DIR}/jobname.jobid.$$.list
rm     ${TEMP_DIR}/jobname.jobid.$$.list

# Collect install logs
if [[ -d ${INSTALL_LOG_DIR} ]];then
    write_to_log "Collecting installation log files from ${INSTALL_LOG_DIR}:"
    add_to_pax ${INSTALL_LOG_DIR} installation_log *.log
else
    write_to_log "Directory ${INSTALL_LOG_DIR} was not found."
fi

# Collect rest of logs
if [[ -d ${RUNTIME_LOG_DIR} ]];then
    write_to_log "Collecting instance log files from ${RUNTIME_LOG_DIR}:"
    add_to_pax ${RUNTIME_LOG_DIR} instance_logs *.log
else
    write_to_log "Directory ${RUNTIME_LOG_DIR} was not found."
fi

# Collect api-definitions
API_DEFS_DIRECTORY="${INSTANCE_DIR}/workspace/api-mediation/api-defs"
if [[ -d ${API_DEFS_DIRECTORY} ]];then
    write_to_log "Collecting instance static definition files from ${API_DEFS_DIRECTORY}:"
    add_to_pax ${API_DEFS_DIRECTORY} api-defs *.yml
else
    write_to_log "Directory ${API_DEFS_DIRECTORY} was not found."
fi

# TODO - collect all the rest of workspace directory?
add_file_to_pax_if_found "${INSTANCE_DIR}/instance.env"
add_file_to_pax_if_found "${KEYSTORE_DIRECTORY}/zowe-certificates.env"
add_file_to_pax_if_found "$ROOT_DIR/manifest.json"

# Add support log file to pax
write_to_log "Adding ${SUPPORT_ARCHIVE_LOG}"
add_to_pax ${SUPPORT_ARCHIVE_LOG} support_archive_log
rm ${SUPPORT_ARCHIVE_LOG}

# Compress pax file
compress ${SUPPORT_ARCHIVE}

# Print final message
echo "The support file was created ${SUPPORT_ARCHIVE}.Z"
