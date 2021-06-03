#!/bin/sh
# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.

if [ $# -lt 4 ]; then
  echo "Usage: $0 -i instance_directory -o output_directory -t to_install_type -f from_install_type\n Types: zos, container, docker, kubernetes, docker-bundle"
  exit 1
fi

# set defaults here


while getopts "i:t:f" opt; do
  case $opt in
    i) INSTANCE_DIR=$OPTARG;;
    k) KEYSTORE_DIR=$OPTARG;;
    t) TO_TYPE=$OPTARG;;
    f) FROM_TYPE=$OPTARG;;
    o) OUTPUT_DIR=$OPTARG;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $(($OPTIND-1))

if [ -e "$INSTANCE_DIR/instance.env" ]; then
  mkdir -p $OUTPUT_DIR

  readInstance()
  if [ -z "$KEYSTORE_DIR" ]; then
    KEYSTORE_DIR="$KEYSTORE_DIRECTORY"
  fi
  readKeystore()
  cd utils
  node migrate-tools.js "$INSTANCE_DIR" "$OUTPUT_DIR" "$TO_TYPE" "$FROM_TYPE"
  else
    echo "Error: cannot read instance.env"
  fi
else
  echo "Error: cannot read INSTANCE_DIR file read-essential-vars.sh"
  exit 1
fi

readInstance() {
  . "$INSTANCE_DIR/instance.env"
  if [ $? -ne 0 ]; then
    mkdir -p $OUTPUT_DIR/instance
    iconv -f 819 -t 1047 "$INSTANCE_DIR/instance.env" > "$OUTPUT_DIR/instance/instance.env.iconv1047"
    . "$OUTPUT_DIR/instance/instance.env.iconv1047"
  fi
}

readKeystore() {
  . "$KEYSTORE_DIR/zowe-certificates.env"
  if [ $? -ne 0 ]; then
    mkdir -p $OUTPUT_DIR/keystore
    iconv -f 819 -t 1047 "$KEYSTORE_DIR/zowe-certificates.env" > "$OUTPUT_DIR/keystore/zowe-certificates.env.iconv1047"
    . "$OUTPUT_DIR/keystore/zowe-certificates.env.iconv1047"
  fi    
}
