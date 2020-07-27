#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2018, 2020
#######################################################################

# NOTE FOR DEVELOPMENT
# Use functions _cp/_cpr/_pax to copy/recursive copy/unpax from
# ${INSTALL_DIR}, as these will mark the source as processed. The build
# pipeline will verify that all ${INSTALL_DIR} files are processed.
# Use function _cmd to add standard error handling to command execution.
# Use function _setInstallError in custom error handling.

# ---------------------------------------------------------------------
function separator {
echo "----------------------------------------------------------------"
}    # separator

script=zowe-install.sh
unset INSTALL_ERROR

echo
if [ `uname` = "OS/390" ]; then
  if [ $# -lt 4 ]; then
    echo "Usage: $0 -i <zowe_install_path> -h <zowe_dsn_prefix> [-l <log_directory>]"
    exit 1
  fi
else
  if [ $# -lt 2 ]; then
    echo  "Usage: $0 -i <zowe_install_path> [-l <log_directory>]"
    exit 1
  fi
fi

while getopts "f:h:i:l:dt" opt; do
  case $opt in
    d) # enable debug mode
      # future use, accept parm to stabilize SMPE packaging
      #debug="-d"
      ;;
    f) LOG_FILE=$OPTARG;; #Internal - used in the smpe-packaging build zip #801
    h) DSN_PREFIX=$OPTARG;;
    i) INSTALL_TARGET=$OPTARG;;
    l) LOG_DIRECTORY=$OPTARG;;
    t) touchIt=true;; #Internal - ensure all files are processed
    \?)
      echo "Invalid option: -$opt" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

if [ `uname` = "OS/390" ]; then
  if [ -z "$DSN_PREFIX" ]; then
    echo "-h parameter not set. Usage: $0 -i zowe_install_path -h zowe_dsn_prefix"
    exit 1
  else
    ZOWE_DSN_PREFIX=$DSN_PREFIX
  fi
fi

# INSTALL_DIR=<something>/zowe-V-R-M
# assumes script is <something>/zowe-V-R-M/install
export INSTALL_DIR=$(cd $(dirname $0);cd ..;pwd)

# Ensure we have tagging behaviour set correctly
. ${INSTALL_DIR}/bin/internal/zowe-set-env.sh
# Load utility functions
. ${INSTALL_DIR}/scripts/zowe-install-utils.sh
. ${INSTALL_DIR}/bin/utils/setup-log-dir.sh
# Source this here as setup-log-dir can't get it from Zowe root as it isn't installed yet
. ${INSTALL_DIR}/bin/utils/file-utils.sh

if [ -z "$INSTALL_TARGET" ]; then
  echo "-i parameter not set. Usage: $0 -i zowe_install_path -h zowe_dsn_prefix"
  exit 1
else
  ZOWE_ROOT_DIR=$(get_full_path ${INSTALL_TARGET})
fi

