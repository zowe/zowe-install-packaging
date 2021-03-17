#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2019, 2021
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
. ${ROOT_DIR}/bin/utils/utils.sh
get_install_log_directory "${INSTALL_LOG_DIR}"

RUNTIME_LOG_DIR=${INSTANCE_DIR}/logs

DATE=`date +%Y-%m-%d-%H-%M-%S`
SUPPORT_ARCHIVE_LOCATION=$RUNTIME_LOG_DIR
SUPPORT_ARCHIVE_NAME="zowe_support_${DATE}.pax"
SUPPORT_ARCHIVE=${SUPPORT_ARCHIVE_LOCATION}/${SUPPORT_ARCHIVE_NAME}
SUPPORT_ARCHIVE_LOG="${SUPPORT_ARCHIVE_LOCATION}/zowe_support_${DATE}.log"
PS_OUTPUT_FILE=${SUPPORT_ARCHIVE_LOCATION}"/ps_output"
VERSION_FILE=${SUPPORT_ARCHIVE_LOCATION}"/version_output"

ZOWE_STC=${ZOWE_PREFIX}${ZOWE_INSTANCE}SV

FILE_PATTERNS_COLLECTED=

export TEMP_DIR=${TMPDIR:-/tmp}

function psgrep {
    pattern=[^]]${1};
    # [^]] used to concatenate a static string to the pattern. Done to remove grep command from output
    ps -A -o pid,ppid,time,etime,user,jobname,args | grep -e "^[[:space:]]*PID" -e ${pattern}
}

function write_to_log {
    echo "$1" | tee -a ${SUPPORT_ARCHIVE_LOG}
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
    pax -wva -o saveext \
      ${SUBSTITUTION} \
      "-s#${ROOT_DIR}#ROOT_DIR#" \
      "-s#${INSTANCE_DIR}#INSTANCE_DIR#" \
      "-s#${INSTALL_LOG_DIR}#INSTALL_LOG_DIR#" \
      "-s#${KEYSTORE_DIRECTORY}#KEYSTORE_DIR#" \
      "-s#${TMPDIR:-/tmp}#TEMP_DIR#" \
      -f ${SUPPORT_ARCHIVE} \
      $1 2>&1 | tee -a ${SUPPORT_ARCHIVE_LOG}
}

function add_files_by_pattern_to_pax {
  FILE_DESCRIPTION=$1
  FILE_PATH=$2
  FILE_PATTERN=$3

  if [ -d "${FILE_PATH}" ]; then
    write_to_log "Collecting ${FILE_DESCRIPTION} (${FILE_PATTERN}) from ${FILE_PATH}"
    for file in $(find "${FILE_PATH}" -name "${FILE_PATTERN}" -type f) ; do
      FILE_PATTERNS_COLLECTED="${FILE_PATTERNS_COLLECTED} $file"
    done
  fi
}

function update_pax {
  pax -wva -o saveext \
    "-s#${ROOT_DIR}#ROOT_DIR#" \
    "-s#${INSTANCE_DIR}#INSTANCE_DIR#" \
    "-s#${INSTALL_LOG_DIR}#INSTALL_LOG_DIR#" \
    "-s#${KEYSTORE_DIRECTORY}#KEYSTORE_DIR#" \
    "-s#${TMPDIR:-/tmp}#TEMP_DIR#" \
    -f ${SUPPORT_ARCHIVE} \
    ${FILE_PATTERNS_COLLECTED} 2>&1 | tee -a ${SUPPORT_ARCHIVE_LOG}
}

write_to_log "============================================================================"
write_to_log "=                           Zowe Support Script                            ="
write_to_log ""
write_to_log "Started at ${DATE}"
write_to_log ""

# Collecting software versions
write_to_log "----------------------------------------------------------------------------"
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
write_to_log ""

# Collect process information
write_to_log "----------------------------------------------------------------------------"
write_to_log "Collecting current process information based on the following prefix: ${ZOWE_PREFIX}$ZOWE_INSTANCE"
psgrep $ZOWE_PREFIX$ZOWE_INSTANCE > $PS_OUTPUT_FILE
write_to_log "Adding ${PS_OUTPUT_FILE}"
add_to_pax $PS_OUTPUT_FILE process_info
rm $PS_OUTPUT_FILE
write_to_log ""

