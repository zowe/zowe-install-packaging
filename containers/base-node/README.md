# Zowe Component Base Image with Node.JS

[![Build ompzowe/base-node](https://github.com/zowe/zowe-install-packaging/actions/workflows/base-node-images.yml/badge.svg)](https://github.com/zowe/zowe-install-packaging/actions/workflows/base-node-images.yml)

## General Information

This base image can be used by any Zowe components. It has node.js LTS (currently v14.x) preinstalled.

It includes 2 Linux Distro:

- Ubuntu
- Red Hat UBI

Each base image supports both `amd64` and `s390x` CPU architectures.

## Usage

In your `Dockerfile`, you can define base image like this:

```
FROM zowe-docker-release.jfrog.io/ompzowe/base-node:latest
```

Or if you want to use the most recent snapshot:

```
FROM zowe-docker-snapshot.jfrog.io/ompzowe/base-node:latest.staging
```
