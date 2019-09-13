#!/bin/bash -e

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018, 2019
################################################################################

################################################################################
# This script will publish Zowe to target folder
# 
# Parameters:
# - targert directory
# - build version
# 
# zowe-{version}.pax should be placed in ~ directory
#
# Example:
# ./zowe-publish.sh /var/www/projectgiza.org/builds 0.9.0
################################################################################

ZOWE_BUILD_DIRECTORY=$1
ZOWE_BUILD_CATEGORY=$2
ZOWE_BUILD_VERSION=$3
CODE_SIGNING_KEY=$4
CODE_SIGNING_PASSPHRASE=$5
ZOWE_BUILD_FILE=zowe-$ZOWE_BUILD_VERSION.pax
ZOWE_CLI_PACKAGE=zowe-cli-package-$ZOWE_BUILD_VERSION.zip

# test parameters
if [ -z "$ZOWE_BUILD_DIRECTORY" ]; then
  echo "Error: build directory is missing"
  exit 1
fi
if [ -z "$ZOWE_BUILD_CATEGORY" ]; then
  echo "Error: build category is missing"
  exit 1
fi
if [ -z "$ZOWE_BUILD_VERSION" ]; then
  echo "Error: build version is missing"
  exit 1
fi
if [ ! -f $ZOWE_BUILD_FILE ]; then
  echo "Error: cannot find $ZOWE_BUILD_FILE"
  exit 1
fi
if [ ! -f $ZOWE_CLI_PACKAGE ]; then 
  echo "Error: cannot find $ZOWE_CLI_PACKAGE"
  exit 1
fi

# move Zowe build to target folder
echo "> move $ZOWE_BUILD_FILE to $ZOWE_BUILD_DIRECTORY/$ZOWE_BUILD_VERSION ..."
mkdir -p $ZOWE_BUILD_DIRECTORY/$ZOWE_BUILD_CATEGORY/$ZOWE_BUILD_VERSION
mv ~/$ZOWE_BUILD_FILE $ZOWE_BUILD_DIRECTORY/$ZOWE_BUILD_CATEGORY/$ZOWE_BUILD_VERSION
mv ~/$ZOWE_CLI_PACKAGE $ZOWE_BUILD_DIRECTORY/$ZOWE_BUILD_CATEGORY/$ZOWE_BUILD_VERSION
cd $ZOWE_BUILD_DIRECTORY/$ZOWE_BUILD_CATEGORY/$ZOWE_BUILD_VERSION

# split into trunks
echo "> split Zowe build ..."
rm zowe-$ZOWE_BUILD_VERSION-part-* 2> /dev/null || true
split -b 70m -a 1 --additional-suffix=.bin $ZOWE_BUILD_FILE zowe-$ZOWE_BUILD_VERSION-part-
ls -1 zowe-$ZOWE_BUILD_VERSION-part-*.bin > zowe-$ZOWE_BUILD_VERSION-parts.txt

# generate SHA512 hash for trunks
ZOWE_SPLITED=$(ls -1 zowe-$ZOWE_BUILD_VERSION-part-*.bin)
echo "> generating hash for trunks ..."
for f in $ZOWE_SPLITED; do
  echo "  > $f"
  gpg --print-md SHA512 $f > $f.sha512
done
# generate SHA512 hash for big file
echo "> generating hash for Zowe build ..."
gpg --print-md SHA512 $ZOWE_BUILD_FILE > $ZOWE_BUILD_FILE.sha512
if [ ! -z "${CODE_SIGNING_KEY}" ]; then
  # signing the build
  echo "> signing the Zowe build with key ${CODE_SIGNING_KEY} ..."
  echo $CODE_SIGNING_PASSPHRASE | gpg --batch --pinentry-mode loopback --passphrase-fd 0 --local-user $CODE_SIGNING_KEY --sign --armor --detach-sig $ZOWE_BUILD_FILE
fi
# generate SHA512 hash for cli bundle
echo "> generating hash for Zowe CLI bundle ..."
gpg --print-md SHA512 $ZOWE_CLI_PACKAGE > $ZOWE_CLI_PACKAGE.sha512
if [ ! -z "${CODE_SIGNING_KEY}" ]; then
  # signing the build
  echo "> signing the Zowe CLI bundle with key ${CODE_SIGNING_KEY} ..."
  echo $CODE_SIGNING_PASSPHRASE | gpg --batch --pinentry-mode loopback --passphrase-fd 0 --local-user $CODE_SIGNING_KEY --sign --armor --detach-sig $ZOWE_CLI_PACKAGE
fi

echo "> generating version file ..."
echo "$ZOWE_BUILD_VERSION" > version
if [ ! -z "${CODE_SIGNING_KEY}" ]; then
  echo "> generating code-signing-key file ..."
  echo "${CODE_SIGNING_KEY}" > code-signing-key
fi

# show build result
echo "> build folder result:"
pwd
ls -la .

# exit successful
echo "> done"
exit 0
