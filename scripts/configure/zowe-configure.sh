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

# Ensure that newly created files are in EBCDIC codepage
export _CEE_RUNOPTS=""
export _TAG_REDIR_IN=""
export _TAG_REDIR_OUT=""
export _TAG_REDIR_ERR=""
export _BPXK_AUTOCVT="OFF"

# TODO LATER - once componentisation and removal of the yaml file is done, this whole file to go and be replaced by . ${ZOWE_ROOT_DIR}/bin/zowe-configure-instance.sh -c $ZOWE_INSTANCE_DIR

# Cache original directory, then change our directory to be here so we can rely on the script offset
PREV_DIR=`pwd`	
cd $(dirname $0)
CONFIG_DIR=`pwd`
cd ../../  #we are in <ZOWE_ROOT_DIR>/scripts/configure
export ZOWE_ROOT_DIR=`pwd`
cd ${CONFIG_DIR}

# TODO - refactor, or work out how to improve?
export LOG_DIR=${CONFIG_DIR}/log
# Make the log directory if needed - first time through - subsequent installs create new .log files
if [[ ! -d $LOG_DIR ]]; then
    mkdir -p $LOG_DIR
    chmod a+rwx $LOG_DIR 
fi

export LOG_FILE="config_`date +%Y-%m-%d-%H-%M-%S`.log"
LOG_FILE=$LOG_DIR/$LOG_FILE
touch $LOG_FILE
chmod a+rw $LOG_FILE

# Create a temp directory to be a working directory for sed replacements
export TEMP_DIR=$CONFIG_DIR/temp_"`date +%Y-%m-%d`"
mkdir -p $TEMP_DIR

. ${ZOWE_ROOT_DIR}/bin/zowe-init.sh

# zowe-parse-yaml.sh to get the variables for install directory, APIM certificate resources, installation proc, and server ports
. $CONFIG_DIR/zowe-parse-yaml.sh

echo "Beginning to configure zowe installed in ${ZOWE_ROOT_DIR}"

# Configure the ports for the zLUX server
. $CONFIG_DIR/zowe-configure-zlux-ports.sh

# configure api catalog and jes explorer plugins, to be moved later to their own configure steps after zlux componentisation
. $CONFIG_DIR/zowe-configure-iframe-plugins.sh

# Configure API Mediation layer.  Because this script may fail because of priviledge issues with the user ID
# this script is run after all the folders have been created and paxes expanded above
echo "Attempting to setup Zowe API Mediation Layer certificates ... "
. $CONFIG_DIR/zowe-configure-api-mediation.sh

# Configure the TLS certificates for the zLUX server
. $CONFIG_DIR/zowe-configure-zlux-certificates.sh

INSTANCE_DIR=${ZOWE_USER_DIR}
. ${ZOWE_ROOT_DIR}/bin/zowe-configure-instance.sh -c ${INSTANCE_DIR} -y

# Run deploy on the zLUX app server to propagate the changes made
zluxserverdirectory='zlux-app-server'
echo "Preparing folder permission for zLux plugins foder..." >> $LOG_FILE
chmod -R u+w $ZOWE_ROOT_DIR/$zluxserverdirectory/plugins/
chmod -R u+w $ZOWE_ROOT_DIR/$zluxserverdirectory/deploy/site
# TODO LATER - revisit to work out the best permissions, but currently needed so deploy.sh can run	
chmod -R 775 $ZOWE_ROOT_DIR/zlux-app-server/deploy/product	
chmod -R 775 $ZOWE_ROOT_DIR/zlux-app-server/deploy/instance

cd $ZOWE_ROOT_DIR/zlux-build
chmod a+x deploy.sh
./deploy.sh > /dev/null