# Collect STC output
write_to_log "----------------------------------------------------------------------------"
write_to_log "Collecting STC output"
tsocmd status ${ZOWE_STC} 2>/dev/null | \
    sed -n 's/.*JOB *\([^ ]*\)(\([^ ]*\)) ON OUTPUT QUEUE.*/\1 \2/p' > ${TEMP_DIR}/jobname.jobid.$$.list
while read jobname jobid
do
  write_to_log "Collecting output for Zowe started task $jobname($jobid)"
  STC_FILE=${TEMP_DIR}/$jobname-$jobid.log   # print-joblog-to-file.sh will create a file of this name    
  ${ROOT_DIR}/bin/utils/print-joblog-to-file.sh $jobname $jobid $STC_FILE | tee -a ${SUPPORT_ARCHIVE_LOG}
  write_to_log "Return code from print-joblog-to-file.sh was $?"
  if [ -f "${$STC_FILE}" ]; then
    add_files_by_pattern_to_pax "STC log file" "${TEMP_DIR}" "${jobname}-${jobid}.log"
    rm $STC_FILE
  else
    write_to_log "${STC_FILE} is not created"
  fi
done < ${TEMP_DIR}/jobname.jobid.$$.list
rm     ${TEMP_DIR}/jobname.jobid.$$.list
write_to_log ""

# Collect install logs
write_to_log "----------------------------------------------------------------------------"
add_files_by_pattern_to_pax "installation log files" "${INSTALL_LOG_DIR}" "*"
write_to_log ""

# Collect configs
write_to_log "----------------------------------------------------------------------------"
add_files_by_pattern_to_pax "Zowe manifest" "$ROOT_DIR" "manifest.json"
add_files_by_pattern_to_pax "env configs" "${INSTANCE_DIR}" "instance.env"
add_files_by_pattern_to_pax "YAML configs" "${INSTANCE_DIR}" "zowe.yaml"
add_files_by_pattern_to_pax "temporary configuration files" "${INSTANCE_DIR}/.env" '*'
add_files_by_pattern_to_pax "keystore env configs" "${KEYSTORE_DIRECTORY}" "zowe-*.env"
add_files_by_pattern_to_pax "keystore YAML configs" "${KEYSTORE_DIRECTORY}" "*.yaml"
write_to_log ""

# Collect api-definitions
write_to_log "----------------------------------------------------------------------------"
API_DEFS_DIRECTORY="${INSTANCE_DIR}/workspace/api-mediation/api-defs"
add_files_by_pattern_to_pax "instance static definition files" "${API_DEFS_DIRECTORY}" "*.yml"
write_to_log ""

if [[ -d $ROOT_DIR/fingerprint ]]
then 
  write_to_log "----------------------------------------------------------------------------"
  write_to_log "Collecting fingerprint"
  add_files_by_pattern_to_pax "reference runtime hash" "${ROOT_DIR}/fingerprint" "*"
  $ROOT_DIR/bin/zowe-verify-authenticity.sh -l $SUPPORT_ARCHIVE_LOCATION
  add_files_by_pattern_to_pax "customer runtime hash" "${SUPPORT_ARCHIVE_LOCATION}" "CustRuntimeHash.*"
  add_files_by_pattern_to_pax "customer runtime hash" "${SUPPORT_ARCHIVE_LOCATION}" "RefRuntimeHash.*"
  write_to_log ""
fi

# Collect instance logs
write_to_log "----------------------------------------------------------------------------"
add_files_by_pattern_to_pax "instance log files" "${RUNTIME_LOG_DIR}" "*.log"
write_to_log ""

# TODO - collect all the rest of workspace directory?

write_to_log "----------------------------------------------------------------------------"
write_to_log "Write pax file"
update_pax
# Compress pax file
compress ${SUPPORT_ARCHIVE}
write_to_log ""

# Clean up
rm -f ${SUPPORT_ARCHIVE_LOG}

# Print final message
echo "============================================================================"
echo "The support file was created ${SUPPORT_ARCHIVE}.Z"
