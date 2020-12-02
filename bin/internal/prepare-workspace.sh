#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2020
################################################################################

################################################################################
# This script will run component `validate` and `configure` step if they are defined.
#
# This script take these parameters
# - c:    INSTANCE_DIR
# - t:    a list of component IDs or paths to component lifecycle script directory
#         separated by comma
#
# For example:
# $ bin/internal/prepare-workspace.sh \
#        -c "/path/to/my/zowe/instance" \
#        -t "discovery,explorer-jes,jobs"
################################################################################

# if the user passes INSTANCE_DIR from command line parameter "-c"
while getopts "c:t:" opt; do
  case ${opt} in
    c) INSTANCE_DIR=${OPTARG};;
    t) LAUNCH_COMPONENTS=${OPTARG};;
    \?)
      echo "Invalid option: -${OPTARG}" >&2
      exit 1
      ;;
  esac
done

########################################################
# prepare environment variables
export ROOT_DIR=$(cd $(dirname $0)/../../;pwd)
. ${ROOT_DIR}/bin/internal/prepare-environment.sh -c "${INSTANCE_DIR}"

########################################################
# setup global logging properties
# Handle log file syntax setup here so that the timestamps for all components match
# Determine if components should log to a file, and where
# FIXME: Zowe Launcher should probably do this file logging logic instead
if [ -z "$ZWE_NO_LOGFILE" ]
then
  if [ -z "$ZWE_LOG_DIR" ]
  then
    export ZWE_LOG_DIR=${INSTANCE_DIR}/logs
  fi
  if [ -f "$ZWE_LOG_DIR" ]
  then
    export ZWE_NO_LOGFILE=1
  elif [ ! -d "$ZWE_LOG_DIR" ]
  then
    echo "Will make log directory $ZWE_LOG_DIR"
    mkdir -p $ZWE_LOG_DIR
    if [ $? -ne 0 ]
    then
      echo "Cannot make log directory.  Logging disabled."
      export ZWE_NO_LOGFILE=1
    fi
  fi
  export ZWE_ROTATE_LOGS=0
  if [ -d "$ZWE_LOG_DIR" ]
  then
    LOG_SUFFIX="-`date +%Y-%m-%d-%H-%M`"
    if [ -z "$ZWE_LOGS_TO_KEEP" ]
    then
      export ZWE_LOGS_TO_KEEP=5
    fi
    echo $ZWE_LOGS_TO_KEEP|egrep '^\-?[0-9]+$' >/dev/null
    if [ $? -ne 0 ]
    then
      echo "ZWE_LOGS_TO_KEEP not a number.  Defaulting to 5."
      export ZWE_LOGS_TO_KEEP=5
    fi
    if [ $ZWE_LOGS_TO_KEEP -ge 0 ]
    then
      export ZWE_ROTATE_LOGS=1
    fi
  fi
fi

get_log_filename() {
  component_id=$1
  component_dir=$2
  LOG_PREFIX=$3
  if [ -d "${component_id}" ]; then
    COMPONENT_NAME=$(cd ${component_dir}/ && echo "${PWD##*/}")
  else
    COMPONENT_NAME=$component_id
  fi

  if [ "${COMPONENT_NAME}" = "zss" ]; then
    COMPONENT_NAME="zssServer" #backwards compatibility
  elif [ "${COMPONENT_NAME}" = "app-server" ]; then
    COMPONENT_NAME="appServer" #backwards compatibility
  fi
  
  LOG_FILE="${ZWE_LOG_DIR}/${LOG_PREFIX}${COMPONENT_NAME}${LOG_SUFFIX}.log"
  if [ -e "$LOG_FILE" ]; then
     echo $LOG_FILE
  fi
}

create_log_file() {
  component_id=$1
  component_dir=$2
  LOG_PREFIX=$3
  if [ -z "$ZWE_NO_LOGFILE" ]; then
    #set up log file, if requested
    if [ -d "${component_id}" ]; then
      COMPONENT_NAME=$(cd ${component_dir}/ && echo "${PWD##*/}")
    else
      COMPONENT_NAME=$component_id
    fi
  
    if [ "${COMPONENT_NAME}" = "zss" ]; then
      COMPONENT_NAME="zssServer" #backwards compatibility
    elif [ "${COMPONENT_NAME}" = "app-server" ]; then
      COMPONENT_NAME="appServer" #backwards compatibility
    fi

    ZWE_LOG_FILE="${ZWE_LOG_DIR}/${LOG_PREFIX}${COMPONENT_NAME}${LOG_SUFFIX}.log"
    
    if [ ! -e "$ZWE_LOG_FILE" ]; then
      touch "$ZWE_LOG_FILE"
      if [ $? -ne 0 ]; then
        echo "Cannot make log file '$ZWE_LOG_FILE'.  Logging disabled."
        ZWE_LOG_FILE=
      fi
    else
      if [ -d "$ZWE_LOG_FILE" ]; then
        echo "ZWE_LOG_FILE '$ZWE_LOG_FILE' is a directory.  Must be a file.  Logging disabled."
        ZWE_LOG_FILE=
      fi
    fi
    if [ ! -w "$ZWE_LOG_FILE" ]; then
      echo "file '$ZWE_LOG_FILE' is not writable. Logging disabled."
      ZWE_LOG_FILE=
    fi
  fi
  if [ -n "$ZWE_LOG_FILE" ]; then
    #Clean up excess logs, if appropriate.
    if [ $ZWE_ROTATE_LOGS -ne 0 ]; then
      for f in `ls -r -1 $ZWE_LOG_DIR/${LOG_PREFIX}${COMPONENT_NAME}-*.log 2>/dev/null | tail +$ZWE_LOGS_TO_KEEP`
      do
        echo "${component_id} removing old log file '$f'"
        rm -f $f
      done
    fi
    echo "${component_id} log file=${ZWE_LOG_FILE}"
  fi
}


