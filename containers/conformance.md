# Zowe Conformance Criteria Related to Containerization

**DRAFT**

These conformance criteria are applicable for all Zowe components intent to run in containerization environment. The containerization environment could be Kubernetes or OpenShift running on Linux or Linux on Z. This may also apply to `docker-compose` running on Linux, Windows, Mac OS, or zCX.

## Image

In general, the image should follow [Best practices for writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/). Below requirements are in addition to the list.

### Base Image

You are free to choose base image based on your requirements.

For Zowe core components, here are our recommendations:

- [Red Hat Universal Base Image 8 Minimal](https://developers.redhat.com/articles/ubi-faq?redirect_fragment=resources#ubi_details)
- [Ubuntu](https://hub.docker.com/_/ubuntu)

The image should be as small as possible.

### Multi-CPU Architecture

- Zowe core components must release images based on both `amd64` and `s390x` CPU architecture.
- Zowe core component images must use multiple manifests to define the image supports multiple CPU architecture.
- CPU architecture like `amd64` and `s390x` must NOT appear in released component image tag.

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

Image tag can be a combination of these information in this format: `<version>-<linux-distro>[-sources][.<customize-build>]`.

- **version**: it must follow [semantic versioning](https://semver.org/) or partial semantic versioning with major or major + minor. It may also be `latest` or `lts`. For example, `1`, `1.23`, `1.23.0`, `lts`, `latest`, etc.
- **linux-distro**: for example, `ubi`, `ubuntu`, etc.
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
- 1.23.0-ubuntu-sources
- 1.23.0-ubi
- 1.23.0-ubi-sources
- 1.23.0-alpine.pr-1234
- 1.23.0-ubi.users-john-test1

### Files and Directories

This is required folder structure for all Zowe components:

```
/licenses
/app
  +- README.md
```

- `/licenses` folder holds all license related files. It should include at least the license information for current application. It's recommended to include license notice file of all pedigree dependencies. All licenses files must be in UTF-8 encoding.
- `/app/README.md` provides information about the application for end-user.

These file(s) and folder(s) are recommended:

```
/app
  +- manifest.json or manifest.yaml
  +- /bin/<lifecycle-scripts>
  +- <other-application-files>
```

- `/app/manifest.(json|yaml)` is recommended for Zowe component. The format of the file is defined at [Zowe component manifest](https://docs.zowe.org/stable/extend/packaging-zos-extensions/#zowe-component-manifest). Component must use same manifest file when it's running on z/OS.
- `/app/bin/<lifecycle-scripts>` should remain same as what it is running on z/OS. Component must use same lifecycle scripts when it's running on z/OS.

### Environment Variable(s)

These environment variable(s) must be set as a fixed value in the image:

- `ZOWE_COMPONENT_ID`: this is the Zowe component ID for current image. For example: `ENV ZOWE_COMPONENT_ID=gateway`.

### User `zowe`

In the Dockerfile, a `zowe` user and group must be created. Example command `RUN groupadd -r zowe && useradd --no-log-init -r -g zowe zowe`.

`USER zowe` must be specified before the first `CMD` or `ENTRYPOINT`.

### Multi-Stage Build

Multi-stage build is recommended to keep image small and concise. Learn more from [Use multi-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/).

## Runtime

This section is mainly for information. No actions required for components except where it's specified explicitly.

Below sections are mainly targeting Kubernetes or OpenShift environment. Starting Zowe containers in Docker environment with `docker-compose` is in plan and may change some of the requirements.

### General rules

**Components MUST:**

- NOT be started as root user in the container.
- listen on ONLY one port in the container.
- NOT rely on hardcoded directory names like `/app`.
- be cloud vendor neutral and must NOT rely on features provided by specific cloud vendor.
- NOT rely on host information such as `hostIP`, `hostPort`, `hostPath`, `hostNetwork`, `hostPID` and `hostIPC`.
- MUST accept either `instance.env` or `zowe.yaml` as configuration file, same as running on z/OS.

### Files and Directories

In runtime, the Zowe content are organized in this structure:

```
/zowe
  +- /runtime
  +- /extension
    +- /<component-id>
  +- /instance
    +- instance.env or zowe.yaml
    +- /workspace
  +- /keystore
    +- zowe-certificates.env
```

- `/zowe/runtime` is a shared volume initialized by `zowe-launch-scripts` container.
- `/zowe/extension/<component-id>` is a symbolic link to `/app` directory. `<component-id>` is `ZOWE_COMPONENT_ID` defined in `ENV`.
- `/zowe/instance/(instance.env|zowe.yaml)` is Zowe configuration file and MUST be mounted from ConfigMap.
- `/zowe/keystore/zowe-certificates.env` is optional if the user is using `instance.env`. If this configuration exists, it MUST be mounted from ConfigMap.
- Any confidential environment variables, for example, redis password, in `instance.env` or `zowe.yaml` should be extracted and stored as Secrets. These configurations must be imported back as environment variables.

### ConfigMap and Secrets

- `instance.env` or `zowe.yaml` must be stored in ConfigMap and be mounted under `/zowe/instance` directory.
- If the user is using `instance.env`, content of `<keystore>/zowe-certificates.env` must also be stored in ConfigMap and be mounted to `/zowe/keystore`.
- All certificates must be stored in Secrets. Those files will be mounted under `/zowe/keystore` directory.
- Secrets must be defined manually by system administrator. Zowe Helm Chart and Zowe Operator does NOT define content of Secrets.

### `zowe-launch-component` Image and initContainers

- `zowe-launch-component` image contains necessary scripts to start Zowe component in Zowe context.
- This image has a `/zowe` directory and it will be shared and mounted to all Zowe component containers as `/zowe/runtime`.
- In Kubernetes and OpenShift environment, this step is defined with [`initContainers` specification](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/).

### Zowe Workspace Directory

- Zowe workspace directory `/zowe/instance/workspace` will be defined a persistent volume.
- Components writing to this directory should be aware of the potential conflicts of same-time writing by multiple instances of same component.
- Components writing to this directory should NOT write container specific information to this directory which may potentially overwritten by another container.

### Command Override

- Component `CMD` and `ENTRYPOINT` will be overwritten with Zowe launch script to start it in Zowe context.

### Persistent Volume(s)

- These persistent volume(s) MUST be created:
  * `zowe-workspace` mounted to `/zowe/instance/workspace`.
- The system administrator MUST define the persistent volume manually. Zowe Helm Chart and Zowe Operator does NOT create consistent volume.

## CI/CD

### Build, Test and Release

- Zowe core component and extension images MUST be built, test and released on their own cadence.
- The component CI/CD pipeline MUST NOT rely on Zowe level CI/CD pipeline and Zowe release schedule.
- Zowe core component images must be tested. This including starting the component and verify the runtime container works as expected.
- ??? Testing in a Kubernetes/OpenShift environment with multiple instances are recommended.
- It's recommended to build snapshot images before release. Zowe core components MUST publish snapshot images to `zowe-docker-snapshot.jfrog.io` registry with proper [tags](#tag).
- Zowe core component images MUST be released before Zowe release.
- Zowe core components MUST publish release images to `zowe-docker-release.jfrog.io` registry.
- Release image MUST also update relevant major/minor version tags and `latest` tag. For example, when component release `1.2.3` image, the component CI/CD pipeline MUST also tag the image as `1.2`, `1` and `latest`. Update `lts` tag when it's applicable.

### Image Scan

#### Security Scam

- Zowe core component images MUST be scanned with security scanning tool(s) to test against CVE database and all identified vulnerabilities must be handled in a timely process. Recommended tool(s) are:
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
