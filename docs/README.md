# Zowe-Install-Packaging Docs

This folder and associated documents contains information useful to maintainers of the zowe-install-packaging repository.

This is not user-facing documentation.

### Table of contents

- [Repository Overview](#repository-overview)
  - [Structure](#structure)
  - [Manifest.json](#manifest-metadata)
  - [Branch Strategy](#branch-strategy)
  - [Tests](#testing)
- Infrastructure, Pipelines and Automation
  - [Build and Test](./pipelines/build_test.md)
  - [Containers](./pipelines/containers.md)
  - [Supply-chain, attributions](./pipelines/supply-chain.md)
  - [Release](./pipelines/release.md)
- Distribution Formats
  - [Pax](./distributions/pax.md)
  - [SMP/e](./distributions/smpe.md)
  - [PSWI](./distributions/zowe_pswi_tech_prev.md)
- [Additional Resources](#additional-resources)
  - [Repository Index](#repository-index)


## Repository Overview

The zowe-install-packaging repository contains multiple technologies and workflows focused around the packaging, delivery, installation and configuration of Zowe server-side components. Since this repository's scope reaches from simply collecting other Zowe server components ([manifest](../manifest.json.template)) to configuration via USS CLI command tooling ([zwe](../bin/zwe)), it's typical to receive pull requests and code modifications from multiple squads within Zowe. Unlike many of the other repositories in Zowe which are primarily driven by a single squad, the zowe-install-packaging repository is collaboratively maintained. The Zowe Systems Squad is the primary administrator and point of contact if you have any questions or issues.

### Structure

This repository contains a mix of packaging/install/configuration, e2e testing, and automation materials. The [repository index](#repository-index) gives a discrete view of this repository's contents, but the contents can be organized roughly into:

* Packaging automation and tools. The `.pax`, `containers`, `files`, `pswi`, `smpe`, and `workflows` directories all cover different aspects of packaging, covered later under [Distribution Formats](#distribution-formats).
* End-user install and configuration tooling. The `bin` (a.k.a. zwe command-line tool), `schemas`, and `workflows` folders all represent tooling intended for use by end-users during their install and configuration of Zowe. This will be covered under [Install and Configuration](#install-and-configuration).
* Zowe Build, Test, and other Automation. The `.dependency`, `.github`, `build`, `playbooks`, `signing_keys`, `tests` folders and `manifest.json.template` file are all part of Zowe pipelines. This will be covered under [Infrastructure, Pipelines, and Automation](#infrastructure-pipelines-automation).


### Manifest Metadata

The manifest is a critical point of Zowe's build and release process. Zowe is composed of individual components which are built in other repositories, by other Zowe squads, in different languages, with different binary formats. `manifest.json.template` is a specification that defines which components are included in an official build, where said components located in remote registries, and some general information regarding the current build of Zowe.

The manifest file covers:

- [General Information](#general-information)
- [Build Information](#build-information)
- [Binary Dependencies](#binary-dependencies)
- [Source Dependencies (Provenance)](#source-dependencies)
- [Container Image Dependencies](#image-dependencies)
- [Deprecated Fields](#deprecated-fields)

#### General information

This section consists of these properties: `name`, `version`, `description`, `license` and `homepage`.

#### Build information

This `build` section includes details when building the Zowe artifact. During the build process, `manifest.json.template` will be converted to `manifest.json` and template variables (e.g. `{BUILD_COMMIT_HASH}`) will be populated with real values. The modified `manifest.json` will then be placed into root folder of Zowe build and picked up by downstream automation.

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

#### Binary Dependencies

The `binaryDependencies` section defines which components will be included into the binary build. Each component has an unique ID, which hints where the pipeline should pick up the component artifact. Also for each the component, it defines which version will be included into the build. The version follows the Artifactory file spec format for resolving special characters, such as wildcards.

Here is an example of component definition:

```
    "org.zowe.explorer.jobs": {
      "version": "~0.2.8-STAGING",
      "explode": "true"
    }
```

`org.zowe.explorer.jobs` is the component ID, which also tell the pipeline to pick the component from Artifactory path `<repo>/org/zowe/explorer/jobs/`. `version` defines which version we should pick. In this case, we should pick the max version matches `0.2.*-STAGING` and `>= 0.2.8-STAGING`. So version `0.2.10-STAGING` is a good match if it exists.

For details of **how to define a component**, please check examples and explanations from https://zowe.github.io/jenkins-library/jenkins_shared_library/artifact/JFrogArtifactory.html#interpretArtifactDefinition(java.lang.String,%20java.util.Map,%20java.util.Map).

#### Source Dependencies

The `sourceDependencies` section defines how the component binary matches to the Zowe github repository, branch or tag. Matching repositories are not automatically validated, so squads must keep `sourceDependencies` up-to-date to reflect the component binary matches. The `sourceDependencies` section is grouped by `componentGroup` to logically connect source repositories into coarser components. For example, `Zowe Application Framework` componentGroup includes all repositories related it and listed in `entries` section.

One example component entry looks like:

```
  {
    "repository": "imperative",
    "tag": "v2.4.9"
  }
```

This means the Zowe build is using https://github.com/zowe/imperative repository tag [v2.4.9](https://github.com/zowe/imperative/tree/v2.4.9).

**Please note, this section may not reflect the correct value for nightly or informal releases.** Only for formal releases, we will update these sections to match the correct repository tags.

To check for each release, what source code from repositories will be used, you can:

- go to https://github.com/zowe/zowe-install-packaging,
- click on [?? releases](https://github.com/zowe/zowe-install-packaging/releases),
- find the release name. For example [v1.4.0](https://github.com/zowe/zowe-install-packaging/releases/tag/v1.4.0),
- click on the tag name on the left. In the above case, it shows [v1.4.0](https://github.com/zowe/zowe-install-packaging/tree/v1.4.0),
- find and check file `manifest.json.template`. In the above case, it links to [v1.4.0/manifest.json.template](https://github.com/zowe/zowe-install-packaging/blob/v1.4.0/manifest.json.template).
- check the `sourceDependencies` section. In the above case, it's line #96.
- In the above example, you will see Zowe release v1.4.0 is using https://github.com/zowe/imperative repository tag [v2.4.9](https://github.com/zowe/imperative/tree/v2.4.9).

#### Image Dependencies

The `imageDependencies` section tracks the container artifacts used as part of distribution of Zowe for Kubernetes. The sources for the container builds are part of this repository, under the [containers](#containers) section. One image entry looks like:

```
    "base": {
        "registry": "zowe-docker-release.jfrog.io",
        "name": "ompzowe/base",
        "tag" : "2.0-ubuntu"
    }
```

#### Deprecated Fields

The following fields are deprecated in the manifest file, and not used at any point by downstream automation or end-users.

- `dependencyDecisions` was an attempt to track dependency status for all of Zowe represented in the manifest; deprecated in favor of other more popular scanning tools.
```
  "dependencyDecisions": {
    "rel": ".dependency/doc/dependency_decisions.yml"
  }
```

### Branch Strategy

The zowe-install-packaging repository is the convergence point for Zowe's component integrations and release activities and so must be able to support both rapid iteration from multiple component squads testing their latest code and respective integrations, as well as support component and code stability during release windows. Our branching, build, and release strategies are defined to meet those requirements.

- The `vN.x/staging` branch is the active development branch for the `vN` release line, and creates builds on a nightly basis. This branch typically creates stable builds but may occasionally generate an unstable build. By default, all development changes should be opened as Pull Requests against this branch.
- The `vN.x/rc` branches are used to create release candidates and stabilize them. It's an intermediate state where we finalize and harden the code to prepare for the coming release. This branch is updated from `vN.x/staging` in preparation for a release and further updated in response to feedback on generated release candidates. Once the Zowe TSC votes to promote a release candidate, this branch will be merged into `vN.x/master` as the latest official release. 
- From any `vN.x/master` branch, you can find the most recent **official** build within the Zowe `vN` release line. e.g., official Zowe v2 releases can be found in `v2.x/master`. Every official build also generates a tag in the `zowe-install-packaging` repository. When an official release is produced, `vN.x/master` is merged back into `vN.x/staging` to ensure capture of any changes which went into `vN.x/rc`.
- All other branches are considered work-in-progress. We suggest using a naming structure which makes both their intent and ownership clear. e.g., something like `user/[myusername]/[feature-or-effective-change]` or `feat/[group-name]/[feature-description-or-issue-#]`, but we don't require any particular structure.


### Testing

Automated e2e tests are driven from the [./tests](../tests) folder in the repository, which contains two testing suites - installation and sanity - each with multiple test cases included. In general, individual installation test cases require the most time to complete and sanity tests are always run after an installation test case within our automation. Most install test cases are pass-throughs which invoke ansible playbooks to deploy Zowe onto a target backend system with a few pre-configured ansible variables. The ansible playbooks can be found in the [./playbooks](../playbooks/) directory and detailed documentation can be found [in the playbooks README](../playbooks/README.md).

### Automation 

Zowe's Automation runs using Github Actions, and leverages functionality present in the [zowe-actions github actions repo](https://github.com/zowe-actions/shared-actions). Important functionality from that repo includes the capability to transfer of files to a mainframe backend in either binary or ASCII mode, as well as build scripts which are executed on the remote system. The actions relies on a set of scripts defined in a `.pax` folder within the repository, which executes a series of scripts in order:

1. `prepare-workspace.sh` - Script run on the build machine (Github Actions), which sets up the local filesystem to transfer files to the backend machine. 
2. `pre-packaging.sh` - Script run on the backend machine before the pax is assembled.
3. `post-packaging.sh` - Script run on the backend machine after the pax is asssembled.
4. `catchall-packaging.sh` - Script run on the build machine after all other actions. Always runs, even if an earlier script failed.

The rest of Zowe's automation is triggered as part of github actions, and is defined under the [.github](../.github/workflows/) folder. See each individual workflow for more information.


### Packaging, Install, Configuration







#### Component Tracking

Pull Requests are always required to make changes to this repository. Generally, pull requests against any `rc` or `master` branch must be approved and merged by a member of the Zowe Systems Squad, while pull requests against `staging` may be approved by other Zowe squads.


### Creating Custom Zowe Build

If your changes are in `zowe-install-packaging`, you can create a custom zowe build by either manually triggering a `Zowe Build and Packaging` github workflow using your branch, or by opening a pull request which will automatically start a Zowe build.

If your changes are in components represented by the [Zowe Manifest](#manifest-metadata), your options depend on how the Zowe build picks up your changes:

- If you released a snapshot build of your component, very likely the change will be picked up by the `vx.y/staging` branch build. If not, review the `binaryDependencies` section in `manifest.json.template` [file specification](#binary-dependencies).
- If your changes are still in a branch of a component repository, you should create a new branch in `zowe-install-packaging` where you edit the `manifest.json.template` file directly to use your component's branch build. 

```
  "org.zowe.explorer.jobs": {
    "artifact": "lib-snapshot-local/org/zowe/explorer/jobs/0.2.7-MY-BRANCH-BUILD.zip",
    "explode": "true"
  },
```

### Automate Install / Uninstall of Zowe with Ansible

Please check details in [playbooks folder](playbooks/README.md).

### Quick Sanity Check on Your Zowe Instance

Please check details in [sanity test folder](tests/sanity/README.md).


## PSWI

## z/OSMF Portable Software Instance For Zowe z/OS Components - Technology Preview

The Zowe z/OSMF Portable Instance - Technology Preview (Zowe PSWI) is the new way of Zowe z/OS components distribution.

## Version

The Zowe PSWI was build on top of SMP/E data sets of Zowe version 1.24. 

## Prerequisities

To be able to use the Zowe PSWI, you need to fulfill a few prerequisites: 
- The current version of the Zowe PSWI was built for the z/OSMF 2.3 and higher. The z/OSMF 2.2 and lower is not supported.
- The user ID you are using for the Zowe PSWI deployment must have READ access to the System Authorization Facility (SAF) resource that protects the Zowe data sets that are produced during the creation of the Zowe PSWI. That is, your user ID requires READ access to data set names with **ZWE** HLQ. Please note, that the prefix is subject to change as the current Zowe PSWI is a technology preview.
- The Zowe PSWI package has about 1.2 GB, please make sure you have enough space available on your system.

## Installation

As the Zowe PSWI is a technology preview, the official Zowe documentation is still in progress. You can reffer to IBM's [documentation](https://www.ibm.com/docs/en/zos/2.4.0?topic=zosmf-portable-software-instances-page) covering Portable Software Instances related tasks. Later, there should be available a blog covering the Zowe PSWI installation process.

## Known Issues and Troubleshooting

- It is not a real issue, but it is worth to mention it. You need to make sure, that in the sysplex environment you have defined a SYSAFF variable in the job header with proper value. Otherwise, deployment jobs might be submitted on the wrong system.
- If you have never used workflows in the z/OSMF, you should configure your job statement for workflows engine. For more details please refer to the IBM's [documentation](https://www.ibm.com/docs/en/zos/2.4.0?topic=task-customizing-job-statement-workflows-your-system).

## Additional Resources

If you would like to read more about Zowe Portable Software Instance, please wait for a while for a blog post that will be released soon. A link will be updated here.

### Repository Index

| Folder or Key File | Description |  
| ----- | ----- | ----- |
| .dependency/  | Produces `zwe` documentation and `zowe-sources.zip` | 
| .github/ | [Automation](#automation) | 
| .pax/ | [Automation](#automation) |
| bin/ | [zwe](../bin/README.md) |
| build/ | [zwe config manager tests](https://github.com/zowe/zowe-common-c/blob/v2.x/staging/Configuration.md) | 
| containers/ | [Zowe Container Distribution](../containers/conformance.md) |
| dco_signoffs/ | Manual DCO Signoffs missing on commits | 
| docs/ | Internal doc on this repository | 
| files/ | Static files included in Zowe PAX, as-is. |
| playbooks/ | [Ansible Playbooks for running install and test](../playbooks/README.md) |
| pswi/ | [Zowe PSWI Build Scripts](../pswi/) |
| schemas/ | [Zowe Configuration YAML Schema](../schemas/server-common.json) |
| signing_keys/ | GPG Keys used to sign Zowe release | 
| smpe/ | [Zowe SMP/e Distribution](./broken_link) | 
| tests/ | [Testing](#testing) | 
| workflows/ | [Zowe Configuration Workflows](./broken_link) | 
| example-zowe.yaml | [Zowe Configuration](./broken_link) |
| manifest.json.template | [Manifest](#manifest-metadata) | 
