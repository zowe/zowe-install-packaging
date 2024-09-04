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

FROM zowe-docker-release.jfrog.io/ompzowe/base:3-ubuntu

##################################
# labels
LABEL name="Zowe Base Image with JDK enabled" \
  maintainer="mark.ackert@broadcom.com" \
  vendor="Zowe" \
  version="3.0.0" \
  release="0" \
  summary="Base image for Zowe components with JDK enabled" \
  description="Base image for Zowe components with JDK enabled"

##################################

# Install JDK. We manually add apt sources to avoid installing python, which is required for add-apt-repository.
RUN apt-get update \
  && apt-get install -y \
  openjdk-17-jre \
  && rm -rf /var/lib/apt/lists/* \
  # smoke tests
  && java -version
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64/jre
