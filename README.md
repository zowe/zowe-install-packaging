# zowe-install-packaging

This repository includes automation, artifacts, and scripts which are used to create the final set of Zowe installable artifacts for the Zowe server side. This repository additionally contains metadata used to track official Zowe releases across multiple build pipelines.

- [Contributing](#contributing)
- [Building](#building)
- [Running Zowe](#running-zowe)
- [Points of Contact](#point-of-contacts)

## Contributing

To contribute to this repository, please follow the [contributing guidelines](./CONTRIBUTING.md).

## Building

Zowe-Install-Packaging is composed of multiple sub-modules and directories which drive the aggregation of individual Zowe components into a final distributable package users can take to install on their mainframe systems. This repository contains pipeline definitions, pipeline implementation details, simple component provenance information, scripts which improve the install and configuration of Zowe, test suites, and more artifacts related to the final package formats. There is no individual build for the entire repository, but instead multiple related builds that require different aspects of the repository. To see more about these builds, check our Github Actions definition [here](./.github/workflows/). To see more about whats in the repository, see [our repository doc](./docs/README.md). To verify code changes, open a PR and request a review from one of the contact points below.

## Running Zowe

For information on running Zowe, see [the Zowe quickstart guide](./ZOWE.md).

### Point of Contacts

For submitting code changes unrelated to a Zowe component update, please contact one of the below:

- Mark Ackert
- OJ Celis
- Sean Grady
- James Struga

For each Zowe component, we have point of contact(s) in case if we want to confirm the versions defined in the `manifest.json.template`. For more information on the `manifest.json`, see the [repo overview](./repos/overview.md):

- API Mediation Layer: Elliot Jalley, Jakub Balhar, Mark Ackert
  * Binary Dependencies
    - org.zowe.apiml.sdk.zowe-install
  * Source Dependencies
    - api-layer
- zLux, ZSS and Cross Memory Server: James Struga
  * Binary Dependencies
    - org.zowe.zlux.sample-angular-app
    - org.zowe.zlux.sample-iframe-app
    - org.zowe.zlux.sample-react-app
    - org.zowe.zlux.tn3270-ng2
    - org.zowe.zlux.vt-ng2
    - org.zowe.zlux.zlux-core
    - org.zowe.zlux.zlux-editor
    - org.zowe.zss
  * Source Dependencies
    - zlux-app-manager
    - zlux-app-server
    - zlux-file-explorer
    - zlux-grid
    - zlux-platform
    - zlux-server-framework
    - zlux-shared
    - zlux-widgets
    - zlux-build
    - zss
    - zowe-common-c
    - tn3270-ng2
    - sample-angular-app
    - sample-iframe-app
    - sample-react-app
    - vt-ng2
    - zlux-editor
- Explorer APIs / UI Plugins: Jordan Cain
  * Binary Dependencies
    - org.zowe.explorer.data.sets
    - org.zowe.explorer.jobs
    - org.zowe.explorer-jes
    - org.zowe.explorer-mvs
    - org.zowe.explorer-uss
  * Source Dependencies
    - data-sets
    - jobs
    - explorer-api-common
    - explorer-jes
    - explorer-mvs
    - explorer-uss
    - orion-editor-component
    - explorer-ui-server
- CLI: Fernando Rijo Cedeno, Mark Ackert
  * Source Dependencies
    - imperative
    - zowe-cli
    - zowe-cli-cics-plugin
    - zowe-cli-db2-plugin
    - perf-timing
    - zowe-cli-mq-plugin
    - zowe-cli-scs-plugin
    - zowe-cli-ftp-plugin
    - zowe-cli-ims-plugin
- Explorer (Visual Studio Code Extension): Fernando Rijo Cedeno, Mark Ackert
  * Source Dependencies
    - vscode-extension-for-zowe
- License: Mark Ackert
  * Binary Dependencies
    - org.zowe.licenses
