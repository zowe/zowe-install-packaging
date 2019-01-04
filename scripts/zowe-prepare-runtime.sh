#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2018
################################################################################

zluxserverdirectory='zlux-example-server'

echo "Installing the JES, MVS and USS Explorer into "$INSTALL_DIR/files/plugins/ >> $LOG_FILE
# (1) Install the MVS, USS and JES Explorer files
# Switch to where the explorer tile files are within the atlas install 
cd $INSTALL_DIR/files/plugins/

#line=$(head -n 1 ./explorer-JES/web/index.html)
#if [ ! "$line" = "<!DOCTYPE html>" ]
#	then
#		#Convert files, we should check if this is necessary first, but how?
#		for file in $(find ./ -name '*.json' -o -name '*.html')
#		do
#			mv $file $file.icv
#           iconv -f IBM-1047 -t ISO8859-1 $file.icv > $file
#			echo "converting $file from 1047 to 8559-1" >> $LOG_FILE
#           rm -f   $file.icv
#  			chtag -tc 1047 $file
#		done
#fi

sed 's/$atlasPortPlaceholder/'"${ZOWE_EXPLORER_SERVER_HTTPS_PORT}"'/g' ./explorer-MVS/web/index.html > $TEMP_DIR/mvsWithPort.html
sed 's/$atlasHostnamePlaceholder/'"${ZOWE_IPADDRESS}"'/g' $TEMP_DIR/mvsWithPort.html > ./explorer-MVS/web/index.html

chmod -R u+w $ZOWE_ROOT_DIR/$zluxserverdirectory/plugins/

mkdir -p $ZOWE_ROOT_DIR/explorer-MVS
cp -R ./explorer-MVS $ZOWE_ROOT_DIR/
cp com.ibm.atlas.explorer-MVS.json $ZOWE_ROOT_DIR/$zluxserverdirectory/plugins/

chtag -b $ZOWE_ROOT_DIR/explorer-MVS/web/images/explorer-MVS.png
