# Zowe-Install-Packaging Docs

This folder and associated documents contains information useful to maintainers of the zowe-install-packaging repository and related Systems Squads activities. 

This is not user-facing documentation.

### Table of contents

- Repository Overview
  - [Branch Strategy](./repo/branches.md)
  - [Structure](./repo/structure.md)
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

The zowe-install-packaging repository serves many adjacent scenarios focused around the packaging and delivery of multiple individual Zowe server-side components, including code focused on improving end-users installation and configuration experiences with the packages created from this repository. Since this repository's scope extends from packaging to configuration and is responsible for aggregating individual server side components, its typical to receive pull requests and code modifications from multiple squads within Zowe. Unlike many of the other repositories in Zowe which are primarily driven by a single squad, the zowe-install-packaging repository is collaboratively maintained by many squads within Zowe. The Zowe Systems Squad is the primary owner and point of contact if you have any questions or issues.


### Branch Strategy

The zowe-install-packaging repository is the convergence point for Zowe's component integrations and release activities and so must be able to support both rapid iteration from multiple component squads testing their latest code and respective integrations, as well as support component and code stability during release windows. Our branching, build, and release strategies are defined to meet those requirements.

- From any `vN.x/master` branch, you can find the most recent **official** build within the Zowe `vN` release line. e.g., official Zowe v2 releases can be found in `v2.x/master`
- The `vN.x/rc` branches are used to create release candidates and stabilize them. It's an intermediate state where we finalize and harden the code to prepare for the coming release. This branch is updated from `vN.x/staging` at regular intervals, and once the Zowe TSC votes to promote a release candidate, this branch will be merged into `vN.x/master` as the latest official release. 
- The `vN.x/staging` branch is the active development branch for the `vN` release line. This branch typically creates stable builds but may occasionally generate an unstable build. Usually, development changes should open Pull Requests against this branch.
- All other branches are considered work-in-progress. We suggest using a naming structure which makes both their intent and ownership clear. e.g., something like `user/[myusername]/[feature-or-effective-change]` or `feat/[group-name]/[feature-description-or-issue-#]`

#### Component Tracking

Pull Requests are always required to make changes to this repository. Generally, pull requests against any `rc` or `master` branch must be approved and merged by a member of the Zowe Systems Squad, while pull requests against `staging` may be approved by other Zowe squads.
