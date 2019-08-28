#!/bin/sh

# Variable Definition
VAR=`dirname $0`			# Obtain the scripts directory name
cd $VAR/..				    # Change to its parent which should be ZOWE_ROOT_DIR
ZOWE_ROOT_DIR={{root_dir}}		# Set our environment variable
ZOWE_PREFIX={{zowe_prefix}}{{zowe_instance}}
ZOWE_INSTALL_LOG_DIR=${ZOWE_ROOT_DIR}/install_log/
ZOWE_CONFIGURE_LOG_DIR=${ZOWE_ROOT_DIR}/configure_log/
ZOWE_INSTALL_ZLUX_SERVER_LOG=${ZOWE_ROOT_DIR}/zlux-app-server/log/

DATE=`date +%Y-%m-%d-%H-%M-%S`
SUPPORT_ARCHIVE_LOCATION=$ZOWE_INSTALL_LOG_DIR
SUPPORT_ARCHIVE_NAME="zowe_support_${DATE}.pax"
SUPPORT_ARCHIVE=${SUPPORT_ARCHIVE_LOCATION}${SUPPORT_ARCHIVE_NAME}
SUPPORT_ARCHIVE_LOG="${SUPPORT_ARCHIVE_LOCATION}zowe_support_${DATE}.log"
PS_OUTPUT_FILE=${SUPPORT_ARCHIVE_LOCATION}"ps_output"
VERSION_FILE=${SUPPORT_ARCHIVE_LOCATION}"version_output"

# These variables should be populated during installation process
NODE_HOME={{node_home}}
ZOWE_JAVA_HOME={{java_home}}
ZOWE_STC={{stc_name}}

# In case NODE_HOME, JAVA_HOME, ZOWE_STC and ZOWE_PREFIX are empty
# this script sould exit with a warning message
if [[ -z "${NODE_HOME}" ]];then
    echo "The NODE_HOME environment variable wasn't properly populated during install. Exiting."
    exit
fi
if [[ -z "${ZOWE_JAVA_HOME}" ]];then
    echo "The JAVA_HOME environment variable wasn't properly populated during install. Exiting."
    exit
fi
if [[ -z "${ZOWE_STC}" ]];then
    echo "The ZOWE_STC environment variable wasn't properly populated during install. Exiting."
    exit
fi
if [[ -z "${ZOWE_PREFIX}" ]];then
    echo "The ZOWE_PREFIX environment variable wasn't properly populated during install. Exiting."
    exit
fi
if [[ -z "${ZOWE_INSTANCE}" ]];then
    echo "The ZOWE_INSTANCE environment variable wasn't properly populated during install. Exiting."
    exit
fi
# Function Definition
# Not really sure if we should use this, it takes a lot of time to search in directory tree
# Alternative is to count on the directory structure, and assume that needed files are there
function realpath {
    # returns full file specification (full path)
    echo $(cd $(dirname ${1}); pwd)/$(basename ${1});
}

function findfile {
    # finds a file in a given directory tree (all subdirs) and returns it with full path
    file_path="$(find ${1} -name ${2} -print)";
    realpath ${file_path};
}

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
            SUBSTITUTION="-s#${SUPPORT_ARCHIVE_LOCATION}#PS_OUTPUT_FILE-#"
        ;;
        version_file)
            SUBSTITUTION="-s#${SUPPORT_ARCHIVE_LOCATION}#VERSION_FILE-#"
        ;;
        installation_log)
            SUBSTITUTION="-s#${ZOWE_INSTALL_LOG_DIR}#INSTALL_LOG-#"
        ;;
        support_archive_log)
            SUBSTITUTION="-s#${SUPPORT_ARCHIVE_LOCATION}#SUPPORT_LOG-#"
        ;;
        zlux_server_log)
            SUBSTITUTION="-s#${ZOWE_INSTALL_ZLUX_SERVER_LOG}#ZLUX_SERVER_LOG-#"
        ;;
        run_zowe_sh)
            SUBSTITUTION="-s$3"
        ;;
        *)  # basic command (no substitution is applied)
            SUBSTITUTION=""
        ;;
    esac
    pax -wva -o saveext ${SUBSTITUTION} -f ${SUPPORT_ARCHIVE}  $1 2>&1 | tee -a ${SUPPORT_ARCHIVE_LOG}
}

