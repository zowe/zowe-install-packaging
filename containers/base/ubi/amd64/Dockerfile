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

FROM registry.redhat.io/ubi8/ubi-minimal:latest

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
# shadow-utils is needed for having adduser groupadd commands
RUN microdnf install shadow-utils \
    && groupadd --gid ${GID} zowe \
    && useradd -M --uid ${UID} --gid ${GID} --home /home/zowe zowe

##################################
# Install node.js which is mandatory for now
ENV NODE_VERSION=14
RUN microdnf module enable nodejs:$NODE_VERSION \
    && MODULE_DEPS="make gcc gcc-c++ libatomic_ops git openssl-devel" \
    && INSTALL_PKGS="$MODULE_DEPS nodejs npm nodejs-nodemon nss_wrapper" \
    && microdnf install --setopt=tsflags=nodocs $INSTALL_PKGS \
    && rpm -V $INSTALL_PKGS \
    && microdnf clean all --enablerepo='*' \
    # smoke tests
    && node --version \
    && npm --version