########################################################
# Validate component properties if script exists
ERRORS_FOUND=0
for component_id in $(echo "${LAUNCH_COMPONENTS}" | sed "s/,/ /g")
do
  component_dir=$(find_component_directory "${component_id}")
  # backward compatible purpose, some may expect this variable to be component lifecycle directory
  export LAUNCH_COMPONENT="${component_dir}/bin"

  # FIXME: change here to read manifest `commands.validate` entry
  validate_script=${component_dir}/bin/validate.sh
  if [ ! -z "${component_dir}" -a -x "${validate_script}" ]; then
    # create log file if file logging enabled
    create_log_file $component_id $component_dir "validate-"
    LOG_FILE=$(get_log_filename $component_id $component_dir "validate-")

    if [ -n "$LOG_FILE" ]; then
      { . ${validate_script} 2>&1 ; let "ERRORS_FOUND=${ERRORS_FOUND}+$?" ; } | tee $LOG_FILE
    else
      . ${validate_script}
      retval=$?
    fi    
    
    let "ERRORS_FOUND=${ERRORS_FOUND}+${retval}"
  fi
done
# exit if there are errors found
check_for_errors_found

########################################################
# Prepare workspace directory
mkdir -p ${WORKSPACE_DIR}
# Make accessible to group so owning user can edit?
chmod -R 771 ${WORKSPACE_DIR}

# Copy manifest into WORKSPACE_DIR so we know the version for support enquiries/migration
cp ${ROOT_DIR}/manifest.json ${WORKSPACE_DIR}

# Keep config dir for zss within permissions it accepts
# FIXME: this should be moved to zlux/bin/configure.sh.
#        Ideally we want this removed entirely as it stops uses from being able 
#        to delete the instance directory and can cause errors on upgrade
if [ -d ${WORKSPACE_DIR}/app-server/serverConfig ]
then
  chmod 750 ${WORKSPACE_DIR}/app-server/serverConfig
  chmod -R 740 ${WORKSPACE_DIR}/app-server/serverConfig/*
fi

########################################################
# Prepare workspace directory - manage active_configuration.cfg
mkdir -p ${WORKSPACE_DIR}/backups

#Backup previous directory if it exists
if [[ -f ${WORKSPACE_DIR}"/active_configuration.cfg" ]]
then
  PREVIOUS_DATE=$(cat ${WORKSPACE_DIR}/active_configuration.cfg | grep CREATION_DATE | cut -d'=' -f2)
  mv ${WORKSPACE_DIR}/active_configuration.cfg ${WORKSPACE_DIR}/backups/backup_configuration.${PREVIOUS_DATE}.cfg
fi

# Create a new active_configuration.cfg properties file with all the parsed parmlib properties stored in it,
NOW=$(date +"%y.%m.%d.%H.%M.%S")
ZOWE_VERSION=$(cat ${ROOT_DIR}/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
cp ${INSTANCE_DIR}/instance.env ${WORKSPACE_DIR}/active_configuration.cfg
cat <<EOF >> ${WORKSPACE_DIR}/active_configuration.cfg

# === zowe-certificates.env
EOF
cat ${KEYSTORE_DIRECTORY}/zowe-certificates.env >> ${WORKSPACE_DIR}/active_configuration.cfg
cat <<EOF >> ${WORKSPACE_DIR}/active_configuration.cfg

# === extra information
VERSION=${ZOWE_VERSION}
CREATION_DATE=${NOW}
ROOT_DIR=${ROOT_DIR}
STATIC_DEF_CONFIG_DIR=${STATIC_DEF_CONFIG_DIR}
LAUNCH_COMPONENTS=${LAUNCH_COMPONENTS}
EOF

########################################################
# Run setup/configure on components if script exists
for component_id in $(echo "${LAUNCH_COMPONENTS}" | sed "s/,/ /g")
do
  component_dir=$(find_component_directory "${component_id}")
  # backward compatible purpose, some may expect this variable to be component lifecycle directory
  export LAUNCH_COMPONENT="${component_dir}/bin"
  # FIXME: change here to read manifest `commands.configure` entry
  configure_script=${component_dir}/bin/configure.sh
  if [ ! -z "${component_dir}" -a -x "${configure_script}" ]; then
    # create log file if file logging enabled
    create_log_file $component_id $component_dir "configure-"
    LOG_FILE=$(get_log_filename $component_id $component_dir "configure-")
    
    if [ -n "$LOG_FILE" ]; then
      . ${configure_script} 2>&1 | tee $LOG_FILE
    else
      . ${configure_script}
    fi
  fi
done