# Collecting software versions
write_to_log "Collecting version of z/OS, Java, NodeJS"
ZOS_VERSION=`${ZOWE_ROOT_DIR}/scripts/internal/opercmd "D IPLINFO" | grep -i release | xargs`
write_to_log "  - z/OS "$ZOS_VERSION
JAVA_VERSION=`$ZOWE_JAVA_HOME/bin/java -version 2>&1 | head -n 1`
write_to_log "  - Java "$JAVA_VERSION
NODE_VERSION=`$NODE_HOME/bin/node --version`
write_to_log "  - NodeJS "$NODE_VERSION
echo "z/OS version: "$ZOS_VERSION > $VERSION_FILE
echo "Java version: "$JAVA_VERSION >> $VERSION_FILE
echo "NodeJS version: "$NODE_VERSION >> $VERSION_FILE
add_to_pax $VERSION_FILE version_file
rm $VERSION_FILE

# Collect the manifest file
write_to_log "Collecting manifest.json"
add_to_pax $ZOWE_ROOT_DIR/manifest.json

# Collect process information
write_to_log "Collecting current process information based on the following prefix: ${ZOWE_PREFIX}$ZOWE_INSTANCE"
psgrep $ZOWE_PREFIX$ZOWE_INSTANCE > $PS_OUTPUT_FILE
write_to_log "Adding ${PS_OUTPUT_FILE}"
add_to_pax $PS_OUTPUT_FILE process_info
rm $PS_OUTPUT_FILE

# Collect STC output
STC_JOBS=`tsocmd "STATUS ${ZOWE_STC}" 2>/dev/null | grep 'ON OUTPUT' | cut -d' ' -f3`
for STC in ${STCS[*]}
do
    write_to_log "Collecting output for Zowe started task ${STC}"
    STC_FILE = `echo ${STC} | tr '()' '-.'`log
    tsocmd "output ${STC}" > $STC_FILE
    add_to_pax $STC_FILE
    rm $STC_FILE
done

# Collect install logs
if [[ -d ${ZOWE_INSTALL_LOG_DIR} ]];then
    write_to_log "Collecting installation log files from ${ZOWE_INSTALL_LOG_DIR}:"
    add_to_pax ${ZOWE_INSTALL_LOG_DIR} installation_log *.log
else
    write_to_log "Directory ${ZOWE_INSTALL_LOG_DIR} was not found."
fi

# Collect configure logs
if [[ -d ${ZOWE_CONFIGURE_LOG_DIR} ]];then
    write_to_log "Collecting configure log files from ${ZOWE_CONFIGURE_LOG_DIR}:"
    add_to_pax ${ZOWE_CONFIGURE_LOG_DIR} configure_log *.log
else
    write_to_log "Directory ${ZOWE_CONFIGURE_LOG_DIR} was not found."
fi

# Collect launch scripts
set +A SCRIPTS '/zlux-app-server/bin/nodeCluster.sh'\
 '/api-mediation/scripts/api-mediation-start-discovery.sh'\
 '/api-mediation/scripts/api-mediation-start-catalog.sh'\
 '/api-mediation/scripts/api-mediation-start-gateway.sh'\
 '/explorer-jobs-api/scripts/jobs-api-server-start.sh'\
 '/explorer-data-sets-api/scripts/data-sets-api-server-start.sh'\
 '/jes_explorer/scripts/start-explorer-jes-ui-server.sh'\
 '/mvs_explorer/scripts/start-explorer-mvs-ui-server.sh'\
 '/uss_explorer/scripts/start-explorer-uss-ui-server.sh'

for SCRIPT in ${SCRIPTS[*]}
do
    write_to_log "Collecting launch script ${SCRIPT}"
    add_to_pax ${ZOWE_ROOT_DIR}/${SCRIPT}
done

# Getting zlux-server log
if [[ -d ${ZOWE_INSTALL_ZLUX_SERVER_LOG} ]];then
    write_to_log "Adding ${ZOWE_INSTALL_ZLUX_SERVER_LOG}"
    add_to_pax ${ZOWE_INSTALL_ZLUX_SERVER_LOG} zlux_server_log
else
    write_to_log "Directory ${ZOWE_INSTALL_ZLUX_SERVER_LOG} was not found."
fi

# Add support log file to pax
write_to_log "Adding ${SUPPORT_ARCHIVE_LOG}"
add_to_pax ${SUPPORT_ARCHIVE_LOG} support_archive_log
rm ${SUPPORT_ARCHIVE_LOG}

# Compress pax file and delete the uncompressed one
pax -wzf ${SUPPORT_ARCHIVE}.Z ${SUPPORT_ARCHIVE}
rm ${SUPPORT_ARCHIVE}

# Print final message
echo "The support file was created, pass it to support guys. Thanks."
echo ${SUPPORT_ARCHIVE}.Z

# done
