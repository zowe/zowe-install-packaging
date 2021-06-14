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

if [ $# -lt 2 ]; then
  echo "Usage: $0 -c zowe_install_directory [-g zowe_group] [--skip_temp | -d dsn_prefix | (-l loadlib -p parmlib)]"
  exit 1
fi

ZOWE_GROUP=ZWEADMIN

# TODO LATER - once not called from zowe-configure.sh remove if and keep the export
if [[ -z ${ZOWE_ROOT_DIR} ]]
then
	export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../;pwd)
fi
export ROOT_DIR="${ZOWE_ROOT_DIR}"

while [ $# -gt 0 ]; do
  arg="$1"
  case $arg in
      c|--instance_dir)
        shift
        INSTANCE_DIR=$1
        shift
        ;;
      g|--group)
        shift
        ZOWE_GROUP=$1
        shift
        ;;
      s)
        SKIP_NODE=1
        shift
        ;;
      l|--loadlib)
        shift
        ZIS_LOADLIB=$1
        shift
        ;;
      p|--parmlib)
        shift
        ZIS_PARMLIB=$1
        shift
        ;;
      d|--dsn_prefix)
        shift
        DSN_PREFIX=$1
        shift
        ;;
      n|--skip_temp)
        NO_TEMP=1
        shift
        ;;
    *)
      echo "Invalid option: -$arg" >&2
      exit 1
  esac
done


. ${ZOWE_ROOT_DIR}/bin/internal/zowe-set-env.sh


# Source main utils script
. ${ZOWE_ROOT_DIR}/bin/utils/utils.sh
# this utils usually be sourced from instance dir, but here we are too early
. ${ZOWE_ROOT_DIR}/bin/instance/internal/utils.sh
if [[ -z ${INSTANCE_DIR} ]]
then
  echo "-c parameter not set. Please re-run 'zowe-configure-instance.sh -c <Instance directory>' specifying the location of the new zowe instance directory you want to create"
  exit 1
else
  INSTANCE_DIR=$(get_full_path "${INSTANCE_DIR}")
fi

# Check instance-dir not inside root dir
validate_file_not_in_directory "${INSTANCE_DIR}" "${ZOWE_ROOT_DIR}"
if [[ $? -ne 0 ]]
then
  echo "It looks like the instance directory chosen ${INSTANCE_DIR} was within the zowe runtime install directory ${ZOWE_ROOT_DIR}. This will cause the instance directory to be overwritten when an upgrade is applied. Please choose an alternative instance directory and re-run 'zowe-configure-instance.sh -c <Instance directory>'"
  exit 1
fi

echo_and_log() {
  echo "$1"
  echo "$1" >> ${LOG_FILE}
}

get_zowe_version() {
  export ZOWE_VERSION=$(cat $ZOWE_ROOT_DIR/manifest.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d '[[:space:]]')
}

# Install-time user input like DSN, if can be determined at this point, should be put into instance for later use
# Since this is used to gather ZIS parms currently, it can be skipped if they are provided in args instead.

get_zis_params() {
  if [ -n $DSN_PREFIX ]; then
    ZIS_PARMLIB=${DSN_PREFIX}.SAMPLIB
    ZIS_LOADLIB=${DSN_PREFIX}.SZWEAUTH
  else
    if [ -z $ZIS_LOADLIB -o -z $ZIS_PARMLIB ]; then
      if [ -z $NO_TEMP ]; then
        echo "ZIS parameters wont be recorded due to missing arguments. Rerun this script with -d or -l and -p parameters to fix."
      elif [ -d "/tmp/zowe/${ZOWE_VERSION}" ]; then
        get_zowe_version
        for file in /tmp/zowe/$ZOWE_VERSION/install-*.env; do
          if [[ -f $file ]]; then
            ROOT_DIR_VAL=$(cat $file | grep "^ROOT_DIR=" | cut -d'=' -f2)
            if [[ ROOT_DIR_VAL == ZOWE_ROOT_DIR ]]; then
              . $file
              break;
            fi
          fi
        done
        if [ -z $ZOWE_DSN_PREFIX ]; then
          echo "ZIS parameters wont be recorded due to temporary file parse error. Rerun this script with -d or -l and -p parameters to fix."
        else
          ZIS_PARMLIB=${ZOWE_DSN_PREFIX}.SAMPLIB
          ZIS_LOADLIB=${ZOWE_DSN_PREFIX}.SZWEAUTH
        fi
      else
        echo "ZIS parameters wont be recorded because temporary file not found. Rerun this script with -d or -l and -p parameters to fix."
      fi
    fi
  fi
}

