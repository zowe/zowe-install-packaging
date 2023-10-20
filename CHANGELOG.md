# Change Log

All notable changes to the Zowe Installer will be documented in this file.
<!--Add the PR or issue number to the entry if available.-->
## `2.13.0`

### New features and enhancements

#### Minor enhancements/defect fixes
- Bugfix: Workflow files in the Zowe PAX are now ASCII-encoded. Fixes [#3591](https://github.com/zowe/zowe-install-packaging/issues/3591).

## `2.12.0`

### New features and enhancements

#### Minor enhancements/defect fixes

## `2.11.0`

### New features and enhancements
- Enhancement: Duplicate log messages into syslog according to "zowe.sysMessages" array [#93](https://github.com/zowe/launcher/pull/93)

#### Minor enhancements/defect fixes
- Bugfix: `zowe-yaml-schema.json` validates unix directory path as `server-common#zowePath`
- Bugfix: Fixed that Zowe would allow newer Java versions to generate PKCS12 keystores that was not compatible with some components. Newer versions of Java by default create PKCS12 keystores that aren't compatible with GSK / SystemSSL which components such as ZSS use, but include flags to restore a compatibility mode, which Zowe now uses. (#3507)

## `2.10.0`

### New features and enhancements
- Enhancement: Added a new zwe "diagnose" command to find help on zowe error messages. (#3455)

#### Minor enhancements/defect fixes
- Enhancement: Check for node v18 which is now supported, but disallow v18.12.1 because it is known not to work for Zowe. (#3485)

## `2.9.0`

### New features and enhancements
- Users who have not set the value of "zowe.useConfimgr" will have the behavior now set to "true" rather than the previous "false". If you wish to use false still, just set "zowe.useConfigmgr=false" explicitly.

## `2.8.0`

### New features and enhancements
- Component installation can now print stdout of install scripts [#3361](https://github.com/zowe/zowe-install-packaging/pull/3361)

#### Minor enhancements/defect fixes
- Bugfix: Component environment variables would not be aliased to the "_configs_" shorthand when the component had a configure script, but not a validate script, and zowe.useConfigmgr was enabled.
- Buffix: When zowe.useConfigmgr=true, component installation would not run the installation script from the component root directory, but instead from the place zwe was executed, causing relative path differences versus zowe.useConfigmgr=false.

## `2.7.0`

### New features and enhancements
- The zowe authorized loadlib now contains a new ZIS plugin as a member named "ZWESISDL". This is the ZIS Dynamic Plugin, and exists for use by other plugins that wish to access zowe-common-c utilities at runtime without needing to statically link them in the other plugin. This plugin must be referenced in the ZWESIP00 parmlib member before use. The samplib for ZWESIP00 now references this "ZWESISDL" member and it is recommended that you update your ZWESIP00 member using the samplib if you need to use this plugin.

#### Minor enhancements/defect fixes
- When zwe components install detects that the given component is already installed, it will suggest you to run zwe components upgrade instead.
- Launcher parameters such as "shareAs" could not be customized globally due to zowe.launcher schema being wrong with some parameters nested inside another.
- Launcher parameters within an individual component were not documented to exist despite the launcher allowing per-component customization.
- Fixed that zwe would fail to recursively make missing directories if the root directory was not readable by the user.
- zwe detects and warns against nodejs lower than version 14 (Due to end of life of v12)
- Tracing and writing to log files would not work for component scripts when zowe.useConfigmgr=true
- Node v18 was installed on marist system and test were made to run with node v18.


## `2.6.0`

#### Minor enhancements/defect fixes
- When a component configure script failed during startup, no warning would be printed. Starting in 2.6, a warning will be printed and there's also an option to prevent Zowe from continuing startup when this failure is seen, by setting `zowe.launchScript.onComponentConfigureFail` to "exit"
- Tar archived components would not be installed when zowe.useConfigmgr=true was set.
- Various bugfixes made for reading and writing of parmlib configuration files when using the PARMLIB() syntax with zwe commands or the ZWESLSTC job.
- Revised help documentation syntax for substitution values to fix auto-documentation, by changing angle brackets to square brackets.

## `2.5.0`

### New features and enhancements
- zwe now has a `zwe config get` and `zwe config validate` command. The get command can be used to get a part of the zowe yaml configuration without needing to read the yaml yourself. `zwe config get` only returns values upon proving the configuration is valid first. `zwe config validate` can be used to perform validation of the zowe configuration files without running any additional actions. This is useful for verifying that a change is valid before starting zowe, for example. 

### New features and enhancements
- A new component management command `zwe components upgrade` allows you to install an already-installed component.
- A new component management command `zwe components uninstall` allows you to remove an installed extension.
- A new component management command `zwe components search` allows you to query for extensions.
- `zwe components` subcommands can now search for, install, and upgrade extensions retrieved via an on-prem or remote package registry. At this time, npm is supported as the registry and package manager technology that `zwe` can use to download content. This is an optional feature and is not enabled by default: it must be configured. View the schema for zowe.yaml to learn more about the "package registry" and "registry handler" technologies to configure for this feature. More information and a recorded demo is available at https://github.com/zowe/zowe-install-packaging/pull/2980

#### Minor enhancements/defect fixes
- Use of DVIPA may cause Zowe to believe a port is not free when it is. Starting in this release, Zowe can narrow its port validation to a specific IP via `zowe.network.vipaIp=some.ip` or bypass the verification via `zowe.network.validatePortFree=false`. Setting this to false will still cause the servers to be unable to connect if the port is not free, but this can be a more accurate and portable setting.
- component configure stages will now have their STDOUT printed when running at the INFO level of zwe verbosity.
- zwe was not guaranteeing that the workspace folder had 770 permission when zowe.useConfigmgr=true was set

## `2.4.0`

### New features and enhancements
- Zowe's 'configmgr' mode is now the default operating mode for installation and configuration when available. To disable this behavior, set `zowe.useConfigmgr` to `false` in your `zowe.yaml`.  
  * Zowe containerization does not yet support 'configmgr' mode. If you have an existing Kubernetes deployment of Zowe and are upgrading to 2.4.0, you should set `zowe.useConfigmgr` to `false` in your zowe YAML configmap. This is set by default for new Kubernetes deployments.
- zwe can now validate component configuration through use of configmgr and json-schema. If a component does not have a schema, a warning will be printed. Due to schemas being required since 2.0, this behavior may change in a later version.
- Components can now provide an array of schema files rather than just one. This allows for better re-use and organization.
- Zowe can now start using zowe.yaml loaded from PARMLIB members if you want, when using the STC startup as well as the `zwe start`, `zwe stop`, and `zwe components` commands. These can be specified in --config / CONFIG input as PARMLIB() entries. For example, zwe start --config FILE(/my/customizations.yaml):PARMLIB(TEAM.CUSTOM.ZOWE(YAML)):PARMLIB(ORG.CUSTOM.ZOWE(YAML)):FILE(/zowe/defaults.yaml) ... Note when using PARMLIB, every member name must be the same.

#### Minor enhancements/defect fixes
- zowe.environments was not applied when zowe.useConfigmgr=true was set

## `2.3.0`

### New features and enhancements
- A new dataset, SZWELOAD was added. It contains versions of configmgr named `ZWECFG31`, `ZWECFG64`, and `ZWERXCFG` which can be used to invoke configmgr from within a rexx program. The expected use case is to simplify how complex JCL gets configuration info about Zowe.
- Zowe can now start in a mode called 'configmgr' mode. You can enable this in certain `zwe` commands by adding `--configmgr`. Not all commands support this yet, more will over time. For now, you can use it in `zwe start`, `zwe stop`, and `zwe components`. This mode is generally significantly faster to start up Zowe, but also enforces validation of the zowe.yaml configuration against the zowe.yaml schema files (found in `/schemas`).
- Zowe can now start using multiple zowe.yaml files when using 'configmgr' mode. This works for the STC startup as well as the `zwe start`, `zwe stop`, and `zwe components` commands. Each file must follow the same zowe.yaml schema as before, but in the list of files, properties found in a file to the right will be overridden by the file to the left. Through this, you can separate portions of Zowe configuration any way you want. To use multiple files, change your existing --config / CONFIG input to instead be a list of FILE() entries which are colon ':' separated. For example, zwe start --config FILE(/my/customizations.yaml):FILE(/zowe/defaults.yaml)
- Zowe server YAML files can now have templates within them when using 'configmgr' mode. When the value of any attribute contains `${{ }}`, the content within the brackets will be replaced with whatever the template evaluates to. The entries are processed as ECMAScript2020-compatible javascript assignments. You can for example, set one property to the value of another, such as having `parmlib: ${{ zowe.setup.dataset.prefix }}.MYPARM` rather than needing to type the prefix explicitly. You can also use this to set conditionals. For examples, please check the ZSS default yaml file: https://github.com/zowe/zss/blob/013d11d700003483fde38e1df0a373bb5bd4ef8c/defaults.yaml

#### Minor enhancements/defect fixes
- Schema pattern for semver range has been simplified as it was not compiling in configmgr
- When `zwe components install` could not find or set the PC bit of a ZSS plugin, it would print out an example command for fixing the issue. Now, it shows the exact command you could execute to fix the PC bit problem.

## `2.2.0`

### New features and enhancements
- A new command, `configmgr` is now present. It can load, validate, and report on the zowe configuration file.

## `2.0.0`

### New features and enhancements
- A new command, 'zwe' is now present which can be used to do various zowe server commands like install and run. To learn more, try `zwe --help` or find the same help on the zowe documentation website.

### Breaking changes
- Zowe no longer uses instance.env, but instead uses a zowe.yaml file for configuration
- Zowe no longer uses an instance directory, but instead uses the zowe.yaml to find all zowe directories, and the zwe command to handle most zowe management operations.

## `1.25.0`

### New features and enhancements
- app-server's uninstall-app.sh script is now available in the instance bin folder.
- zss's zis-plugin-install.sh script is now available in the instance bin/utils folder.

## `1.24.0`

### New features and enhancements
- A new dataset is created during instance creation. The dataset is to be used for holding ZIS plugins, as an alternative to putting the plugins inside of the ZIS loadlib which is still the default.
- New instance parameters describing ZIS are available and automatically recorded in instance.env if a new install is done via a convenience build. These parameters can be used in future automation of detecting ZIS and installing ZIS plugins
- New instance creation parameters -d or -l, -p, and -z are now available in the instance creation script for manually specifying the new ZIS parameters. 

## `1.20.0`

### New features and enhancements
- server-bundle docker image has been optimized to greatly reduce the size without impacting the content and usability
- server-bundle docker image now runs zowe under the user "zowe", and the default mount locations of instance, keystore, and plugins directories is now within /home/zowe as a result

## `1.17.0`

### New features and enhancements
- You can now start ZSS independent from the Zowe Application Framework server by specifying the `LAUNCH_COMPONENT_GROUP "ZSS"`. If `DESKTOP` is specified instead of `ZSS`, ZSS will still be included as a prerequisite to the Application Framework server. [#1632](https://github.com/zowe/zowe-install-packaging/pull/1632)
- Zowe instance configuration script (`zowe-configure-instance.sh`) can now skip checking for Node.js by passing in the `-s` flag since Node.js may not be needed if the components to be launched don't require it. [#1677](https://github.com/zowe/zowe-install-packaging/pull/1677)
- The `run-zowe.sh` script can also skip the checking for Node.js by setting the environment variable `SKIP_NODE=1` for the cases where the components to be launched don't require Node.js.
- Exported the `EXTERNAL_CERTIFICATE_AUTHORITIES` variable to the `zowe-certificates.env` file such that it may be used by the Application Framework server. [#1742](https://github.com/zowe/zowe-install-packaging/pull/1742)

## `1.16.0`

### New features and enhancements
- Moved explorer-ui-server out of explorers into new `shared` folder under Zowe Runtime Directory. It involved following PRs (https://github.com/zowe/zowe-install-packaging/pull/1545), (https://github.com/zowe/explorer-jes/pull/207), (https://github.com/zowe/explorer-ui-server/pull/37). Thanks @stevenhorsman, @nakulmanchanda, @jackjia-ibm
- Created `zowe-setup-keyring-certificates.env` and removed the overloaded properties from `zowe-setup-certificates.env` to try and clarify the user experience when setting up certificates in the keyring and USS keystore modes. [#1603](https://github.com/zowe/zowe-install-packaging/issues/1603)


## `1.14.0`

### New features and enhancements
- Allow the user to verify the authenticity of a Zowe driver. The script `zowe-verify-authenticity.sh` will check that a Zowe `ROOT_DIR` for an installed release matches the contents for when that release was created, which assists with support and troubleshooting. To verify pre-1.14 releases, the script and its associated code are available [separately](https://github.com/zowe/zowe-install-packaging/blob/staging/files/fingerprint.pax) (see [#1552](https://github.com/zowe/zowe-install-packaging/issues/1552)). For more information, see the new topic [Verify Zowe Runtime Directory](https://docs.zowe.org/stable/troubleshoot/verify-fingerprint.html) that describes the operation of the script. 
- Allow multiple domains (names/IP Addresses) when generating certificates. This also includes SMP/E `HOLDDATA` for the affected function `Zowe Configuration`. [#1511](https://github.com/zowe/zowe-install-packaging/issues/1511)
- Included z/OSMF workflows for Zowe z/OS configuration. [#1527](https://github.com/zowe/zowe-install-packaging/issues/1527)
- Added warning if `ZWESVSTC` runs under user ID `IZUSVR`. [#1534](https://github.com/zowe/zowe-install-packaging/issues/1534)
- [Docs] Changed the documentation to say that SZWEAUTH PDSE load library members should not be copied elsewhere, but instead that the original installation target SZWEAUTH PDSE should be APF-authorized and used as the runtime load library.  This also includes SMP/E `HOLDDATA` for the affected function `STC JCL` as well as changes to topics [Installing and configuring the Zowe cross memory server (ZWESISTC)](https://docs.zowe.org/stable/user-guide/configure-xmem-server.html) and [Installing and starting the Zowe started task (ZWESVSTC)](https://docs.zowe.org/stable/user-guide/configure-zowe-server.html).  
- [Docs] Added a new topic [Installing and configuring Zowe z/OS components using scripts](https://docs.zowe.org/stable/user-guide/scripted-configure-server.html).

## `1.13.0`

#### Minor enhancements/defect fixes
- Updated zowe-configure-instance upgrade to update ROOT_DIR [#1414](https://github.com/zowe/zowe-install-packaging/pull/1414)
- Update port validation logic to reduce false negatives [#1399](https://github.com/zowe/zowe-install-packaging/pull/1399)
- Update install and configure to tolerate ZERT Network Analyzer better [#1124](https://github.com/zowe/zowe-install-packaging/pull/1124)



## `1.12.0`

- Edit default plugin references to point to $ROOT_DIR env var

2020-05-08 Timothy Gerstel <tgerstel@rocketsoftware.com>

  - Set up SSO in a standard install of Zowe via new environment variables set
in zowe-setup-certificates.env

  - Automate conversion of APIML public key and storage within PKCS#11 token

- When the hostname cannot be resolved use the IP address instead.  This covers the scenario when the USS `hostname` command returned a system name that wasn't externally addressable, such as `S0W1.DAL-EBIS.IHOST.COM` which occurs on an image created from the z/OS Application Developers Controlled Distribution (ADCD).
- Separate zss component from app-server component
