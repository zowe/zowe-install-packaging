#!/bin/sh
# This program and the accompanying materials are
# made available under the terms of the Eclipse Public License v2.0 which accompanies
# this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.

if [ $# -lt 8 ]; then
  echo "Usage: $0 -i instance_directory -o output_directory -t to_install_type -f from_install_type [-k input_keystore_directory] [-d output_keystore_directory] [-r output_root_directory]\n Types: zos, container, docker, kubernetes, docker-bundle"
  exit 1
fi

# set defaults here


while [ $# -gt 0 ]; do
  arg="$1"
  case $arg in
    -i)
        shift
        INSTANCE_DIR=$1
        shift
    ;;
    -k)
        shift
        KEYSTORE_DIR=$1
        shift
    ;;
    -t)
        shift
        TO_TYPE=$1
        shift
    ;;
    -f)
        shift
        FROM_TYPE=$1
        shift
    ;;
    -o)
        shift
        OUTPUT_DIR=$1
        shift
    ;;
    -r)
        shift
        export MIGRATE_ROOT_DIR=$1
        shift
    ;;
    -d)
        shift
        export MIGRATE_KEYSTORE_DIRECTORY=$1
        shift
    ;;
    *)
      echo "Invalid option: $1" >&2
      exit 1
  esac
done

if [ -z $INSTANCE_DIR -o -z $TO_TYPE -o -z $FROM_TYPE -o -z OUTPUT_DIR ]; then
  echo "Usage: $0 -i instance_directory -o output_directory -t to_install_type -f from_install_type [-k keystore_directory]\n Types: zos, container, docker, kubernetes, docker-bundle"
  exit 1
fi

readInstance() {
  mkdir -p $OUTPUT_DIR/instance

  
  if [ $(. "$INSTANCE_DIR/instance.env" 2> /dev/null) ]; then
    source_env "$INSTANCE_DIR/instance.env"
  else
    echo "Can't read instance file, attempting to read as EBCDIC."
    iconv -f 819 -t 1047 "$INSTANCE_DIR/instance.env" > "$OUTPUT_DIR/instance/instance.env.iconv1047"
    source_env "$OUTPUT_DIR/instance/instance.env.iconv1047"
  fi
}

readKeystore() {
  mkdir -p $OUTPUT_DIR/keystore

  
  if [ $(. "$KEYSTORE_DIR/zowe-certificates.env" 2> /dev/null) ]; then
    source_env "$KEYSTORE_DIR/zowe-certificates.env"
  else
    echo "Can't read keystore file, attempting to read as EBCDIC."
    iconv -f 819 -t 1047 "$KEYSTORE_DIR/zowe-certificates.env" > "$OUTPUT_DIR/keystore/zowe-certificates.env.iconv1047"
    source_env "$OUTPUT_DIR/keystore/zowe-certificates.env.iconv1047"
  fi
}

source_env() {
  env_file=$1

  . "${env_file}"

  while read -r line ; do
    # skip line if first char is #
    test -z "${line%%#*}" && continue
    key=${line%%=*}
    export $key
  done < "${env_file}"
}

if [ -e "$INSTANCE_DIR/instance.env" ]; then
  mkdir -p $OUTPUT_DIR
  export ENV_NODE_HOME="$NODE_HOME"
  export ENV_JAVA_HOME="$JAVA_HOME"

  readInstance
  if [ ! -z "$KEYSTORE_DIR" ]; then
    export KEYSTORE_DIRECTORY="$KEYSTORE_DIR"
  fi
  readKeystore

  cd utils/migrate-tool
  node migrate-tool.js "$INSTANCE_DIR" "$OUTPUT_DIR" "$TO_TYPE" "$FROM_TYPE"
else
  echo "Error: cannot read instance.env"
  exit 1
fi