# Extract Zowe version from manifest.json
export ZOWE_VERSION=$(cat ${INSTALL_DIR}/manifest.json | grep version \
  | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')

if [ -z "$ZOWE_VERSION" ]; then
  echo "Error: $script failed to determine Zowe version."
  exit 1
fi

# Create a temp directory to be a working directory for sed replacements
# and logs, if install_dir is read-only then put it in ${TMPDIR}/'/tmp\'
if [ -w "${INSTALL_DIR}" ]; then
  export TEMP_DIR=${INSTALL_DIR}/temp_"`date +%Y-%m-%d`"
else
  export TEMP_DIR=${TMPDIR:-/tmp}/zowe_"`date +%Y-%m-%d`"
fi
mkdir -p ${TEMP_DIR}
#chmod a+rwx ${TEMP_DIR}
if [ $? -ne 0 ]; then
  echo "Error: $script failed to stage \${TEMP_DIR} ${TEMP_DIR}"
  exit 1
fi    #

separator

# Initialize log file
if [ -z "${LOG_FILE}" ]; then
  set_install_log_directory "${LOG_DIRECTORY}"
  validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
  set_install_log_file "zowe-install"
else
  set_install_log_file_from_full_path "${LOG_FILE}"
  validate_log_file_not_in_root_dir "${LOG_FILE}" "${ZOWE_ROOT_DIR}"
fi

# Now that the log file exists we can use the _* install functions

# Initialize verify everything was processed
if [ -n "${touchIt}" ]; then
  export TIME_REFERENCE=${TEMP_DIR}/time_reference.$$
  _cmd touch ${TIME_REFERENCE}                # set reference timestamp
  sleep 1 # manifest.json shows up as not processed, likely because we're too fast
fi

echo "  Install started at: "`date` >> ${LOG_FILE}

echo "Beginning install of Zowe ${ZOWE_VERSION} into directory" ${ZOWE_ROOT_DIR}

NEW_INSTALL="true"

# Warn about any prior installation
count_children_in_directory ${ZOWE_ROOT_DIR}
root_dir_existing_children=$?
if [ ${root_dir_existing_children} -gt 0 ]; then
  if [ -f "${ZOWE_ROOT_DIR}/manifest.json" ]; then
    OLD_VERSION=$(cat ${ZOWE_ROOT_DIR}/manifest.json | grep version \
      | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
    NEW_INSTALL="false"
    echo "  ${ZOWE_ROOT_DIR} contains version ${OLD_VERSION}. Updating this install to version ${ZOWE_VERSION}."
    echo "  Backing up previous Zowe runtime files to ${ZOWE_ROOT_DIR}.${OLD_VERSION}.bak." | tee -a ${LOG_FILE}
    mv ${ZOWE_ROOT_DIR} ${ZOWE_ROOT_DIR}.${OLD_VERSION}.bak
    if [ $? -ne 0 ]; then
      echo "Error: $script failed to back up to ${ZOWE_ROOT_DIR}.${OLD_VERSION}.bak" | tee -a ${LOG_FILE}
      exit 1
    fi
  fi
fi

mkdir -p ${ZOWE_ROOT_DIR}
#chmod a+rx ${ZOWE_ROOT_DIR}
if [ $? -ne 0 ]; then
  echo "Error: $script failed to create \${ZOWE_ROOT_DIR} ${ZOWE_ROOT_DIR}" | tee -a ${LOG_FILE}
  exit 1
fi    #

# Install starting - - - - - - - - - - - - - - - - - - - - - - - - - -

# Copy manifest.json to root folder
_cp ${INSTALL_DIR}/manifest.json ${ZOWE_ROOT_DIR}
#chmod 750 "${ZOWE_ROOT_DIR}/manifest.json"  #obsolete umask @ startup and chmod 755 later on

# Install the API Mediation Layer
. ${INSTALL_DIR}/scripts/zowe-install-api-mediation.sh

# Install the zLUX server
. ${INSTALL_DIR}/scripts/zowe-install-zlux.sh

# Install the Explorer API
. ${INSTALL_DIR}/scripts/zowe-install-explorer-api.sh

# Install the Explorer UI plugins
. ${INSTALL_DIR}/scripts/zowe-install-explorer-ui.sh

# Kinda pointless now, all we have is manifest file and components directory
echo "---- After expanding components this is a directory listing of ${ZOWE_ROOT_DIR}" >> ${LOG_FILE}
ls ${ZOWE_ROOT_DIR} 1>>${LOG_FILE} 2>&1  # stdout/stderr only in ${LOG_FILE}
echo "" >> ${LOG_FILE}

echo "  Copying the licenses into ${ZOWE_ROOT_DIR}/licenses" >> ${LOG_FILE}
_cmd mkdir -p ${ZOWE_ROOT_DIR}/licenses
_cpr ${INSTALL_DIR}/licenses/.  ${ZOWE_ROOT_DIR}/licenses/

echo "  Copying the customization workflows into ${ZOWE_ROOT_DIR}/workflows" >> ${LOG_FILE}
_cmd mkdir -p ${ZOWE_ROOT_DIR}/workflows
_cpr ${INSTALL_DIR}/files/workflows/.  ${ZOWE_ROOT_DIR}/workflows/

echo "  Copying the utilty scripts into ${ZOWE_ROOT_DIR}/scripts" >> ${LOG_FILE}
#_cmd mkdir -p ${ZOWE_ROOT_DIR}/scripts/templates # is empty
_cmd mkdir -p ${ZOWE_ROOT_DIR}/scripts/internal \
              ${ZOWE_ROOT_DIR}/scripts/utils
_cp ${INSTALL_DIR}/scripts/instance.template.env  ${ZOWE_ROOT_DIR}/scripts/

_cp ${INSTALL_DIR}/scripts/opercmd         ${ZOWE_ROOT_DIR}/scripts/internal/
_cp ${INSTALL_DIR}/scripts/ocopyshr.sh     ${ZOWE_ROOT_DIR}/scripts/internal/
_cp ${INSTALL_DIR}/scripts/ocopyshr.clist  ${ZOWE_ROOT_DIR}/scripts/internal/

_cpr ${INSTALL_DIR}/scripts/utils/.  ${ZOWE_ROOT_DIR}/scripts/utils/
#chmod -R a+w ${ZOWE_ROOT_DIR}/scripts #obsolete umask @ startup and chmod 755 later on
#chmod a+x ${ZOWE_ROOT_DIR}/scripts/internal #obsolete umask @ startup and chmod 755 later on

echo "  Copying the runtime scripts into ${ZOWE_ROOT_DIR}/bin" >> ${LOG_FILE}
_cmd mkdir -p ${ZOWE_ROOT_DIR}/bin
_cpr ${INSTALL_DIR}/bin/.  ${ZOWE_ROOT_DIR}/bin/
#chmod -R 755 ${ZOWE_ROOT_DIR}/bin #obsolete umask @ startup and chmod 755 later on
#chmod -R 755 ${ZOWE_ROOT_DIR}/scripts/internal #obsolete umask @ startup and chmod 755 later on

# Create the /fingerprint directory in the ZOWE_ROOT_DIR runtime directory,
# if it exists in the INSTALL_DIR driectory
if [ -d ${INSTALL_DIR}/fingerprint ]; then
  echo "  Copying fingerprint into ${ZOWE_ROOT_DIR}/fingerprint" >> ${LOG_FILE}
  _cmd mkdir -p  ${ZOWE_ROOT_DIR}/fingerprint
  _cp ${INSTALL_DIR}/fingerprint/* ${ZOWE_ROOT_DIR}/fingerprint/
  #chmod a+x ${ZOWE_ROOT_DIR}/fingerprint
  #chmod a+r ${ZOWE_ROOT_DIR}/fingerprint/*
else
  # should only occur during install in build pipeline
  echo "  No fingerprint in install directory ${INSTALL_DIR}, create it with zowe-generate-checksum.sh" >> ${LOG_FILE}
fi

# install MVS artifacts
if [ `uname` = "OS/390" ]; then
  . ${INSTALL_DIR}/scripts/zowe-install-MVS.sh
fi

# Based on zowe-install-packaging/issues/1014 we should set everything to 755
echo "  Setting correct permission bits" >> ${LOG_FILE}
_cmd chmod -R 755 ${ZOWE_ROOT_DIR}

# Install finished - - - - - - - - - - - - - - - - - - - - - - - - - -

# Verify that everything was processed (must be before "rm ${TEMP_DIR}")
if [ -n "${touchIt}" ]; then
  echo "  Verifying that everything was processed" >> ${LOG_FILE}
  # mark files that are intentionally not processed
  _cmd touch ${INSTALL_DIR}/install/*
  _cmd touch ${INSTALL_DIR}/scripts/zowe-install-*.sh
# TODO verify why these are in zowe.pax but not installed
  _cmd touch ${INSTALL_DIR}/files/HashFiles.java
  _cmd touch ${INSTALL_DIR}/scripts/tag-files.sh
  _cmd touch ${INSTALL_DIR}/scripts/allocate-dataset.sh     # came from shared/scripts
  _cmd touch ${INSTALL_DIR}/scripts/check-dataset-dcb.sh    # came from shared/scripts
  _cmd touch ${INSTALL_DIR}/scripts/check-dataset-exist.sh  # came from shared/scripts
  _cmd touch ${INSTALL_DIR}/scripts/opercmd.rex             # came from shared/scripts
  _cmd touch ${INSTALL_DIR}/scripts/wait-for-job.sh         # came from shared/scripts

  # verify that everything was processed
  # (only files older than reference, excluding ${TEMP_DIR})
  notProcessed="$(find ${INSTALL_DIR} \
                  -type f \                     
                  ! -newer ${TIME_REFERENCE} \  
                | grep -v ^${TEMP_DIR}/)"       
  if [ -n "${notProcessed}" ]; then
    echo "Error: $script not all files are installed" | tee -a ${LOG_FILE}
    echo ${notProcessed} | tr ' ' '\n' | tee -a ${LOG_FILE}
    _setInstallError
  fi
fi

# Inform caller of completion
echo "Zowe ${ZOWE_VERSION} runtime install completed into"
echo "  directory ${ZOWE_ROOT_DIR}/*"
if [ `uname` = "OS/390" ]; then
  echo "  datasets  ${ZOWE_DSN_PREFIX}.SZWE*"
fi

if [ -n "$INSTALL_ERROR" ]; then
  echo "" | tee -a ${LOG_FILE}
  echo "Error: $script Install completed with failures and must be re-run" | tee -a ${LOG_FILE}
  echo "See ${LOG_FILE} for more details"
  echo "" | tee -a ${LOG_FILE}
else
  echo "Install script $script does not need to be re-run as it completed successfully" | tee -a ${LOG_FILE}
  separator
  echo "Zowe install completed. In order to use Zowe:"
  if [ ${NEW_INSTALL} = "true" ]; then
    echo " - one time only: Setup the security defintions by submitting '${ZOWE_DSN_PREFIX}.SZWESAMP(ZWESECUR)'"
    echo " - one time only: Setup the Zowe certificates by running '${ZOWE_ROOT_DIR}/bin/zowe-setup-certificates.sh -p <certificate_config>'"
    echo " - You must choose an instance directory and create it by running '${ZOWE_ROOT_DIR}/bin/zowe-configure-instance.sh -c <INSTANCE_DIR>'"
    echo " - You must ensure that the Zowe PROCLIB members are added to your JES PROCLIB concatenation"
  else
    echo " - Check your instance directory is up to date, by running '${ZOWE_ROOT_DIR}/bin/zowe-configure-instance.sh -c <INSTANCE_DIR>'"
    echo " - Check that Zowe PROCLIB members are up-to-date in your JES PROCLIB concatenation"
  fi
  echo "Please review the 'Configuring the Zowe runtime' chapter of the documentation for more information about these steps"
fi

# Remove the working directory
rm -rf ${TEMP_DIR}  1>>${LOG_FILE} 2>&1  # stdout/stderr only in ${LOG_FILE}

echo "---- Final directory listing of ZOWE_ROOT_DIR ${ZOWE_ROOT_DIR}" >> ${LOG_FILE}
ls -l ${ZOWE_ROOT_DIR} 1>>${LOG_FILE} 2>&1  # stdout/stderr only in ${LOG_FILE}
echo "" >> ${LOG_FILE}

# Set exit RC 1 on install error
test -z "$INSTALL_ERROR"           # MUST be the last command in script
