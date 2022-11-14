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

FROM zowe-docker-release.jfrog.io/ompzowe/base:1.0.0-ubi

##################################
# labels
LABEL name="Zowe Base Image with JDK enabled" \
      maintainer="jack-tiefeng.jia@ibm.com" \
      vendor="Zowe" \
      version="1.0.0" \
      release="0" \
      summary="Base image for Zowe components with JDK enabled" \
      description="Base image for Zowe components with JDK enabled"

##################################
# Install JDK
RUN microdnf install --nodocs \
      java-1.8.0-openjdk \
    && microdnf clean all --enablerepo='*' \
    # smoke tests
    && java -version
ENV JAVA_HOME=/usr/lib/jvm/jre-1.8.0
