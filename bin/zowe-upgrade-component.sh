#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2021
################################################################################

################################################################################
# Zowe updater script
#
# This script will upgrade a specified Zowe component to the latest version. It will
# get consumed by the zowe-install script during the Zowe installation.
#
# Command line options:
# -o|--component-package required. path to the component package or directory.
# -l|--logs-dir          optional. path to logs directory.
# -f|--log-file          optional. write log to the file specified.
################################################################################

# Prepare shell environment
if [ -z "${ZOWE_ROOT_DIR}" ]; then
  export ZOWE_ROOT_DIR=$(cd $(dirname $0)/../;pwd)
fi

SCRIPT_DIR=$(dirname $0)/bin
repository_path="libs-snapshot-local"

#######################################################################
# Functions
prepare_log_file() {
    if [ -z "${LOG_FILE}" ]; then
        set_install_log_directory "${LOG_DIRECTORY}"
        validate_log_file_not_in_root_dir "${LOG_DIRECTORY}" "${ZOWE_ROOT_DIR}"
        set_install_log_file "zowe-upgrade-component"
    else
        set_install_log_file_from_full_path "${LOG_FILE}"
        validate_log_file_not_in_root_dir "${LOG_FILE}" "${ZOWE_ROOT_DIR}"
    fi
}

error_handler() {
    print_error_message "$1"
    exit 1
}

# Downloading the Zowe component artifact from Zowe artifactory and saving it into the temporary components directory.
download_apiml_artifacts() {
  artifact_group="apiml/sdk"
  path=https://zowe.jfrog.io/artifactory/$repository_path/org/zowe/$artifact_group/$artifact_name
  version=$(node "${SCRIPT_DIR}"/utils/curl.js $path/maven-metadata.xml -k | grep latest | sed "s/.*<latest>\([^<]*\)<\/latest>.*/\1/")
  build=$(node "${SCRIPT_DIR}"/utils/curl.js $path/"$version"/maven-metadata.xml -k | grep '<value>' | head -1 | sed "s/.*<value>\([^<]*\)<\/value>.*/\1/")
  full_name=$artifact_name-$build.zip
  print_and_log_message "Downloading the ${artifact_name} artifact..."
  node ${SCRIPT_DIR}/utils/curl.js $path/"$version"/"$full_name" -o ${temporary_components_directory}/$(basename "$url")
  rc=$?;

  if [ $rc != 0 ]; then
    error_handler "The ${artifact_name} artifact download failed."
  else
    print_and_log_message "The ${artifact_name} artifact has been downloaded into the directory ${temporary_components_directory}"
  fi
}

download_other_artifacts() {
  artifact_group=$1
  repository_path=$2
  path=https://zowe.jfrog.io/artifactory/api/storage/$repository_path/org/zowe/$artifact_group/?lastModified
  jq="${SCRIPT_DIR}"/utils/njq/src/index.js
  url=$(node "${SCRIPT_DIR}"/utils/curl.js "$path" -k | node "${jq}" -r '.uri')
  url=$(node "${SCRIPT_DIR}"/utils/curl.js "$url" -k | node "${jq}" -r '.downloadUri')
  print_and_log_message "Downloading the ${artifact_name} artifact..."
  node ${SCRIPT_DIR}/utils/curl.js "$url" -o ${temporary_components_directory}/$(basename "$url")
  rc=$?;

  if [ $rc != 0 ]; then
    error_handler "The ${artifact_name} artifact download failed."
  else
    print_and_log_message "The ${artifact_name} artifact has been downloaded into the directory ${temporary_components_directory}"
  fi
}

#######################################################################
# Parse command line options
while [ $# -gt 0 ]; do #Checks for parameters
  arg="$1"
      case $arg in
          -o|--component-package)
              shift
              artifact_name=$(basename $1)
              temporary_components_directory=$(get_full_path "$1")
              temporary_components_directory=$(cd $(dirname "$temporary_components_directory") && pwd)
              shift
          ;;
          -l|--logs-dir) # Represents the path to the installation logs
              shift
              LOG_DIRECTORY=$1
              shift
          ;;
          -f|--log-file) # write logs to target file if specified
              shift
              LOG_FILE=$1
              shift
          ;;
          *)
              error_handler "$1 is an invalid option\ntry: zowe-upgrade-component.sh -o <PATH_TO_COMPONENT>"
              shift
      esac
done

#######################################################################
# Parse component package
case $artifact_name in
  launcher*)
    artifact_name=launcher
    full_name=launcher-[RELEASE].pax
    download_other_artifacts "launcher" "libs-release-local"
    ;;
  jobs-api-package*)
    full_name=jobs-api-package-[RELEASE].zip
    download_other_artifacts "explorer/jobs" "libs-release-local"
    ;;
  files-api-package*)
    full_name=files-api-package-[RELEASE].zip
    download_other_artifacts "explorer/files" "libs-release-local"
    ;;
  api-catalog-package*)
    artifact_name=api-catalog-package
    download_apiml_artifacts
    ;;
  discovery-package*)
    artifact_name=discovery-package
    download_apiml_artifacts
    ;;
  gateway-package*)
    artifact_name=gateway-package
    download_apiml_artifacts
    ;;
  caching-service-package*)
    artifact_name=caching-service-package
    download_apiml_artifacts
    ;;
  apiml-common-lib-package*)
    artifact_name=apiml-common-lib-package
    download_apiml_artifacts
    ;;
  explorer-ui-server*)
    artifact_name=explorer-ui-server
    full_name=$artifact_name-[RELEASE].pax
    download_other_artifacts "explorer-ui-server" "libs-snapshot-local"
    ;;
  explorer-jes*)
    artifact_name=explorer-jes
    full_name=$artifact_name-[RELEASE].pax
    download_other_artifacts "explorer-jes" "libs-release-local"
    ;;
  explorer-mvs*)
    artifact_name=explorer-mvs
    full_name=$artifact_name-[RELEASE].pax
    download_other_artifacts "explorer-mvs" "libs-release-local"
    ;;
  explorer-uss*)
    artifact_name=explorer-uss
    full_name=$artifact_name-[RELEASE].pax
    download_other_artifacts "explorer-uss" "libs-release-local"
    ;;
   zss*)
    artifact_name=zss
    full_name=$artifact_name-[RELEASE].pax
    download_other_artifacts "zss" "libs-snapshot-local"
    ;;
   app-server*)
    artifact_name=zlux-core
    full_name=$artifact_name-[RELEASE].pax
    download_other_artifacts "zlux/zlux-core" "libs-snapshot-local"
    ;;
esac

prepare_log_file

