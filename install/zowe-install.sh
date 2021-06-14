#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2021
################################################################################

################################################################################
# Zowe installation script
#
# This script will install the extracted Zowe package into target directory.
#
# Command line options:
# - i: installation target. This is required.
# - h: DSN prefix. This is required when installing on z/OS.
# - l: log directory. This is optional. Default value is /global/zowe/logs or
#      ~/zowe/logs if /global/zow is not writable.
# - f: log file. This is optional. It provides option to direct all installation
#      logs into one file. This option is deprecated in favor of "-l" option.
################################################################################

################################################################################
# Functions
separator() {
    echo "---------------------------------------------------------------------"
}

usage() {
  if [ "${RUN_ON_ZOS}" = "true" ]; then
    echo "Usage: $0 -i <zowe_install_path> -h <zowe_dsn_prefix> [-l <log_directory>]"
  else
    echo "Usage: $0 -i <zowe_install_path> [-l <log_directory>]"
  fi
  exit 1
}

show_usage_error_and_exit() {
  message=$1

  echo "Error: ${message}" >&2
  usage
}

prepare_temp_dir() {
  # Create a temp directory to be a working directory for sed replacements and logs, if install_dir is read-only then put it in ${TMPDIR}/'/tmp\'
  if [[ -w "${INSTALL_DIR}" ]]
  then
    export TEMP_DIR=${INSTALL_DIR}/temp_"`date +%Y-%m-%d`"
  else
    export TEMP_DIR=${TMPDIR:-/tmp}/zowe_"`date +%Y-%m-%d`"
  fi
  mkdir -p $TEMP_DIR
  chmod a+rwx $TEMP_DIR
}

prepare_log_file() {
  if [[ -z "${LOG_FILE}" ]]
  then
    set_install_log_directory "${LOG_DIRECTORY}"
    validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
    set_install_log_file "zowe-install"
  else
    set_install_log_file_from_full_path "${LOG_FILE}"
    validate_log_file_not_in_root_dir "${LOG_FILE}" "${ZOWE_ROOT_DIR}"
  fi
}

