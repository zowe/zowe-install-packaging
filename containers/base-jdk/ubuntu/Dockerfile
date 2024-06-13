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

FROM zowe-docker-release.jfrog.io/ompzowe/base:latest-ubuntu

##################################
# labels
LABEL name="Zowe Base Image with JDK enabled" \
      maintainer="jack-tiefeng.jia@ibm.com" \
      vendor="Zowe" \
      version="2.0.2" \
      release="0" \
      summary="Base image for Zowe components with JDK enabled" \
      description="Base image for Zowe components with JDK enabled"

##################################
# Install JDK
RUN apt-get update \
    && apt-get install -y \
      openjdk-8-jre \
    && rm -rf /var/lib/apt/lists/* \
    # smoke tests
    && java -version
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre
