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

ZOWE_GROUP=${ZOWE_GROUP} # Replace when zowe has it's own group: https://github.com/zowe/zowe-install-packaging/issues/518

while getopts "f:h:i:dI" opt; do
  case $opt in
    d) # enable debug mode
      # future use, accept parm to stabilize SMPE packaging
      #debug="-d"
      ;;
    f) # override default value for LOG_FILE
      # future use, issue 801, accept parm to stabilize SMPE packaging
      #...="$OPTARG"
      ;;
    h) DSN_PREFIX=$OPTARG;;
    i) INSTALL_TARGET=$OPTARG;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

# Ensure that newly created files are in EBCDIC codepage
export _CEE_RUNOPTS=""
export _TAG_REDIR_IN=""
export _TAG_REDIR_OUT=""
export _TAG_REDIR_ERR=""
export _BPXK_AUTOCVT="OFF"

export INSTALL_DIR=$(cd $(dirname $0)/../;pwd)

# extract Zowe version from manifest.json
export ZOWE_VERSION=$(cat $INSTALL_DIR/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')

separator() {
    echo "---------------------------------------------------------------------"
}
separator

# Create a log file with the year and time.log in a log folder 
# that scripts can echo to and can be written to by scripts to diagnose any install 
# problems.  

export LOG_DIR=$INSTALL_DIR/log
# Make the log directory if needed - first time through - subsequent installs create new .log files
if [[ ! -d $LOG_DIR ]]; then
    mkdir -p $LOG_DIR
    chmod a+rwx $LOG_DIR 
fi
# Make the log file (unique assuming there is only one install per second)
export LOG_FILE="`date +%Y-%m-%d-%H-%M-%S`.log"
LOG_FILE=$LOG_DIR/$LOG_FILE
touch $LOG_FILE
chmod a+rw $LOG_FILE

if [ -z "$ZOWE_VERSION" ]; then
  echo "Error: failed to determine Zowe version."
  echo "Error: failed to determine Zowe version." >> $LOG_FILE
  exit 1
fi

echo "Install started at: "`date` >> $LOG_FILE

cd $INSTALL_DIR/install
# zowe-parse-yaml.sh to get the variables for install directory, APIM certificate resources, installation proc, and server ports
. $INSTALL_DIR/scripts/zowe-parse-yaml.sh

if [[ ! -z "$INSTALL_TARGET" ]]
then
  ZOWE_ROOT_DIR=$INSTALL_TARGET
fi

if [[ ! -z "$DSN_PREFIX" ]]
then
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

# Create a temp directory to be a working directory for sed replacements
export TEMP_DIR=$INSTALL_DIR/temp_"`date +%Y-%m-%d`"
mkdir -p $TEMP_DIR

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

cd $INSTALL_DIR/scripts
cp $INSTALL_DIR/scripts/zowe-verify.sh $ZOWE_ROOT_DIR/scripts/zowe-verify.sh

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

#TODO LATER - do we need a better location rather than scripts - covered by zip #519
cp $INSTALL_DIR/files/jcl/ZWESVSTC.jcl ${ZOWE_ROOT_DIR}/scripts/templates/ZWESVSTC.jcl

echo "Creating MVS artefacts SZWEAUTH and SZWESAMP" >> $LOG_FILE
. $INSTALL_DIR/scripts/zowe-install-MVS.sh

echo "Zowe ${ZOWE_VERSION} runtime install completed into"
echo "  directory " $ZOWE_ROOT_DIR
echo "  datasets  " ${ZOWE_DSN_PREFIX}.SZWESAMP " and " ${ZOWE_DSN_PREFIX}.SZWEAUTH
echo "The install script zowe-install.sh does not need to be re-run as it completed successfully"
separator

# Prepare configure directory 
mkdir -p ${ZOWE_ROOT_DIR}/scripts/configure
cp $INSTALL_DIR/scripts/zowe-parse-yaml.sh ${ZOWE_ROOT_DIR}/scripts/configure
# Copy all but root dir from yaml as we can derive that once there
grep -v "rootDir=" $INSTALL_DIR/install/zowe-install.yaml > ${ZOWE_ROOT_DIR}/scripts/configure/zowe-install.yaml

cp -r $INSTALL_DIR/scripts/configure/. ${ZOWE_ROOT_DIR}/scripts/configure
chmod -R 755 $ZOWE_ROOT_DIR/scripts/configure

# Prepare utils directory 
mkdir -p ${ZOWE_ROOT_DIR}/scripts/utils
cp $INSTALL_DIR/scripts/instance.template.env ${ZOWE_ROOT_DIR}/scripts/instance.template.env
cp -r $INSTALL_DIR/scripts/utils/. ${ZOWE_ROOT_DIR}/scripts/utils
chmod -R 755 $ZOWE_ROOT_DIR/scripts/utils

. $INSTALL_DIR/scripts/zowe-copy-xmem.sh # TODO - remove and file once zowe-apf-server removed.

#Give all directories -rw+x permission so they can be listed, but files -rwx
chmod -R o-rwx ${ZOWE_ROOT_DIR}
echo "  About to run find and chmods to add o+x on directories" >> $LOG_FILE
find ${ZOWE_ROOT_DIR} -type d -exec chmod o+x {} \; 2>/dev/null
echo "  Completed find and chmods to add o+x on directories" >> $LOG_FILE

# If this step fails it is likely because the user running this script is not part of the IZUADMIN group
chgrp -R ${ZOWE_GROUP} ${ZOWE_ROOT_DIR}
RETURN_CODE=$?
if [[ $RETURN_CODE != "0" ]]; then
  echo "  The current user does not have sufficient authority to change the group of ${ZOWE_ROOT_DIR}."
  echo "  A user who is part of group ${ZOWE_GROUP} must run 'chgrp -R ${ZOWE_GROUP} ${ZOWE_ROOT_DIR}'."
  echo "  'chgrp -R ${ZOWE_GROUP} ${ZOWE_ROOT_DIR}' failed to run successfully" >> $LOG_FILE
fi

chmod -R 550 ${ZOWE_ROOT_DIR}/components/app-server/share/zlux-app-server/defaults

# save install log in runtime directory
mkdir -p $ZOWE_ROOT_DIR/install_log
cp $LOG_FILE $ZOWE_ROOT_DIR/install_log

# remove the working directory
rm -rf $TEMP_DIR

echo "zowe-install.sh completed. In order to use Zowe:"
if [[ ${NEW_INSTALL} == "true" ]]
then
  echo " - You must choose an instance directory and create it by running '${ZOWE_ROOT_DIR}/bin/zowe-configure-instance.sh -c <INSTANCE_DIR>'"
  echo " - You must ensure that the Zowe Proclibs are added to your JES2 concatenation"
  echo " - 1-time only: Setup the security defintions by submitting '${ZOWE_DSN_PREFIX}/SZWESAMP/ZWESECUR'"
  echo " - 1-time only: Setup the Zowe certificates by running '${ZOWE_ROOT_DIR}/bin/zowe-setup-certificates.sh -p <certificate_config>'"
else
  echo "zowe-install.sh completed. Before you run Zowe:"
  echo " - In order to check your instance is up to date, please run '${ZOWE_ROOT_DIR}/bin/zowe-configure-instance.sh -c <INSTANCE_DIR>'"
  echo " - Check that Zowe Proclibs are up-to-date in your JES2 concatenation"
fi
echo "Please review the documentation for more information about these steps"
