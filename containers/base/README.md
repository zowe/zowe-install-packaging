# Zowe Component Base Image

[![Build Zowe Base Images](https://github.com/zowe/zowe-install-packaging/actions/workflows/base-images.yml/badge.svg)](https://github.com/zowe/zowe-install-packaging/actions/workflows/base-images.yml)

## General Information

This base image can be used by any Zowe components.

It includes 2 Linux Distro:

- Ubuntu
- Red Hat UBI

Each base image supports both `amd64` and `s390x` CPU architectures.

## Usage

In your `Dockerfile`, you can define base image like this:

```
FROM zowe-docker-release.jfrog.io/ompzowe/base:latest
```

Or if you want to use the most recent snapshot:

```
FROM zowe-docker-snapshot.jfrog.io/ompzowe/base:latest.staging
```
