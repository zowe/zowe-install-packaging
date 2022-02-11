# Zowe Component Base Image with JDK8

[![Build ompzowe/base-jdk](https://github.com/zowe/zowe-install-packaging/actions/workflows/base-jdk-images.yml/badge.svg)](https://github.com/zowe/zowe-install-packaging/actions/workflows/base-jdk-images.yml)

## General Information

This base image can be used by any Zowe components. It has JDK 8 preinstalled.

It includes 2 Linux Distro:

- Ubuntu
- Red Hat UBI

Each base image supports both `amd64` and `s390x` CPU architectures.

## Usage

In your `Dockerfile`, you can define base image like this:

```
FROM zowe-docker-release.jfrog.io/ompzowe/base-jdk:latest
```

Or if you want to use the most recent snapshot:

```
FROM zowe-docker-snapshot.jfrog.io/ompzowe/base-jdk:latest.staging
```
