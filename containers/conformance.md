# Zowe Conformance Criteria Related to Containerization

**DRAFT**

These conformance criteria are applicable for all Zowe components intending to run in a containerized environment. The containerized environment could be Kubernetes or OpenShift running on Linux or Linux on Z. This may also apply to `docker-compose` running on Linux, Windows, Mac OS, or zCX.

## Image

In general, the image should follow [Best practices for writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/). Below requirements are in addition to the list.

### Base Image

You are free to choose a base image based on your requirements.

Here are our recommendations for core Zowe components:

- Zowe base images:
  * base on Ubuntu and Red Hat Universal Base Image,
  * provide common dependencies including JDK and/or node.js,
  * support both `amd64` and `s390x` architecture.
- [Red Hat Universal Base Image 8 Minimal](https://developers.redhat.com/articles/ubi-faq?redirect_fragment=resources#ubi_details)
- [Ubuntu](https://hub.docker.com/_/ubuntu)

The image should contain as few software packages as possible for security, and should be as small as possible such as by reducing package count and layers.

### Multi-CPU Architecture

- Zowe core components must release images based on both `amd64` and `s390x` CPU architecture.
- Zowe core component images must use multiple manifests to define if the image supports multiple CPU architecture.

### Image Label

These descriptive labels are required in the Dockerfile: `name`, `maintainer`, `vendor`, `version`, `release`, `summary`, and `description`.

Example line:

```
### Required Labels 
LABEL name="APPLICATION NAME" \
      maintainer="EMAIL@ADDRESS" \
      vendor="COMPANY NAME" \
      version="VERSION NUMBER" \
      release="RELEASE NUMBER" \
      summary="APPLICATION SUMMARY" \
      description="APPLICATION DESCRIPTION" \
```

### Tag

Zowe core component image tags must be a combination of the following information in this format: `<version>-<linux-distro>[-<cpu-arch>][-sources][.<customize-build>]`.

- **version**: must follow [semantic versioning](https://semver.org/) or partial semantic versioning with major or major + minor. It may also be `latest` or `lts`. For example, `1`, `1.23`, `1.23.0`, `lts`, `latest`, etc.
- **linux-distro**: for example, `ubi`, `ubuntu`, etc.
- **cpu-arch**: for example, `amd64`, `s390x`, etc.
- **customize-build**: string sanitized by converting non-letters and non-digits to dashes. For example, `pr-1234`, `users-john-fix123`, etc.
- **Source Build**: must be string `-sources` appended to the end of tag.
  * If this is a source build, the tag must contain full version number (major+minor+patch) information.
  * Linux Distro information is recommended.
  * Must NOT contain customize build information.
  * For example: `1.23.0-ubi-sources`.

For example, these are valid image tags:

- latest
- latest-ubuntu
- latest-ubuntu-sources
- latest-ubi
- latest-ubi-sources
- lts
- lts-ubuntu
- lts-ubi
- 1
- 1-ubuntu
- 1-ubi
- 1.23
- 1.23-ubuntu
- 1.23-ubi
- 1.23.0
- 1.23.0-ubuntu
- 1.23.0-ubuntu-amd64
- 1.23.0-ubuntu-sources
- 1.23.0-ubi
- 1.23.0-ubi-s390x
- 1.23.0-ubi-sources
- 1.23.0-ubuntu.pr-1234
- 1.23.0-ubi.users-john-test1

Same image tag pattern are recommended for Zowe extensions.
### Files and Directories

This is the required folder structure for all Zowe components:

```
/licenses
/component
  +- README.md
```

- `/licenses` folder holds all license related files. It MUST include at least the license information for current application. It's recommended to include a license notice file for all pedigree dependencies. All licenses files must be in UTF-8 encoding.
- `/component/README.md` provides information about the application for end-user.

These file(s) and folder(s) are recommended:

```
/component
  +- manifest.json or manifest.yaml
  +- /bin/<lifecycle-scripts>
  +- <other-application-files>
```

- `/component/manifest.(json|yaml)` is recommended for Zowe components. The format of this file is defined at [Zowe component manifest](https://docs.zowe.org/stable/extend/packaging-zos-extensions/#zowe-component-manifest). Components must use the same manifest file as when it's running on z/OS.
- `/component/bin/<lifecycle-scripts>` must remain the same as what it is when running on z/OS.

### Environment Variable(s)

These environment variable(s) must be set as a fixed value in the image:

- `ZOWE_COMPONENT_ID`: this is the Zowe component ID for current image. For example: `ENV ZOWE_COMPONENT_ID=gateway`.

### User `zowe`

In the Dockerfile, a `zowe` user and group must be created. The `zowe` user `UID` and group `GID` must be defined as `ARG` and with default value `UID=20000` and `GID=20000`. Example commands:

```
ARG UID=20000
ARG GID=20000
RUN groupadd -g $GID -r zowe && useradd --no-log-init -u $UID -d /home/zowe -r -g zowe zowe
```

`USER zowe` must be specified before the first `CMD` or `ENTRYPOINT`.

### Multi-Stage Build

Multi-stage build is recommended to keep images small and concise. Learn more from [Use multi-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/).

## Runtime

This section is mainly for information. No actions are required for components except where it's specified explicitly.

Below sections are mainly targeting Kubernetes or OpenShift environments. Starting Zowe containers in a Docker environment with `docker-compose` is in a planning stage and may change some of the requirements.

### General rules

**Components MUST:**

- NOT be started as root user in the container.
- listen on only ONE port in the container except for API Mediation Layer Gateway.
- be cloud vendor neutral and must NOT rely on features provided by specific cloud vendor.
- NOT rely on host information such as `hostIP`, `hostPort`, `hostPath`, `hostNetwork`, `hostPID` and `hostIPC`.
- MUST accept either `instance.env` or `zowe.yaml` as a configuration file, the same as when running on z/OS.

### Files and Directories

In the runtime, the Zowe content are organized in this structure:

```
/home
  +- /zowe
    +- /runtime
    +- /extension
      +- /<component-id>
    +- /instance
      +- instance.env or zowe.yaml
      +- /logs
      +- /workspace
    +- /keystore
      +- zowe-certificates.env
```

- `/home/zowe/runtime` is a shared volume initialized by the `zowe-launch-scripts` container.
- `/home/zowe/extension/<component-id>` is a symbolic link to the `/component` directory. `<component-id>` is `ZOWE_COMPONENT_ID` defined in `ENV`.
- `/home/zowe/instance/(instance.env|zowe.yaml)` is a Zowe configuration file and MUST be mounted from a ConfigMap.
- `/home/zowe/keystore/zowe-certificates.env` is optional if the user is using `instance.env`. If this configuration exists, it MUST be mounted from a ConfigMap.
- Any confidential environment variables, for example, a Redis password, in `instance.env` or `zowe.yaml` must be extracted and stored as Secrets. These configurations must be imported back as environment variables.

### ConfigMap and Secrets

- `instance.env` or `zowe.yaml` must be stored in a ConfigMap and be mounted under `/home/zowe/instance` directory.
- If the user is using `instance.env`, `<keystore>/zowe-certificates.env` content must also be stored in a ConfigMap and be mounted to `/home/zowe/keystore`.
- All certificates must be stored in Secrets. Those files will be mounted under the `/home/zowe/keystore` directory.
- Secrets must be defined manually by a system administrator. Zowe Helm Chart and Zowe Operator do NOT define content of Secrets.

### `zowe-launch-component` Image and initContainers

- The `zowe-launch-component` image contains necessary scripts to start Zowe components in the Zowe context.
- This image has a `/home/zowe` directory and it will be shared and mounted to all Zowe component containers as `/home/zowe/runtime`.
- In Kubernetes and OpenShift environments this step is defined with [`initContainers` specification](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/).

### Zowe Workspace Directory

- Zowe workspace directory `/home/zowe/instance/workspace` will be defined as a persistent volume.
- Components writing to this directory should be aware of the potential conflicts of same-time writing by multiple instances of the same component.
- Components writing to this directory must NOT write container specific information to this directory as it may potentially overwritten by another container.

### Command Override

- Component `CMD` and `ENTRYPOINT` directives will be overwritten with the Zowe launch script used to start it in Zowe context.

### Persistent Volume(s)

- These persistent volume(s) MUST be created:
  * `zowe-workspace` mounted to `/home/zowe/instance/workspace`.
- The system administrator MUST define the persistent volume manually. Zowe Helm Chart and Zowe Operator do NOT create persistent volumes.

## CI/CD

### Build, Test and Release

- Zowe core component and extension images MUST be built, tested and released on their own cadence.
- The component CI/CD pipeline MUST NOT rely on the Zowe level CI/CD pipeline and Zowe release schedule.
- Zowe core component images must be tested. This includes starting the component and verifying the runtime container works as expected.
- It is recommended to build snapshot images before release. Zowe core components MUST publish snapshot images to the `zowe-docker-snapshot.jfrog.io` registry with proper [tags](#tag).
- Zowe core component images MUST be released before Zowe is released.
- Zowe core components MUST publish release images to both `zowe-docker-release.jfrog.io` and [Docker hub](https://hub.docker.com/) registry under `ompzowe/` prefix.
- Release images MUST also update relevant major/minor version tags and the `latest` tag. For example, when a component releases a `1.2.3` image, the component CI/CD pipeline MUST also tag the image as `1.2`, `1` and `latest`. Update the `lts` tag when it is applicable.
- Zowe core component release images MUST be signed by Zowe committer(s).

### Image Scan

#### Security Scam

- Zowe core component images MUST be scanned with security scanning tool(s) to test against a CVE database and all identified vulnerabilities must be handled in a timely process. Recommended tool(s) are:
  * [docker scan](https://docs.docker.com/engine/scan/)
  * [Anchore Grype](https://github.com/anchore/grype)
  * Any other tools received [Red Hat Vulnerability Scanner Certification](https://www.redhat.com/en/blog/introducing-red-hat-vulnerability-scanner-certification)
- Security scan is recommended for Zowe extension images.

#### License Scan, Notice file and Source Build

- License scan is required for Zowe core component images. Recommended tool(s) are:
  * [Tern](https://github.com/tern-tools/tern)
- A separated source build image is required for Zowe core component images.
- License notice file is recommended for Zowe core component images.
- Above rules are recommended for Zowe extension images.
n
