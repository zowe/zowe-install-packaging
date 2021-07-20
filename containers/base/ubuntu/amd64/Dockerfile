#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

FROM ubuntu:latest

##################################
# labels
LABEL name="Zowe Base Image" \
      maintainer="jack-tiefeng.jia@ibm.com" \
      vendor="Zowe" \
      version="0.0.1" \
      release="0" \
      summary="Base image for Zowe components" \
      description="Base image for Zowe components"

##################################
# arguments
# zowe default user id
ARG UID=20000
# zowe default group id
ARG GID=20000

##################################
# define zowe user/group
RUN groupadd -g $GID -r zowe && useradd --no-log-init -u $UID -d /home/zowe -r -g zowe zowe
