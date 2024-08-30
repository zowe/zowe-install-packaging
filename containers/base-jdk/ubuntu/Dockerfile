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
RUN CODENAME=$(cat /etc/os-release | grep UBUNTU_CODENAME | cut -d "=" -f 2) \
  && echo deb [trusted=yes] https://ppa.launchpadcontent.net/openjdk-r/ppa/ubuntu "$CODENAME" main >> /etc/apt/sources.list \
  && echo deb-src [trusted=yes] https://ppa.launchpadcontent.net/openjdk-r/ppa/ubuntu "$CODENAME" main >> /etc/apt/sources.list \
  && apt-get update \
  && apt-get install -y \
  openjdk-11-jre \
  && rm -rf /var/lib/apt/lists/* \
  # smoke tests
  && java -version
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/jre
