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

# base image tag
ARG ZOWE_BASE_IMAGE=latest-ubuntu

FROM zowe-docker-release.jfrog.io/ompzowe/base:${ZOWE_BASE_IMAGE}

##################################
# labels
LABEL name="Zowe Base Image with node.js enabled" \
      maintainer="jack-tiefeng.jia@ibm.com" \
      vendor="Zowe" \
      version="2.0.2" \
      release="0" \
      summary="Base image for Zowe components with node.js enabled" \
      description="Base image for Zowe components with node.js enabled"

##################################
# node.js is installed in base image, so no actions here
ENV NODE_HOME=/usr/local
