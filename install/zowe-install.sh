#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2020
################################################################################

if [ $# -lt 4 ]; then
  echo "Usage: $0 -i <zowe_install_path> -h <zowe_dsn_prefix> [-l <log_directory>]"
  exit 1
fi

while getopts "f:h:i:l:d" opt; do
  case $opt in
    d) # enable debug mode
      # future use, accept parm to stabilize SMPE packaging
      #debug="-d"
      ;;
    f) LOG_FILE=$OPTARG;; #Internal - used in the smpe-packaging build zip #801
    h) DSN_PREFIX=$OPTARG;;
    i) INSTALL_TARGET=$OPTARG;;
    l) LOG_DIRECTORY=$OPTARG;;
    \?)
      echo "Invalid option: -$opt" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

export INSTALL_DIR=$(cd $(dirname $0)/../;pwd)

. ${INSTALL_DIR}/bin/internal/zowe-set-env.sh

# extract Zowe version from manifest.json
export ZOWE_VERSION=$(cat $INSTALL_DIR/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')

separator() {
    echo "---------------------------------------------------------------------"
}
separator

# Create a temp directory to be a working directory for sed replacements and logs, if install_dir is read-only then put it in ${TMPDIR}/'/tmp\'
if [[ -w "${INSTALL_DIR}" ]]
then
  export TEMP_DIR=${INSTALL_DIR}/temp_"`date +%Y-%m-%d`"
else
  export TEMP_DIR=${TMPDIR:-/tmp}/zowe_"`date +%Y-%m-%d`"
fi
mkdir -p $TEMP_DIR
chmod a+rwx $TEMP_DIR 

. ${INSTALL_DIR}/bin/utils/setup-log-dir.sh
. ${INSTALL_DIR}/bin/utils/file-utils.sh #source this here as setup-log-dir can't get it from root as it isn't install yet

if [[ -z "$INSTALL_TARGET" ]]
then
  echo "-i parameter not set. Usage: $0 -i zowe_install_path -h zowe_dsn_prefix"
  exit 1
else
  ZOWE_ROOT_DIR=$(get_full_path ${INSTALL_TARGET})
fi

if [[ -z "${LOG_FILE}" ]]
then
  set_install_log_directory "${LOG_DIRECTORY}"
  validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
  set_install_log_file "zowe-install"
else
  set_install_log_file_from_full_path "${LOG_FILE}"
  validate_log_file_not_in_root_dir "${LOG_FILE}" "${ZOWE_ROOT_DIR}"
fi

if [ -z "$ZOWE_VERSION" ]; then
  echo "Error: failed to determine Zowe version."
  echo "Error: failed to determine Zowe version." >> $LOG_FILE
  exit 1
fi

echo "Install started at: "`date` >> $LOG_FILE


if [[ -z "$DSN_PREFIX" ]]
then
  echo "-h parameter not set. Usage: $0 -i zowe_install_path -h zowe_dsn_prefix"
  exit 1
else
  ZOWE_DSN_PREFIX=$DSN_PREFIX
fi

echo "Beginning install of Zowe ${ZOWE_VERSION} into directory " $ZOWE_ROOT_DIR

NEW_INSTALL="true"

# warn about any prior installation
if [[ -d $ZOWE_ROOT_DIR ]]; then
    directoryListLines=`ls -al $ZOWE_ROOT_DIR | wc -l`
    # Has total line, parent and self ref
    if [[ $directoryListLines -gt 3 ]]; then
        if [[ -f "${ZOWE_ROOT_DIR}/manifest.json" ]]
        then
            OLD_VERSION=$(cat ${ZOWE_ROOT_DIR}/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
            NEW_INSTALL="false"
            echo "  $ZOWE_ROOT_DIR contains version ${OLD_VERSION}. Updating this install to version ${ZOWE_VERSION}."
            echo "  Backing up previous Zowe runtime files to ${ZOWE_ROOT_DIR}.${OLD_VERSION}.bak."
            mv ${ZOWE_ROOT_DIR} ${ZOWE_ROOT_DIR}.${OLD_VERSION}.bak
        fi
    fi
fi
mkdir -p $ZOWE_ROOT_DIR
chmod a+rx $ZOWE_ROOT_DIR

# copy manifest.json to root folder
cp "$INSTALL_DIR/manifest.json" "$ZOWE_ROOT_DIR"
chmod 750 "${ZOWE_ROOT_DIR}/manifest.json"

# Install the API Mediation Layer
. $INSTALL_DIR/scripts/zowe-install-api-mediation.sh

# Install the zLUX server
. $INSTALL_DIR/scripts/zowe-install-zlux.sh

# Install the Explorer API
. $INSTALL_DIR/scripts/zowe-install-explorer-api.sh

# Install Explorer UI plugins
. $INSTALL_DIR/scripts/zowe-install-explorer-ui.sh

echo "---- After expanding zLUX artifacts this is a directory listing of "$ZOWE_ROOT_DIR >> $LOG_FILE
ls $ZOWE_ROOT_DIR >> $LOG_FILE

# Create the /scripts folder in the runtime directory
# where the scripts to start and the Zowe server will be coped into
mkdir -p $ZOWE_ROOT_DIR/scripts/templates
chmod -R a+w $ZOWE_ROOT_DIR/scripts

mkdir -p $ZOWE_ROOT_DIR/scripts/internal
chmod a+x $ZOWE_ROOT_DIR/scripts/internal

echo "Copying the opercmd into "$ZOWE_ROOT_DIR/scripts/internal >> $LOG_FILE
cp $INSTALL_DIR/scripts/opercmd $ZOWE_ROOT_DIR/scripts/internal/opercmd
cp $INSTALL_DIR/scripts/ocopyshr.sh $ZOWE_ROOT_DIR/scripts/internal/ocopyshr.sh
cp $INSTALL_DIR/scripts/ocopyshr.clist $ZOWE_ROOT_DIR/scripts/internal/ocopyshr.clist
echo "Copying the run-zowe.sh into "$ZOWE_ROOT_DIR/scripts/internal >> $LOG_FILE

mkdir -p ${ZOWE_ROOT_DIR}/bin
cp -r $INSTALL_DIR/bin/. $ZOWE_ROOT_DIR/bin
chmod -R 755 $ZOWE_ROOT_DIR/bin

chmod -R 755 $ZOWE_ROOT_DIR/scripts/internal

echo "Creating MVS artefacts SZWEAUTH and SZWESAMP" >> $LOG_FILE
. $INSTALL_DIR/scripts/zowe-install-MVS.sh

echo "Zowe ${ZOWE_VERSION} runtime install completed into"
echo "  directory " $ZOWE_ROOT_DIR
echo "  datasets  " ${ZOWE_DSN_PREFIX}.SZWESAMP " and " ${ZOWE_DSN_PREFIX}.SZWEAUTH
echo "The install script zowe-install.sh does not need to be re-run as it completed successfully"
separator

# Prepare utils directory 
mkdir -p ${ZOWE_ROOT_DIR}/scripts/utils
cp $INSTALL_DIR/scripts/instance.template.env ${ZOWE_ROOT_DIR}/scripts/instance.template.env
cp -r $INSTALL_DIR/scripts/utils/. ${ZOWE_ROOT_DIR}/scripts/utils

# Based on zowe-install-packaging/issues/1014 we should set everything to 755
chmod -R 755 ${ZOWE_ROOT_DIR}

# remove the working directory
rm -rf $TEMP_DIR

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
