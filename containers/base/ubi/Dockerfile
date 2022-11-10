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
      version="2.0.1" \
      release="0" \
      summary="Base image for Zowe components" \
      description="Base image for Zowe components"

##################################
# arguments
# zowe default user id
ARG UID=20000
# zowe default group id
ARG GID=20000
# node build CPU arch
ARG NODE_CPU_ARCH=x64

##################################
# environments
ENV NODE_VERSION=18.12.1

##################################
# customize
RUN set -ex \
    # shadow-utils is needed for having adduser groupadd commands
    && microdnf install --nodocs shadow-utils \
    # define zowe user/group
    && groupadd --gid ${GID} zowe \
    && useradd -r -m --no-log-init --uid ${UID} --gid ${GID} --home /home/zowe zowe \
    # create /licenses folder
    && mkdir -p /licenses \
    && chown zowe.zowe /licenses \
    # create /component folder
    && mkdir -p /component \
    && chown zowe.zowe /component \
    # install node.js which is mandatory for now
    && microdnf install --nodocs \
      findutils \
      tar \
      xz \
    && ARCH=${NODE_CPU_ARCH} \
    # gpg keys listed at https://github.com/nodejs/node#release-keys
    && for key in \
      4ED778F539E3634C779C87C6D7062848A1AB005C \
      94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
      74F12602B6F1C4E913FAA37AD3A89613643B6201 \
      71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
      8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
      C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
      DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
      A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
      108F52B48DB57BB0CC439B2997B01419BD92F80A \
      B9E2F5981AA6E0CD28160D9FF13993A75599653C \
    ; do \
        gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
        gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
    done \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
    # smoke tests
    && node --version \
    && npm --version \
    # remove unused pacakges
    && microdnf remove \
      findutils \
      tar \
      xz \
    # clean up
    && microdnf clean all --enablerepo='*'