create_new_instance() {
  get_zis_params #may find nothing, thats ok

  sed \
    -e "s#{{root_dir}}#${ZOWE_ROOT_DIR}#" \
    -e "s#{{java_home}}#${JAVA_HOME}#" \
    -e "s#{{node_home}}#${NODE_HOME}#" \
    -e "s#{{zosmf_port}}#${ZOWE_ZOSMF_PORT}#" \
    -e "s#{{zosmf_host}}#${ZOWE_ZOSMF_HOST}#" \
    -e "s#{{zowe_explorer_host}}#${ZOWE_EXPLORER_HOST}#" \
    -e "s#{{zowe_ip_address}}#${ZOWE_IP_ADDRESS}#" \
    -e "s#{{zwes_zis_loadlib}}#${ZIS_LOADLIB}#" \
    -e "s#{{zwes_zis_parmlib}}#${ZIS_PARMLIB}#" \
    "${TEMPLATE}" \
    > "${INSTANCE}"

  chmod -R 750 "${INSTANCE}"
  echo "Created ${INSTANCE} with injected content">> $LOG_FILE
}

# FIXME: make it compatible with zowe.yaml
check_existing_instance_for_updates() {
  echo_and_log "Checking existing ${INSTANCE} for updated properties"

  #zip 1414 - replace root_dir if install has moved
  ROOT_DIR_MATCH=$(grep -c ROOT_DIR=${ZOWE_ROOT_DIR} ${INSTANCE})
  if [[ ${ROOT_DIR_MATCH} -ne 1 ]]
  then
    TEMP_INSTANCE="${TMPDIR:-/tmp}/instance.env"
    cat "${INSTANCE}" | sed -e "s%ROOT_DIR=.*\$%ROOT_DIR=${ZOWE_ROOT_DIR}%" > "${TEMP_INSTANCE}"
    cat "${TEMP_INSTANCE}" > "${INSTANCE}"
    rm -f "${TEMP_INSTANCE}"
  fi

  while read -r line
  do
    test -z "${line%%#*}" && continue      # skip line if first char is #
    key=${line%%=*}
    PROP_VALUE=`cat $INSTANCE | grep ^$key=`
    if [[ -z $PROP_VALUE ]]
    then
      LINES_TO_APPEND=${LINES_TO_APPEND}"${line}\n"
    fi
  done < ${TEMPLATE}

  if [[ -n $LINES_TO_APPEND ]]
  then
    LINES_TO_APPEND=$(echo "$LINES_TO_APPEND" | sed \
      -e "s#{{java_home}}#${JAVA_HOME}#" \
      -e "s#{{node_home}}#${NODE_HOME}#" \
      -e "s#{{zosmf_port}}#${ZOWE_ZOSMF_PORT}#" \
      -e "s#{{zosmf_host}}#${ZOWE_ZOSMF_HOST}#" \
      -e "s#{{zowe_explorer_host}}#${ZOWE_EXPLORER_HOST}#" \
      -e "s#{{zowe_ip_address}}#${ZOWE_IP_ADDRESS}#")

    echo_and_log "Missing properties that will be appended to $INSTANCE:\n$LINES_TO_APPEND"
    echo "\n$LINES_TO_APPEND" >> $INSTANCE
    echo "Properties added, please review these before starting zowe."
  else
    echo_and_log "No updates required"
  fi
}

echo "Creating zowe instance in ${INSTANCE_DIR}"
$(mkdir -p ${INSTANCE_DIR}/bin/internal)
DIRECTORY_CREATE_RC=$?
if [[ $DIRECTORY_CREATE_RC != "0" ]]
then
  echo "We could not create the instance directory and sub-directories in ${INSTANCE_DIR}. Please check permissions and re-run."
  exit 1
fi

LOG_DIR=${INSTANCE_DIR}/logs
mkdir -p ${LOG_DIR}
chmod 777 ${LOG_DIR}
export LOG_FILE=${LOG_DIR}/"configure-`date +%Y-%m-%d-%H-%M-%S`.log"
echo "Created instance directory ${INSTANCE_DIR}" >> $LOG_FILE

# get a list of variables, from the template instance and the existing config to see which ones are missing and add them to the instance
TEMPLATE=${ZOWE_ROOT_DIR}/scripts/instance.template.env
INSTANCE=${INSTANCE_DIR}/instance.env

# Try and work out the variables that we can
if [[ ${SKIP_NODE} != 1 ]]
then
  . ${ZOWE_ROOT_DIR}/bin/zowe-init.sh
else
  . ${ZOWE_ROOT_DIR}/bin/zowe-init.sh -s
fi
echo "Ran zowe-init.sh from ${ZOWE_ROOT_DIR}/bin/zowe-init.sh" >> $LOG_FILE