get_and_validate_zowe_version() {
  # extract Zowe version from manifest.json
  export ZOWE_VERSION=$(cat $INSTALL_DIR/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')

  if [ -z "$ZOWE_VERSION" ]; then
    echo "Error: failed to determine Zowe version."
    echo "Error: failed to determine Zowe version." >> $LOG_FILE
    exit 1
  fi
}

backup_priror_version() {
  NEW_INSTALL="true"

  # warn about any prior installation
  count_children_in_directory ${ZOWE_ROOT_DIR}
  root_dir_existing_children=$?
  if [[ ${root_dir_existing_children} -gt 0 ]]; then
      if [[ -f "${ZOWE_ROOT_DIR}/manifest.json" ]]
      then
          OLD_VERSION=$(cat ${ZOWE_ROOT_DIR}/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
          NEW_INSTALL="false"
          echo "  $ZOWE_ROOT_DIR contains version ${OLD_VERSION}. Updating this install to version ${ZOWE_VERSION}."
          echo "  Backing up previous Zowe runtime files to ${ZOWE_ROOT_DIR}.${OLD_VERSION}.bak."
          mv ${ZOWE_ROOT_DIR} ${ZOWE_ROOT_DIR}.${OLD_VERSION}.bak
      fi
  fi
}

prepare_target_dir() {
  mkdir -p $ZOWE_ROOT_DIR
  chmod a+rx $ZOWE_ROOT_DIR

  # copy manifest.json to root folder
  cp "$INSTALL_DIR/manifest.json" "$ZOWE_ROOT_DIR"
  chmod 750 "${ZOWE_ROOT_DIR}/manifest.json"

  # Create the /scripts folder in the runtime directory
  # where the scripts to start and the Zowe server will be coped into
  mkdir -p $ZOWE_ROOT_DIR/scripts/templates
  chmod -R a+w $ZOWE_ROOT_DIR/scripts

  mkdir -p $ZOWE_ROOT_DIR/scripts/internal
  chmod a+x $ZOWE_ROOT_DIR/scripts/internal
}

copy_fingerprint() {
  # Create the /fingerprint directory in the ZOWE_ROOT_DIR runtime directory,
  # if it exists in the INSTALL_DIR driectory
  if [[ -d $INSTALL_DIR/fingerprint ]]
  then
    echo "OK: Fingerprint exists in install directory $INSTALL_DIR and will be copied to runtime" >> $LOG_FILE
    ls -l $INSTALL_DIR/fingerprint/*  >> $LOG_FILE
    mkdir -p  $ZOWE_ROOT_DIR/fingerprint
    chmod a+x $ZOWE_ROOT_DIR/fingerprint
    echo "Copying `ls $INSTALL_DIR/fingerprint/*` into "$ZOWE_ROOT_DIR/fingerprint >> $LOG_FILE
    cp $INSTALL_DIR/fingerprint/* $ZOWE_ROOT_DIR/fingerprint
    chmod a+r $ZOWE_ROOT_DIR/fingerprint/*
  else
    echo "OK: No fingerprint"
    echo "OK: No fingerprint in install directory $INSTALL_DIR, create it with zowe-generate-checksum.sh" >> $LOG_FILE
  fi
}

copy_runtime_support_files() {
  echo "Copying the opercmd into "$ZOWE_ROOT_DIR/scripts/internal >> $LOG_FILE
  cp $INSTALL_DIR/scripts/opercmd $ZOWE_ROOT_DIR/scripts/internal/opercmd
  cp $INSTALL_DIR/scripts/ocopyshr.sh $ZOWE_ROOT_DIR/scripts/internal/ocopyshr.sh
  cp $INSTALL_DIR/scripts/ocopyshr.clist $ZOWE_ROOT_DIR/scripts/internal/ocopyshr.clist
  echo "Copying the run-zowe.sh into "$ZOWE_ROOT_DIR/scripts/internal >> $LOG_FILE
  chmod -R 755 $ZOWE_ROOT_DIR/scripts/internal

  mkdir -p ${ZOWE_ROOT_DIR}/bin
  cp -r $INSTALL_DIR/bin/. $ZOWE_ROOT_DIR/bin
  chmod -R 755 $ZOWE_ROOT_DIR/bin

  # Prepare utils directory 
  mkdir -p ${ZOWE_ROOT_DIR}/scripts/utils
  cp $INSTALL_DIR/scripts/instance.template.env ${ZOWE_ROOT_DIR}/scripts/instance.template.env
  cp -r $INSTALL_DIR/scripts/utils/. ${ZOWE_ROOT_DIR}/scripts/utils
  cp $INSTALL_DIR/scripts/tag-files.sh $ZOWE_ROOT_DIR/scripts/utils/tag-files.sh
}

copy_workflow() {
  mkdir -p ${ZOWE_ROOT_DIR}/workflows
  cp -r $INSTALL_DIR/files/workflows/. $ZOWE_ROOT_DIR/workflows/
}

install_mvs() {
  if [ "${RUN_ON_ZOS}" = "true" ]; then
    echo "Creating MVS artefacts SZWEAUTH and SZWESAMP" >> $LOG_FILE
    . $INSTALL_DIR/scripts/zowe-install-MVS.sh
  fi
}

upgrade_components() {
  component_list=$1
  echo "Updating the Zowe components to the latest version"
  for component_name in ${component_list}; do
    cd ${INSTALL_DIR}
    component_package=$PWD/$(ls -t ./files/${component_name}-* | head -1)
    if [ ! -f ${component_package} ]; then
      echo "  Component ${component_name} package (${component_name}-*) is missing"
      echo "  Installation terminated"
      exit 0
    fi
    . $INSTALL_DIR/bin/zowe-upgrade-component.sh \
      --component-package "${component_package}"\
      --log-file "${LOG_FILE}"
  done
}

install_buildin_components() {
  if [ "${RUN_ON_ZOS}" = "true" ]; then
      component_list="launcher jobs-api files-api api-catalog discovery gateway caching-service apiml-common-lib explorer-ui-server explorer-jes explorer-mvs explorer-uss app-server zss"
  else
      component_list="launcher jobs-api files-api api-catalog discovery gateway caching-service apiml-common-lib explorer-ui-server explorer-jes explorer-mvs explorer-uss app-server"
  fi
   # Upgrade the Zowe components by downloading the latest artifacts
  if [ -n "${ZOWE_COMPONENTS_UPGRADE}" ] && [ "${ZOWE_COMPONENTS_UPGRADE}" = "true" ]; then
    upgrade_components "${component_list}"
    echo "Zowe components upgrade completed"
  fi
  for component_name in ${component_list}; do
    cd ${INSTALL_DIR}
    component_package=$PWD/$(ls -t ./files/${component_name}-* | head -1)
    if [ ! -f ${component_package} ]; then
      echo "  Component ${component_name} package (${component_name}-*) is missing"
      echo "  Installation terminated"
      exit 0
    fi

    . $INSTALL_DIR/bin/zowe-install-component.sh \
      --component-name "${component_name}" \
      --component-file "${component_package}" \
      --target_dir "${ZOWE_ROOT_DIR}/components" \
      --core --log-file "${LOG_FILE}"
  done
}

record_zis_info() {
  # Record useful user input specified at install time that would otherwise be lost at configure & runtime
  # Later retrieve this info by looking in a known folder location with info that helps to disambiguate which install it originated from
  # This is not foolproof, but will use the info from the latest install of a given ROOT_DIR
  if [ "${RUN_ON_ZOS}" = "true" ]; then
    mkdir -p /tmp/zowe/$ZOWE_VERSION
    CURRENT_TIME=`date +%Y%j%H%M%S`
    INSTALL_VAR_FILE=/tmp/zowe/${ZOWE_VERSION}/install-${CURRENT_TIME}.env
    echo "ZOWE_DSN_PREFIX=$ZOWE_DSN_PREFIX\nZOWE_ROOT_DIR=$ZOWE_ROOT_DIR\nZOWE_VERSION=$ZOWE_VERSION" >> $INSTALL_VAR_FILE
  fi
}

finish_and_cleanup() {
  # Based on zowe-install-packaging/issues/1014 we should set everything to 755
  chmod -R 755 ${ZOWE_ROOT_DIR}
  # remove the working directory
  rm -rf $TEMP_DIR

  echo
  echo "Zowe ${ZOWE_VERSION} runtime install completed into"
  echo "  directory " $ZOWE_ROOT_DIR
  echo "  datasets  " ${ZOWE_DSN_PREFIX}.SZWESAMP " and " ${ZOWE_DSN_PREFIX}.SZWEAUTH
  echo "The install script zowe-install.sh does not need to be re-run as it completed successfully"

  separator

  echo "---- Final directory listing of ZOWE_ROOT_DIR "$ZOWE_ROOT_DIR >> $LOG_FILE
  ls -l $ZOWE_ROOT_DIR >> $LOG_FILE
}

################################################################################
# Parse command line options
while getopts "f:h:i:l:d" opt; do
  case $opt in
    d) # enable debug mode
      # future use, accept parm to stabilize SMPE packaging
      #debug="-d"
      ;;
    h) DSN_PREFIX=$OPTARG;;
    i) INSTALL_TARGET=$OPTARG;;
    l) LOG_DIRECTORY=$OPTARG;;
    f) LOG_FILE=$OPTARG;; #Internal - used in the smpe-packaging build zip #801
    \?)
      show_usage_error_and_exit "Invalid option: -$opt"
      ;;
  esac
done
shift $(($OPTIND-1))

################################################################################
# Prepare installation environment

export INSTALL_DIR=$(cd $(dirname $0)/../;pwd)

RUN_ON_ZOS=$(test `uname` = "OS/390" && echo "true")

. ${INSTALL_DIR}/bin/internal/zowe-set-env.sh

# Source main utils script
. ${INSTALL_DIR}/bin/utils/utils.sh

separator

################################################################################
# Validat command line options

if [[ -z "$INSTALL_TARGET" ]]; then
  show_usage_error_and_exit "-i parameter not set"
fi
if [ "${RUN_ON_ZOS}" = "true" ]; then
  if [[ -z "$DSN_PREFIX" ]]; then
    show_usage_error_and_exit "-h parameter not set"
  fi
fi

################################################################################
# Install Zowe

ZOWE_ROOT_DIR=$(get_full_path ${INSTALL_TARGET})
ZOWE_DSN_PREFIX=$DSN_PREFIX

prepare_log_file

echo "Install started at: "`date` >> $LOG_FILE
prepare_temp_dir
get_and_validate_zowe_version

echo "Beginning install of Zowe ${ZOWE_VERSION} into directory " $ZOWE_ROOT_DIR

backup_priror_version
prepare_target_dir
copy_runtime_support_files
copy_fingerprint
copy_workflow
install_mvs
install_buildin_components
record_zis_info
finish_and_cleanup

################################################################################
# Conclude
echo "zowe-install.sh completed. In order to use Zowe:"
if [[ ${NEW_INSTALL} == "true" ]]
then
  echo " - 1-time only: Setup the security defintions by submitting '${ZOWE_DSN_PREFIX}.SZWESAMP(ZWESECUR)'"
  echo " - 1-time only: Setup the Zowe certificates by running '${ZOWE_ROOT_DIR}/bin/zowe-setup-certificates.sh -p <certificate_config>'"
  echo " - You must ensure that the Zowe Proclibs are added to your PROCLIB JES concatenation path"
  echo " - You must choose an instance directory and create it by running '${ZOWE_ROOT_DIR}/bin/zowe-configure-instance.sh -c <INSTANCE_DIR>'"
else
  echo " - Check that Zowe Proclibs are up-to-date in your PROCLIB JES concatenation path"
  echo " - Check your instance directory is up to date, by running '${ZOWE_ROOT_DIR}/bin/zowe-configure-instance.sh -c <INSTANCE_DIR>'"
fi
echo "Please review the 'Configuring the Zowe runtime' chapter of the documentation for more information about these steps"
