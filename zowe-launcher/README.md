This program and the accompanying materials are
made available under the terms of the Eclipse Public License v2.0 which accompanies
this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html

SPDX-License-Identifier: EPL-2.0

Copyright Contributors to the Zowe Project.

<h1 align="center">Zowe Launcher</h1>

This is a POC project with the goal to provide an advanced launcher for Zowe components.

## Current features
* Stopping Zowe using the conventional `P` operator command
* Ability to handle modify commands
* Stopping and starting specific Zowe components without restarting the entire Zowe

## Future features
* Issuing WTOs indicating the start and termination of specific components (this should simplify the integration with z/OS automation)
* Passing modify commands to Zowe components
* Clean termination of the components in case if the launcher gets cancelled

## Building

```
cd zowe-launcher
make
```

The launcher binary will be saved into the bin directory.

## Prerequisites

* Zowe 1.11.0

## Deployment

* Specify the Zowe installation and instance directories in `zowe.conf`
* Run `patch-zowe.sh` to apply the require Zowe changes
* Copy the launcher JCL (`samplib/zlaunch`) to your PROCLIB
* Edit the JCL and specify the launcher directory in the WORKDIR variable

## Component configuration

Edit `components.conf` to add and remove components. The configuration consists of key-value pairs, where a key is a component name and a value is the path to the component binary.

## Operating the launcher

* To start the launcher use the `S` operator command:
```
S ZLAUNCH
```
* To stop use the `P` operator command:
```
P ZLAUNCH
```
* To stop a specific component use the following modify command:
```
F ZLAUNCH,APPL=STOP(component_name)
```
* To start a specific component use the following modify command:
```
F ZLAUNCH,APPL=START(component_name)
```
* To list the components use the following modify command:
```
F ZLAUNCH,APPL=DISP
```

## The project should fix the following issues
* https://github.com/zowe/zowe-install-packaging/issues/1137
* https://github.com/zowe/zowe-install-packaging/issues/790
