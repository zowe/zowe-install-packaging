#!/bin/bash

# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.

cd /root/sources
dnf list --installed | sed '1d' | cut -d' ' -f1 > ../packages.list

#while read line;
#  do $(dnf download --source --quiet "$line");
#done <../packages.list


  
#rpm_files="home/zowe/sources/*.rpm"
#for rpm in $rpm_files;
#  do OUT=$(echo $rpm | sed s/\.rpm//) && mkdir $OUT && cd $OUT && rpm2cpio $rpm | cpio -idm;
#done

#rm *.rpm && rm ../packages.list
rm ../packages.list