# Check if instance .env already exists
if [[ -f "${INSTANCE}" ]]
then
  check_existing_instance_for_updates
else
  create_new_instance
fi

#Make install-app.sh present per-instance for convenience
cp ${ZOWE_ROOT_DIR}/components/app-server/share/zlux-app-server/bin/install-app.sh ${INSTANCE_DIR}/bin/install-app.sh
# copy other files we needed for <instance>/bin
cp -R ${ZOWE_ROOT_DIR}/bin/instance/* ${INSTANCE_DIR}/bin

# Make the instance directory writable by the owner and zowe process , but not the bin directory so people can't maliciously edit it
# If this step fails it is likely because the user running this script is not part of the ZOWE group, so have to give more permissions
chmod 775 ${INSTANCE_DIR}
chgrp -R ${ZOWE_GROUP} ${INSTANCE_DIR} 1> /dev/null 2> /dev/null
RETURN_CODE=$?
if [[ $RETURN_CODE != "0" ]]; then
  current_user=$(get_user_id)
  print_and_log_message ""
  print_and_log_message "WARNING: some files or directories in the instance directory ${INSTANCE_DIR} cannot be"
  print_and_log_message "         changed to group ${ZOWE_GROUP}. Will set instance directory to be writable to"
  print_and_log_message "         everyone. To properly setup instance directory permission, please add both"
  print_and_log_message "         install user ${current_user} and Zowe runtime user to ${ZOWE_GROUP} group."
  print_and_log_message ""
  print_and_log_message "         If you don't have ${ZOWE_GROUP} group or want to set a specific Zowe administrator"
  print_and_log_message "         group, please run this command again with the -g flag."
  print_and_log_message ""
  chmod 777 ${INSTANCE_DIR}
fi
chmod -R 755 ${INSTANCE}
chmod -R 755 ${INSTANCE_DIR}/bin

# Go through Zowe build-in components and see they need to be configured for current instance
component_list="jobs-api files-api api-catalog discovery gateway caching-service apiml-common-lib explorer-ui-server explorer-jes explorer-mvs explorer-uss"
for component_name in ${component_list}; do
  cd ${ZOWE_ROOT_DIR}
  . $ZOWE_ROOT_DIR/bin/zowe-configure-component.sh \
    --component-name "${component_name}" \
    --instance_dir "${INSTANCE_DIR}" \
    --target_dir "${ZOWE_ROOT_DIR}/components" \
    --core --log-file "${LOG_FILE}"
done

# FIXME: try to clean up previous static api registrations
#        what happens if user has custom static definitions?
# this variable should be same as what defined in prepare-environment.sh
# STATIC_DEF_CONFIG_DIR=${WORKSPACE_DIR}/api-mediation/api-defs
# if [ -d "${STATIC_DEF_CONFIG_DIR}" ]; then
#   rm -fr "${STATIC_DEF_CONFIG_DIR}"/* 1> /dev/null 2> /dev/null
#   RETURN_CODE=$?
#   if [[ $RETURN_CODE != "0" ]]; then
#     print_and_log_message ""
#     print_and_log_message "WARNING: failed to delete component API static registration files in directory"
#     print_and_log_message "         ${STATIC_DEF_CONFIG_DIR}."
#     print_and_log_message "         It's recommended to cleanup this folder before you starting Zowe."
#     print_and_log_message ""
#     chmod 777 ${INSTANCE_DIR}
#   fi
# fi

echo
echo "Configure instance completed. Please now review the properties in ${INSTANCE} to check they are correct."

# FIXME: hide message until this is ready
# echo
# echo "As technical preview, Zowe now provides a new way to customize your instance with a YAML file."
# echo "You can convert your instance.env file by running this script:"
# echo "  ${INSTANCE_DIR}/bin/utils/convert-to-zowe-yaml.sh > ${INSTANCE_DIR}/zowe.yaml"
# echo "The zowe.yaml will take effect once you delete or rename your ${INSTANCE_DIR}/instance.env file."
# echo "Please check ${INSTANCE_DIR}/bin/example-zowe.yaml and see how you can customize Zowe instance."
# echo "This YAML configuration format is mandatory to deploy Zowe in a Parallel Sysplex environment."

echo
echo "To start Zowe run the script "${INSTANCE_DIR}/bin/zowe-start.sh
echo "   (or in SDSF directly issue the command /S ZWESVSTC,INSTANCE='${INSTANCE_DIR}')"
echo "To stop Zowe run the script "${INSTANCE_DIR}/bin/zowe-stop.sh
echo "  (or in SDSF directly the command /C ZWESVSTC)"

echo "zowe-configure-instance.sh completed">> $LOG_FILE
