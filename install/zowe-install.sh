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
    I)
      INSTALL_ONLY=1
      ;;
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

# warn about any prior installation
if [[ -d $ZOWE_ROOT_DIR ]]; then
    directoryListLines=`ls -al $ZOWE_ROOT_DIR | wc -l`
    # Has total line, parent and self ref
    if [[ $directoryListLines -gt 3 ]]; then
        echo "    $ZOWE_ROOT_DIR is not empty"
        echo "    Please clear the contents of this directory, or edit zowe-install.yaml's root directory location before attempting the install."
        echo "Exiting non emptry install directory $ZOWE_ROOT_DIR has `expr $directoryListLines - 3` directory entries" >> $LOG_FILE
        exit 2
    fi
else
    mkdir -p $ZOWE_ROOT_DIR
fi
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
cp $INSTALL_DIR/scripts/zowe-support.template.sh ${ZOWE_ROOT_DIR}/scripts/templates/zowe-support.template.sh

cp $INSTALL_DIR/scripts/zowe-verify.sh $ZOWE_ROOT_DIR/scripts/zowe-verify.sh

mkdir $ZOWE_ROOT_DIR/scripts/internal
chmod a+x $ZOWE_ROOT_DIR/scripts/internal

echo "Copying the opercmd into "$ZOWE_ROOT_DIR/scripts/internal >> $LOG_FILE
cp $INSTALL_DIR/scripts/opercmd $ZOWE_ROOT_DIR/scripts/internal/opercmd
cp $INSTALL_DIR/scripts/ocopyshr.sh $ZOWE_ROOT_DIR/scripts/internal/ocopyshr.sh
cp $INSTALL_DIR/scripts/ocopyshr.clist $ZOWE_ROOT_DIR/scripts/internal/ocopyshr.clist
echo "Copying the run-zowe.sh into "$ZOWE_ROOT_DIR/scripts/internal >> $LOG_FILE

mkdir ${ZOWE_ROOT_DIR}/bin
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
mkdir ${ZOWE_ROOT_DIR}/scripts/configure
cp $INSTALL_DIR/scripts/zowe-parse-yaml.sh ${ZOWE_ROOT_DIR}/scripts/configure
# Copy all but root dir from yaml as we can derive that once there
grep -v "rootDir=" $INSTALL_DIR/install/zowe-install.yaml > ${ZOWE_ROOT_DIR}/scripts/configure/zowe-install.yaml

cp -r $INSTALL_DIR/scripts/configure/. ${ZOWE_ROOT_DIR}/scripts/configure
chmod -R 755 $ZOWE_ROOT_DIR/scripts/configure

# Prepare utils directory 
mkdir ${ZOWE_ROOT_DIR}/scripts/utils
cp $INSTALL_DIR/scripts/instance.template.env ${ZOWE_ROOT_DIR}/scripts/instance.template.env
cp -r $INSTALL_DIR/scripts/utils/. ${ZOWE_ROOT_DIR}/scripts/utils
chmod -R 755 $ZOWE_ROOT_DIR/scripts/utils

echo "Copying zowe-runtime-authorize.template.sh to "$ZOWE_ROOT_DIR/scripts/templates/zowe-runtime-authorize.template.sh >> $LOG_FILE
cp "$INSTALL_DIR/scripts/zowe-runtime-authorize.template.sh" "$ZOWE_ROOT_DIR/scripts/templates/zowe-runtime-authorize.template.sh"

. $INSTALL_DIR/scripts/zowe-copy-xmem.sh

# save install log in runtime directory
mkdir  $ZOWE_ROOT_DIR/install_log
cp $LOG_FILE $ZOWE_ROOT_DIR/install_log

# remove the working directory
rm -rf $TEMP_DIR

if [ -z $INSTALL_ONLY ]
then
  # Run configure - note not in source mode
  ${ZOWE_ROOT_DIR}/scripts/configure/zowe-configure.sh
else
    echo "zowe-install.sh -I was specified, so just installation ran. In order to use Zowe, you must configure it by running ${ZOWE_ROOT_DIR}/scripts/configure/zowe-configure.sh"
fi