# TODO LATER - this need updating to not modify read-only dir, but instead use instance variables - move zowe-support.sh to INSTANCE_DIR?
sed -e "s#{{java_home}}#${ZOWE_JAVA_HOME}#" \
  -e "s#{{node_home}}#${NODE_HOME}#" \
  -e "s#{{zowe_prefix}}#${ZOWE_PREFIX}#" \
  -e "s#{{zowe_instance}}#${ZOWE_INSTANCE}#" \
  -e "s#{{stc_name}}#${ZOWE_SERVER_PROCLIB_MEMBER}#" \
  -e "s#{{root_dir}}#${ZOWE_ROOT_DIR}#" \
  "${ZOWE_ROOT_DIR}/scripts/templates/zowe-support.template.sh" \
  > "${ZOWE_ROOT_DIR}/scripts/zowe-support.sh"
chmod a+x "${ZOWE_ROOT_DIR}/scripts/zowe-support.sh"

echo "Attempting to setup Zowe Proclib ... "
# Note: this calls exit code, so can't be run in 'source' mode
$CONFIG_DIR/zowe-copy-proc.sh ${ZOWE_ROOT_DIR}/scripts/templates/ZOWESVR.jcl $ZOWE_SERVER_PROCLIB_MEMBER $ZOWE_SERVER_PROCLIB_DSNAME

# Inject stc name into config-stc
sed -e "s#{{stc_name}}#${ZOWE_SERVER_PROCLIB_MEMBER}#" \
   "${ZOWE_ROOT_DIR}/scripts/configure/zowe-config-stc.sh" \
  > "${ZOWE_ROOT_DIR}/scripts/configure/zowe-config-stc.sh.new"
mv "${ZOWE_ROOT_DIR}/scripts/configure/zowe-config-stc.sh.new" "${ZOWE_ROOT_DIR}/scripts/configure/zowe-config-stc.sh"
chmod 770 "${ZOWE_ROOT_DIR}/scripts/configure/zowe-config-stc.sh"

# TODO LATER - same as the above - zss won't start with those permissions,
sed -e "s#{{root_dir}}#${ZOWE_ROOT_DIR}#" \
  -e "s#{{zosmf_admin_group}}#${ZOWE_ZOSMF_ADMIN_GROUP}#" \
  -e "s#{{configure_log_file}}#${LOG_FILE}#" \
  "$ZOWE_ROOT_DIR/scripts/templates/zowe-runtime-authorize.template.sh" \
  > "$ZOWE_ROOT_DIR/scripts/zowe-runtime-authorize.sh"

chmod a+x $ZOWE_ROOT_DIR/scripts/zowe-runtime-authorize.sh
$(. $ZOWE_ROOT_DIR/scripts/zowe-runtime-authorize.sh)
AUTH_RETURN_CODE=$?
if [[ $AUTH_RETURN_CODE == "0" ]]; then
    echo "  The permissions were successfully changed"
    echo "  zowe-runtime-authorize.sh run successfully" >> $LOG_FILE
    else
    echo "  The current user does not have sufficient authority to modify all the file and directory permissions."
    echo "  A user with sufficient authority must run $ZOWE_ROOT_DIR/scripts/zowe-runtime-authorize.sh"
    echo "  zowe-runtime-authorize.sh failed to run successfully" >> $LOG_FILE
fi

cd $PREV_DIR

echo "To start Zowe run the script "${INSTANCE_DIR}/bin/zowe-start.sh
echo "   (or in SDSF directly issue the command /S $ZOWE_SERVER_PROCLIB_MEMBER,INSTANCE='${INSTANCE_DIR}')"
echo "To stop Zowe run the script "${INSTANCE_DIR}/bin/zowe-stop.sh
echo "  (or in SDSF directly the command /C $ZOWE_SERVER_PROCLIB_MEMBER)"

# save config log in runtime directory
mkdir  $ZOWE_ROOT_DIR/configure_log
cp $LOG_FILE $ZOWE_ROOT_DIR/configure_log

# remove the working directory
rm -rf $TEMP_DIR
