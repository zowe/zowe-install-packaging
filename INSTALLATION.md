# Installing Zowe Server Components on z/OS

Within the Zowe project, there exists several components for both client and server, z/OS and PC.
Among them are the Zowe servers; Software that is run usually on z/OS, though some of these servers may also be capable of running in linux environment such as in containers.

This document covers installation and configuration of Zowe's core server components on z/OS.

Table of contents:

1. [Concepts](#concepts)
    1. [Installation Concepts](#installation-concepts)
    2. [Configuration Concepts](#configuration-concepts)
2. [Distribution](#distribution)
3. [Installation of Runtime](#installation-of-runtime)
    1. [SMPE or PSWI](#smpe-or-pswi)
    2. [PAX](#pax)
4. [Configuration of Instance](#configuration-of-instance)
    1. [Configuration by JCL](#configuration-by-jcl)
        1. [Core Tasks](#core-tasks)
        2. [Keyring Tasks](#keyring-tasks)
        3. [(Optional) Caching Service VSAM Task](#optional-caching-service-vsam-task)
    3. [Configuration by zwe](#configuration-by-zwe)
        1. [Keystore or Keyring Configuration](#keystore-or-keyring-configuration)
        2. [(Optional) Caching Service VSAM Configuration](#optional-caching-service-vsam-configuration)
5. [References](#references)
   

## Concepts

Familiarize yourself with these core concepts of the Zowe servers, which are referenced during installation and configuration.

### Installation Concepts
Runtime: The read-only content that comprises a version of Zowe.

Instance: A collection of configuration and persistent data for Zowe that uses a particular Runtime.

HA Instance: An optional subset of an Instance which varies its configuration for redundant copies of Zowe components across one or more LPARs for high avilability and fault tolerance.

Component: A unit of software that is managed by Zowe's launcher and has a folder structure that allows Zowe's tools to manage it. Components may contain a webserver or an extension to another component.

Extension: A component which is not part of the Zowe core server Components. This could be an extension from the Zowe project, or from a 3rd party. Extensions do not exist in the Runtime directory. They are instead linked to Zowe via the Extension directory.

Keystore: Zowe has several HTTPS servers which require certificates to function. You can store these certificates in a Keyring, or in a ZFS Keystore directory in the form of PKCS12 files.

### Configuration Concepts
Zowe YAML File: Each Instance is configured by a YAML document composed of one or more unix file or PDSE member. This can be as simple as a "zowe.yaml" unix file, or ZWEYAML parmlib member, or advanced configuration can ba accomplished by splitting configuration across multiple such files. This allows for defaults and customizations, splitting the configuration by administrative duty, or even splitting the configuration by core configuration versus extension configuration. 

Schema: The YAML file is backed by a Schema, found within `runtimeDirectory/schemas`. Whenever Zowe starts up, or when most `zwe` commands are used, Zowe will check that the YAML file is valid before executing the requested operation, to reduce chance of misconfiguration. The schema also details advanced configuration parameters that may not be needed in basic installs.

Configuration Templates: Each YAML file can contain values that have templates within in the form of `${{ item }}` where the item within can be a reference to another property in the YAML, an environment variable, system symbol, or even simple conditional logic of them. This allows you to have configuration that works across multiple systems, such as by tying a hostname to `${{ zos.resolveSymbol(&SYSNAME) }}` to have the value be whatever the SYSNAME symbol is on a given LPAR.
Workspace: Each Instance has an area where Components can store data to persist across Zowe restarts or IPLs. Runtime state should instead be stored in the Caching Service component if high availability and fault tolerance is a concern, whereas the workspace instead covers items like user preferences.

## Distribution

The Zowe server components are distributed in multiple forms, such as SMPE, PSWI, and even PAX archive. You can find Zowe's official distributions at zowe.org

## Installation of Runtime

The following covers installation when not using the Zowe Server Install Wizard. When using that instead, please refer to the prompts within it instead of this guide.

### SMPE or PSWI
1. When you install Zowe via SMPE or PSWI, the Runtime directory and datasets will be populated.
2. Navigate to the Runtime Directory and copy the `example-zowe.yaml` file to a location outside this folder, generally wherever you want to put the Zowe Instance.
3. Edit the YAML copy to set the values of "zowe.runtimeDirectory", "java.home", "node.home", and "zowe.setup.datasets", as follows
   1. zowe.runtimeDirectory: The location you extracted the PAX to.
   2. java.home: The location of the Java that will be used when installing & running Zowe. For example, if your java is located at /usr/lpp/java/J8.0_64/bin/java, then the java.home is /usr/lpp/java/J8.0_64
   3. node.home: The location of the NodeJS that will be used when installing & running ZOwe. For example, if your node is located at /usr/lpp/node/v18/bin/node, then the java.home is /usr/lpp/node/v18
   4. zowe.setup.datasets: This section defines where both Runtime and Instance datasets of Zowe will be created.


### PAX
1. Extract the PAX on some ZFS partition on z/OS. At least 1200MB of free space is required. (For example, `pax -ppx -rf zowe.pax`). The location you extract to is the "Runtime Directory"
2. Navigate to the Runtime Directory and copy the `example-zowe.yaml` file to a location outside this folder, generally wherever you want to put the Zowe Instance.
3. Edit the YAML copy to set the values of `zowe.runtimeDirectory`, `java.home`, `node.home`, and `zowe.setup.datasets`, as follows
   1. `zowe.runtimeDirectory`: The location you extracted the PAX to.
   2. `java.home`: The location of the Java that will be used when installing & running Zowe. For example, if your java is located at /usr/lpp/java/J8.0_64/bin/java, then the java.home is /usr/lpp/java/J8.0_64
   3. `node.home`: The location of the NodeJS that will be used when installing & running ZOwe. For example, if your node is located at /usr/lpp/node/v18/bin/node, then the java.home is /usr/lpp/node/v18
   4. `zowe.setup.datasets`: This section defines where both Runtime and Instance datasets of Zowe will be created.
5. Navigate to the `/bin` folder of the extracted location
6. Run `./zwe install -c /path/to/zowe.yaml`. This creates the Runtime datasets for the Zowe release.



## Configuration of Instance

The following covers configuration when not using the Zowe Server Install Wizard. When using that instead, please refer to the prompts within it instead of this guide.
Aside from the Zowe Server Install Wizard, there are three other ways to configure a Zowe Instance.
1. JCL samples: The Zowe Runtime dataset SZWESAMP contains templates of JCL that must be substituted with Zowe YAML parameters before executed. That can be done manually, or automatically via editing and submitting the job ZWEGENER, which will place resolved JCL into the PDSE defined at `zowe.setup.datasets.jcllib`
2. zwe operations: `zwe` is a Unix CLI program that has commands which will automate the execution of the JCL samples.
3. z/OSMF workflow: The z/OSMF workflows will prompt you for Zowe YAML parameters before submitting jobs equivalent to the actions seen in the JCL samples.


### Configuration by JCL
The Zowe Runtime Dataset SZWESAMP contains JCL samples that have templates referencing Zowe YAML parameters.
They cannot be submitted without modification as a result.

It is recommended to edit and submit the job SZWESAMP(ZWEGENER) which will validate the contents of your Zowe YAML before resolving the JCL templates and placing the resulting JCL into a separate PDSE created during installation, located at the value of `zowe.setup.datasets.jcllib`.

When the JCL is prepared, the following jobs can be submitted to perform the following Instance configuration actions:

#### Core Tasks
|Task|Description|Sample JCL|
|---|---|---|
|Create Instance Datasets|Creates datasets for holding PARMLIB content and non-ZFS Extension content that is particular to one Zowe instance|ZWEIMVS|
|APF Authorize privileged content|Zowe contains one privileged component, ZIS, which enables the security model by which the majority of Zowe is unprivileged and in key 8. The load library for the ZIS component (SZWEAUTH, or customized via YAML value `zowe.setup.dataset.authLoadlib`) and its extension library (The value value `zowe.setup.dataset.authPluginLib`) must be set APF authorized and run in key 4 to use ZIS and components that depend upon it|ZWEIAPF|
|Grant SAF permissions|The STC accounts for Zowe need permissions for operating servers, and users need permissions for interacting with the servers.|RACF: ZWEIRAC<br><br>TSS: ZWEITSS<br><br>ACF2: ZWEIACF|
|(z/OS v2.4 ONLY) Create Zowe SAF Resource Class|This is not needed on z/OS v2.5+. On z/OS v2.4, the SAF resource class for Zowe is not included, and must be created|RACF: ZWEIRACZ<br><br>TSS: ZWEITSSZ<br><br>ACF2: ZWEIACFZ|
|Copy STC JCL to PROCLIB|The jobs for starting the Zowe webservers, ZWESLSTC, and the Zowe APF authorized cross-memory server, ZWESISTC, and its auxiliary address space, ZWESASTC, must be copied to the desired proclib for running. The YAML value `zowe.setup.dataset.proclib` defines where these members will be placed. The names of the members can be customized with YAML value `zowe.setup.security.stcs`|ZWEISTC|


#### Keyring Tasks

**Certificate requirements**: Zowe's keyring must have the following
* Private key & certificate pair: The Zowe Servers will use this certificate, and it must either not have the "Extended Key Usage" attribute, or have it with both "Server Authorization" and "Client Authorization" values.
* Certificate Authorities: Every intermediate and root Certificate Authority (CA) Zowe interacts with must be within the Keyring, unless the YAML value `zowe.verifyCertificates` is set to `DISABLED`. CAs that must be within the keyring include z/OSMF's CAs if using z/OSMF, and Zowe's own certificate's CAs as Zowe servers must be able to verify each other.

There are 4 options for setting up keyrings: Three scenarios covered by JCL samples where a keyring is created for you, or a fourth where you can bring your own keyring.

|Keyring Setup Type|Description|Sample JCL|
|---|---|---|
|1|Zowe will create a keyring and populate it with a newly generated certificate and certificate authority. The certificate would be seen as "self-signed" by clients unless import of the CA to clients is performed|RACF:ZWEIKRR1<br><br>TSS:ZWEIKRT1<br><br>ACF2:ZWEIKRA1|
|2|Zowe will create a keyring and populate it by connecting pre-existing certificates and CAs that you specify.|RACF:ZWEIKRR2<br><br>TSS:ZWEIKRT2<br><br>ACF2:ZWEIKRA2|
|3|Zowe will create a keyring and populate it by importing PKCS12 content from a dataset that you specify.|RACF:ZWEIKRR3<br><br>TSS:ZWEIKRT3<br><br>ACF2:ZWEIKRA3|

Alternatively, zowe can use a keyring provided by you as long as the contents meet Zowe's requirements and configure YAML values within `zowe.certificate` as follows:
```yaml
zowe:
  certificate:
    keystore:
      type: JCERACFKS
      name: "safkeyring://<STC Account Name>/<Ring Name>"
      alias: "<Name of your certificate>"
      password: "password" #literally "password". keyrings do not use passwords, so this is a placeholder.
    truststore:
      type: JCERACFKS
      name: "safkeyring://<STC Account Name>/<Ring Name>"
      password: "password" #literally "password". keyrings do not use passwords, so this is a placeholder.
```

#### (Optional) Caching Service VSAM Task:
If you plan to use the Zowe caching service Component, such as for high availability and fault tolerance reasons, then you must choose a form of database for it to use.
Among the choices is for it to use a VSAM dataset of your choice.

|Task|Description|Sample JCL|
|---|---|---|
|Create VSAM Dataset for Caching Service|Creates a RLM or NONRLM dataset for the caching service using the YAML values in `zowe.setup.vsam`|ZWECSVSM|

JCL samples for removing Zowe configuration also exist.
|Action|Sample|
|---|---|
|Remove Instance Datasets|ZWERMVS|
|Remove SAF Permissions|ZWENOSEC|
|Remove Keyring|ZWENOKR|
|Remove Caching Service VSAM Dataset|ZWECSRVS|

### Configuration by zwe

`zwe` is a unix tool located in the `<Runtime Directory>/bin` directory of Zowe.
If you type `zwe init --help`, you will see each configuration command that is available.
Each command reads configuration properties from the Zowe YAML files, and combines that with the JCL samples from the SZWESAMP dataset.
The commands resolve the JCL sample templates into usable JCL within the dataset defined by YAML value `zowe.setup.dataset.jcllib`.
Before each command runs, it will pritn the JCL that it is submitting.

Every `zwe init` command also has a `--dry-run` option which validates the configuration, prints the JCL, but does not submit it.
This allows you to review the actions before performing them with the appropriate administrator.

The following commands can be run to set up a Zowe Instance via `zwe`

|Task|Description|Command|
|Create Instance Datasets|Creates datasets for holding PARMLIB content and non-ZFS Extension content that is particular to one Zowe instance|`zwe init mvs`|
|APF Authorize privileged content|Zowe contains one privileged component, ZIS, which enables the security model by which the majority of Zowe is unprivileged and in key 8. The load library for the ZIS component (SZWEAUTH, or customized via YAML value `zowe.setup.dataset.authLoadlib`) and its extension library (The value value `zowe.setup.dataset.authPluginLib`) must be set APF authorized and run in key 4 to use ZIS and components that depend upon it|`zwe init apfauth`|
|Grant SAF permissions|The STC accounts for Zowe need permissions for operating servers, and users need permissions for interacting with the servers.|`zwe init security`|
|Copy STC JCL to PROCLIB|The jobs for starting the Zowe webservers, ZWESLSTC, and the Zowe APF authorized cross-memory server, ZWESISTC, and its auxiliary address space, ZWESASTC, must be copied to the desired proclib for running. The YAML value `zowe.setup.dataset.proclib` defines where these members will be placed. The names of the members can be customized with YAML value `zowe.setup.security.stcs`|`zwe init stc`|


#### Keystore or Keyring Configuration

**Certificate requirements**: Zowe's keystore or keyring must have the following
* Private key & certificate pair: The Zowe Servers will use this certificate, and it must either not have the "Extended Key Usage" attribute, or have it with both "Server Authorization" and "Client Authorization" values.
* Certificate Authorities: Every intermediate and root Certificate Authority (CA) Zowe interacts with must be within the Keyring, unless the YAML value `zowe.verifyCertificates` is set to `DISABLED`. CAs that must be within the keyring include z/OSMF's CAs if using z/OSMF, and Zowe's own certificate's CAs as Zowe servers must be able to verify each other.

There are 6 scenarios for setting up certificates for Zowe to use. There are five scenarios in the YAML to have Zowe create a ZFS PKCS12 keystore, or z/OS keyring, and an additional sixth option to bring your own keyring.

To have Zowe create a keystore or keyring for you, run `zwe init certificate` for one of the options below.
|Certificate scenario|Description|
|---|---|
|1|Zowe will create a ZFS keystore and populate it with newly generated PKCS12 certificate and certificate authority files. The certificate would be seen as "self-signed" by clients unless import of the CA to clients is performed|
|2|Zowe will create a ZFS keystore and populate it with PKCS12 certificate and certificate authority content that you provide.|
|3|Zowe will create a keyring and populate it with a newly generated certificate and certificate authority. The certificate would be seen as "self-signed" by clients unless import of the CA to clients is performed|
|4|Zowe will create a keyring and populate it by connecting pre-existing certificates and CAs that you specify.|
|5|Zowe will create a keyring and populate it by importing PKCS12 content from a dataset that you specify.|

Alternatively, zowe can use a keyring provided by you as long as the contents meet Zowe's requirements and configure YAML values within `zowe.certificate` as follows:
```yaml
zowe:
  certificate:
    keystore:
      type: JCERACFKS
      name: "safkeyring://<STC Account Name>/<Ring Name>"
      alias: "<Name of your certificate>"
      password: "password" #literally "password". keyrings do not use passwords, so this is a placeholder.
    truststore:
      type: JCERACFKS
      name: "safkeyring://<STC Account Name>/<Ring Name>"
      password: "password" #literally "password". keyrings do not use passwords, so this is a placeholder.
```

(Optional) Caching Service VSAM Configuration:
If you plan to use the Zowe caching service Component, such as for high availability and fault tolerance reasons, then you must choose a form of database for it to use.
Among the choices is for it to use a VSAM dataset of your choice.

|Task|Description|Sample JCL|
|---|---|---|
|Create VSAM Dataset for Caching Service|Creates a RLM or NONRLM dataset for the caching service using the YAML values in `zowe.setup.vsam`|`zwe init vsam`|



## References

To learn about the requirements and prerequisites of Zowe, review https://docs.zowe.org/stable/user-guide/systemrequirements-zos

To learn more about YAML and how Zowe uses it, review https://docs.zowe.org/stable/appendix/zowe-yaml-configuration

To learn more about advanced YAML configuration, review https://docs.zowe.org/stable/user-guide/configmgr-using/

To learn more about certificates, review https://docs.zowe.org/stable/user-guide/configure-certificates

To learn more about which SAF resources Zowe and its users need, review https://docs.zowe.org/stable/user-guide/assign-security-permissions-to-users

To learn more about using z/OSMF workflows for setup, review https://docs.zowe.org/stable/user-guide/zosmf-install
