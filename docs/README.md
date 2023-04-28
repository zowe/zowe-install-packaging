# Zowe-Install-Packaging Docs

This folder and associated documents contains information useful to maintainers of the zowe-install-packaging repository and related Systems Squads activities. 

This is not user-facing documentation.

### Table of contents

- Repository Overview
  - [Structure](./repo/structure.md)
  - [Manifest.json](#manifest-metadata)
  - [Branch Strategy](./repo/branches.md)
  - [Tests](./repo/tests.md)
- [Infrastructure](./infra/infrastructure.md)
- Pipelines and Automation
  - [Build and Test](./pipelines/build_test.md)
  - [Containers](./pipelines/containers.md)
  - [Supply-chain, attributions](./pipelines/supply-chain.md)
  - [Release](./pipelines/release.md)
- Install and Configuration
- Distribution Formats
  - [Pax](./distributions/pax.md)
  - [SMP/e](./distributions/smpe.md)
  - [PSWI](./distributions/zowe_pswi_tech_prev.md)


## Repository Overview

The zowe-install-packaging repository is intended to multiple workflows focused around the packaging and delivery of individual Zowe server-side components, including code focused on improving end-users installation and configuration experiences with the packages created from this repository. Since this repository's scope extends from packaging to configuration and is responsible for aggregating individual server side components, its typical to receive pull requests and code modifications from multiple squads within Zowe. Unlike many of the other repositories in Zowe which are primarily driven by a single squad, the zowe-install-packaging repository is collaboratively maintained by many squads within Zowe. The Zowe Systems Squad is the primary owner and point of contact if you have any questions or issues.

## Manifest Metadata

Zowe's releases are composed of several individual components which are built in other repositories, by other Zowe squads, and in different formats. `manifest.json.template` defines which components are included into official build, where they're located in remote registries, and some general information regarding the current build of Zowe.

The manifest file includes:

- [General Information](#general-information)
- [Build Information](#build-information)
- [Binary Dependencies](#binary-dependencies)
- [Source Dependencies (Provenance)](#source-dependencies)
- [Container Image Dependencies](#image-dependencies)
- [Deprecated Fields](#deprecated-fields)

### General information

These information are represented in these properties: `name`, `version`, `description`, `license` and `homepage`.

### Build information

These information includes details when building the Zowe artifact. During build process, `manifest.json.template` will be converted to `manifest.json` and the template variables like `{BUILD_COMMIT_HASH}` will be filled in with real value. The modified `manifest.json` will be placed into root folder of Zowe build.

Here is an example of build information after build, you can find it in the `manifest.json` file from every Zowe build:

```
  "build": {
    "branch": "staging",
    "number": "202",
    "commitHash": "dad00f0a9c45f34bfbe3ec56a8443f2e818e59f4",
    "timestamp": "1568205429441"
  },
```

The above build information means this Zowe build is from `staging` branch build #202, git commit hash is [dad00f0a9c45f34bfbe3ec56a8443f2e818e59f4](https://github.com/zowe/zowe-install-packaging/commit/dad00f0a9c45f34bfbe3ec56a8443f2e818e59f4). Build time is `1568205429441`, which means `Wed Sep 11 2019 08:37:09 GMT-0400 (Eastern Daylight Time)`.

### Binary Dependencies

`binaryDependencies` section defines how many components will be included into the binary build. Each component has an unique ID, which hints where the pipeline should pick up the component artifact. Also for each the component, it defines which version will be included into the build.

Here is an example of component definition:

```
    "org.zowe.explorer.jobs": {
      "version": "~0.2.8-STAGING",
      "explode": "true"
    }
```

`org.zowe.explorer.jobs` is the component ID, which also tell the pipeline to pick the component from Artifactory path `<repo>/org/zowe/explorer/jobs/`. `version` defines which version we should pick. In this case, we should pick the max version matches `0.2.*-STAGING` and `>= 0.2.8-STAGING`. So version `0.2.10-STAGING` is a good match if it exists.

For details of **how to define a component**, please check examples and explanations from https://zowe.github.io/jenkins-library/jenkins_shared_library/artifact/JFrogArtifactory.html#interpretArtifactDefinition(java.lang.String,%20java.util.Map,%20java.util.Map).

### Source Dependencies

`sourceDependencies` section defines how the component binary matches to the Zowe github repository, branch or tag. It is grouped by `componentGroup`. For example, `Zowe Application Framework` componentGroup includes all repositories related it and listed in `entries` section.

One example component entry looks like:

```
  {
    "repository": "imperative",
    "tag": "v2.4.9"
  }
```

This means the Zowe build is using https://github.com/zowe/imperative repository tag [v2.4.9](https://github.com/zowe/imperative/tree/v2.4.9).

**Please note, this section may not reflect the correct value for non-formal-release.** Only for formal releases, we will update these sections to match the correct repository tags.

To check for each release, what source code from repositories will be used, you can:

- go to https://github.com/zowe/zowe-install-packaging,
- click on [?? releases](https://github.com/zowe/zowe-install-packaging/releases),
- find the release name. For example [v1.4.0](https://github.com/zowe/zowe-install-packaging/releases/tag/v1.4.0),
- click on the tag name on the left. In the above case, it shows [v1.4.0](https://github.com/zowe/zowe-install-packaging/tree/v1.4.0),
- find and check file `manifest.json.template`. In the above case, it links to [v1.4.0/manifest.json.template](https://github.com/zowe/zowe-install-packaging/blob/v1.4.0/manifest.json.template).
- check the `sourceDependencies` section. In the above case, it's line #96.
- In the above example, you will see Zowe release v1.4.0 is using https://github.com/zowe/imperative repository tag [v2.4.9](https://github.com/zowe/imperative/tree/v2.4.9).

### Image Dependencies

### Deprecated Fields

### Branch Strategy

The zowe-install-packaging repository is the convergence point for Zowe's component integrations and release activities and so must be able to support both rapid iteration from multiple component squads testing their latest code and respective integrations, as well as support component and code stability during release windows. Our branching, build, and release strategies are defined to meet those requirements.

- From any `vN.x/master` branch, you can find the most recent **official** build within the Zowe `vN` release line. e.g., official Zowe v2 releases can be found in `v2.x/master`
- The `vN.x/rc` branches are used to create release candidates and stabilize them. It's an intermediate state where we finalize and harden the code to prepare for the coming release. This branch is updated from `vN.x/staging` at regular intervals, and once the Zowe TSC votes to promote a release candidate, this branch will be merged into `vN.x/master` as the latest official release. 
- The `vN.x/staging` branch is the active development branch for the `vN` release line. This branch typically creates stable builds but may occasionally generate an unstable build. Usually, development changes should open Pull Requests against this branch.
- All other branches are considered work-in-progress. We suggest using a naming structure which makes both their intent and ownership clear. e.g., something like `user/[myusername]/[feature-or-effective-change]` or `feat/[group-name]/[feature-description-or-issue-#]`

#### Component Tracking

Pull Requests are always required to make changes to this repository. Generally, pull requests against any `rc` or `master` branch must be approved and merged by a member of the Zowe Systems Squad, while pull requests against `staging` may be approved by other Zowe squads.

### Build Pipeline

Zowe build pipeline has hooked into github repository. Every branch, commit and PR has potential to kick off a new Zowe build. If the build is not automatically started, you can go to Jenkins and start a build job on the appropriated branch or pull request.



### Generate Customized Zowe Build

If your changes are in `zowe-install-packaging`, you may already have a Zowe build if you have a branch. Otherwise you will have one if you create a pull request on your changes.

If your changes are in components, it may depend on how the Zowe build picks your changes:

- If you have released, or have a snapshot build of your component, very likely the change will be picked up by the `staging` branch build. If not, you need to check the `binaryDependencies` section in `manifest.json.template`.
- If your changes is still in a branch of the component repository, you can edit `manifest.json.template` to use the branch build directly like this:

  ```
    "org.zowe.explorer.jobs": {
      "artifact": "lib-snapshot-local/org/zowe/explorer/jobs/0.2.7-MY-BRANCH-BUILD.zip",
      "explode": "true"
    },
  ```

## Automate Install / Uninstall of Zowe with Ansible

Please check details in [playbooks folder](playbooks/README.md).

## Quick Sanity Check on Your Zowe Instance

Please check details in [sanity test folder](tests/sanity/README.md).
