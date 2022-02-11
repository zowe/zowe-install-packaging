# Zowe Launch Scripts Image

[![Build ompzowe/zowe-launch-scripts](https://github.com/zowe/zowe-install-packaging/actions/workflows/zowe-launch-scripts-images.yml/badge.svg)](https://github.com/zowe/zowe-install-packaging/actions/workflows/zowe-launch-scripts-images.yml)

## General Information

This image can be used to initialize Zowe runtime environment for component.

It includes 2 Linux Distro:

- Ubuntu
- Red Hat UBI

Each image supports both `amd64` and `s390x` CPU architectures.

## Usage

Image `zowe-docker-release.jfrog.io/ompzowe/zowe-launch-scripts:latest` can be used as `initContainers` spec of Kubernetes configuration.
