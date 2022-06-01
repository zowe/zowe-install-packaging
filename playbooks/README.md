# Use Ansible to control Zowe instance

This project targets to use Ansible to uninstall / install Zowe.

- [Use Ansible to control Zowe instance](#use-ansible-to-control-zowe-instance)
  - [Prepare Environment](#prepare-environment)
    - [Verify Inventory and Variables](#verify-inventory-and-variables)
    - [Other verifications or tools](#other-verifications-or-tools)
  - [Install (Uninstall) Zowe](#install-uninstall-zowe)
    - [Convenience Build](#convenience-build)
    - [SMPE FMID](#smpe-fmid)
    - [SMPE PTF](#smpe-ptf)
    - [Uninstall Zowe](#uninstall-zowe)
    - [Kubernetes/Openshift](#kubernetesopenshift)
    - [Install Zowe Extensions](#install-zowe-extensions)
  - [Other Predefined Playbooks](#other-predefined-playbooks)
    - [Sanity Test a Zowe Instance](#sanity-test-a-zowe-instance)
    - [Start and Stop a Zowe Instance](#start-and-stop-a-zowe-instance)
    - [Show Zowe Logs](#show-zowe-logs)
  - [Other Build Variables](#other-build-variables)

## Prepare Environment

You need Ansible v2.9.4+. Please check [Installation Document](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) from Ansible website.

You also need Java installed on z/OS. The `JAVA_HOME` should be defined in the user `~/.profile` and Java bin folder should be added to `PATH` environment variable.

### Verify Inventory and Variables

- Check [hosts](hosts) file.
- Check variables defined in [group_vars/all.yml](group_vars/all.yml).
- Check variables defined for each group, for example: [group_vars/marist.yml](group_vars/marist.yml).
- Check variables defined for each host or create a host variable YAML for your server. For example: [host_vars/river-0.yml](host_vars/river-0.yml).
- Setup `ansible_password` or `ansible_ssh_private_key_file` for your host you are working on.
- Verify values of `zowe_zos_host`, `zowe_external_domain_name`, `zowe_external_ip_address`, `zowe_test_user` and `zowe_test_password` for your host.

### Other verifications or tools

- List Hosts
  ```
  $ ansible all --list-hosts
  ```
- Verify Variables
  ```
  $ ansible all -m debug -a "var=hostvars"
  ```

## Install (Uninstall) Zowe

### Convenience Build

To install Zowe convenience build, run playbook `install.yml`:

```
$ ansible-playbook -l <server> install.yml -v
```

Please Note:

- The playbook will install the `zowe.pax` pre-uploaded to `work_dir_remote`.
- The install playbook will also uninstall Zowe by default.
- The `-v` option allows you to see stdout from server side, which includes installation log, etc.

If you just want to uninstall Zowe, run playbook `uninstall.yml`:

```
$ ansible-playbook -l <server> uninstall.yml -v
```

If you want to install a Zowe downloaded to your local computer, you can run the playbook with variable `zowe_build_local`:

```
$ ansible-playbook -l <server> install.yml -v --extra-vars "zowe_build_local=/path/to/your/local/zowe.pax"
```

If you want to install a Zowe from a URL, you can run the playbook with variable `zowe_build_url`:

```
$ ansible-playbook -l <server> install.yml -v --extra-vars "zowe_build_url=https://zowe.jfrog.io/zowe/libs-release-local/org/zowe/1.9.0/zowe-1.9.0.pax"
```

For example, you can pick a downloadable Zowe build from https://zowe.jfrog.io/zowe/webapp/#/artifacts/browse/tree/General/libs-release-local/org/zowe.

### SMPE FMID

To install Zowe SMPE build, run playbook `install-fmid.yml`:

```
$ ansible-playbook -l <server> install-fmid.yml -v
```

Please Note:

- The playbook will install the `AZWE*.pax.Z` and `AZWE*.readme.txt` pre-uploaded to `work_dir_remote`.
- The SMPE build must be the new `.zip` format. The old release formats of `.pax.Z` or `.tar` are not supported.
- The install playbook will also uninstall Zowe by default.
- The `-v` option allows you to see stdout from server side, which includes installation log, etc.

If you want to install a Zowe FMID pre-uploaded to your remote server, you can run the playbook with variable `zowe_build_remote` (You must define `zowe_fmids_dir_remote` if you choose this option):

```
$ ansible-playbook -l <server> install-fmid.yml -v --extra-vars "zowe_build_remote=AZWE002"
```

If you want to install a Zowe downloaded to your local computer, you can run the playbook with variable `zowe_build_local`:

```
$ ansible-playbook -l <server> install-fmid.yml -v --extra-vars "zowe_build_local=/path/to/your/local/zowe-smpe.zip"
```

If you want to install a Zowe from a URL, you can run the playbook with variable `zowe_build_url`:

```
$ ansible-playbook -l <server> install-fmid.yml -v --extra-vars "zowe_build_url=https://zowe.jfrog.io/zowe/libs-release-local/org/zowe/1.9.0/zowe-smpe-package-1.9.0.zip"
```

### SMPE PTF

To install Zowe SMPE PTF, run playbook `install-ptf.yml`:

```
$ ansible-playbook -l <server> install-ptf.yml -v
```

Please Note:

- The playbook will install the `ZOWE.AZWE*.UO*` and `ZOWE.AZWE*.UO*.readme.htm` pre-uploaded to `work_dir_remote`.
- The SMPE PTF build must be the new `.zip` format. The old release formats of `.pax.Z` or `.tar` are not supported.
- The PTF install playbook requires Zowe FMID pre-installed on the server.
- The PTF install playbook will NOT uninstall Zowe.
- The `-v` option allows you to see stdout from server side, which includes installation log, etc.


If you want to install a Zowe downloaded to your local computer, you can run the playbook with variable `zowe_build_local`:

```
$ ansible-playbook -l <server> install-ptf.yml -v --extra-vars "zowe_build_local=/path/to/your/local/zowe-smpe.zip"
```

If you want to install a Zowe from a URL, you can run the playbook with variable `zowe_build_url`:

```
$ ansible-playbook -l <server> install-ptf.yml -v --extra-vars "zowe_build_url=https://zowe.jfrog.io/zowe/libs-release-local/org/zowe/1.10.0/zowe-smpe-package-1.10.0.zip"
```

### Uninstall Zowe

You can uninstall and cleanup the host by running `uninstall.yml` playbook.

```
$ ansible-playbook -l <server> uninstall.yml -v
```

### Kubernetes/Openshift

You can use playbook `install-kubernetes.yml` to install Zowe containers in a container orchestration cluster (i.e. Kubernetes, OpenShift, IBM Cloud Kubernetes, Google Cloud Kubernetes)

Please Note:
- This install playbook does NOT install Zowe convenience build onto the target z/OS system. But, it will require ZSS, ZIS and z/OSMF be installled and started on z/OS side. 
- This install playbook does NOT install any container orchestation cluster. But, it will require one to deploy the Zowe containers.
  
There are many environmental variables for this playbook. Since there are different Kubernetes/OpenShift cluster, you can customize environmental variable to accomadate your needs. Please read the README file, found in Kubernetes role folder, for more information about the list of environmental variables can be used for this playboook `install-kubernetes.yml`. 

For example, Install Zowe containers on local Kubernetes service provisioned by Docker-Desktop:

```
ansible-playbook -l <server> install-kubernetes.yml -e k8s_context=docker-desktop -e ansible_user=<user> -e ansible_password=<password> -e ansible_ssh_host=<host> -e zowe_instance_dir=<zowe-instance-location>
```

Install Zowe containers on Kubernetes running on BareMetal:
```
ansible-playbook -l <server> install-kubernetes.yml -e kubeconfig=<location_of_the_file>/kubeconfig -e ansible_user=<user> -e ansible_password=<password> -e ansible_ssh_host=<host> -e k8s_gateway_domain="*.nio.io" -e k8s_discovery_domain="*.nio.io" -e k8s_storageclass=<storageclassname> -e k8s_service=nodeport -e k8s_list_domain_ip="1.2.3.4.nip.io,1.2.3.4" -e k8s_networking=ingress -e zowe_instance_dir=<zowe-instance-location>
```

### Install Zowe Extensions

You can install an extension by providing it's full url to the extension using the `zowe_ext_url` variable. This will download and install the extension onto the specified running Zowe instance:
```
$ ansible-playbook -l <server> install-ext.yml -v --extra-vars "zowe_ext_url=https://zowe.jfrog.io/artifactory/libs-snapshot-local/org/zowe/sample-node-api/1.0.0-SNAPSHOT/sample-node-api-1.0.0-snapshot-6-20210126212259.pax"
```

You can also install an extension that exists in your local directory by using the `zowe_ext_local` variable. This will transfer the file from your local to the remote server and install the extension:
```
$ ansible-playbook -l <server> install-ext.yml -v --extra-vars "zowe_ext_local=/path/to/local/directory/zowe-extension.pax"
```

Please Note:

- This playbook is compatible with `.pax, .zip and .tar` files
- The `-v` option allows you to see stdout from server side, which includes installation log, etc.

## Other Predefined Playbooks

### Sanity Test a Zowe Instance

You can run a playbook to give a quick check if the Zowe instance is running as expected. The playbook will launch sanity tests defined in [tests/sanity](../tests/sanity/README.md).

```
$ ansible-playbook -l <server> verify.yml -v
```

_To run this playbook, you need node.js v8+ and npm installed on your computer._

### Start and Stop a Zowe Instance

You can use `start.yml` or `stop.yml` playbooks to start or stop an existing Zowe instance.

```
$ ansible-playbook -l <server> start.yml -v
```

### Show Zowe Logs

You can display Zowe logs by running `show-logs.yml` playbook. This playbook will display Zowe job (usually it should be `ZWE1SV`) log, Cross Memory Server job (usually it should be `ZWESISTC`) log and also all USS log files in the `logs` folder under Zowe instance directory.

```
$ ansible-playbook -l <server> show-logs.yml -v
```

## Other Build Variables

- **zowe_build_local**: An optional string to define where is the Zowe package on your local computer.
- **zowe_build_url**: An optional URL string to define where to download Zowe package.
- **zowe_build_remote**: An optional string to define the FMID you want to install and the FMID has been pre-uploaded to your target server `zowe_fmids_dir_remote` folder.
- **zowe_ext_local**: A string to define where the Zowe Extension is on your local computer. (one of zowe_ext_local or zowe_ext_url MUST be defined)
- **zowe_ext_url**: A string to define where to download the Zowe Extension. (one of zowe_ext_local or zowe_ext_url MUST be defined)
- **zos_java_home**: An optional string to customize your Java version by specifying the full path to your Java folder.
- **zos_node_home**: An optional string to customize your node.js version by specifying the full path to your node.js folder.
- **zowe_auto_create_user_group**: A boolean value to enable or disable creating Zowe user and group. Default value is `false`.
- **zowe_configure_security_dry_run**: A boolean value to skip running security configurations when configure Zowe instance.
- **zos_keystore_mode**: An optional string to configure Zowe instance to store certificates into Keyring instead of keystore. Valid values are `<empty>` (default value) or `KEYSTORE_MODE_KEYRING`.
- **skip_start**: A boolean value to skip automatically starting Zowe after installation. Default value is `false`.
- **zowe_uninstall_before_install**: If you want to uninstall Zowe before installing a new version. Default value is `true`.
- **zowe_custom_for_test**: If you want to customize the Zowe instance to run sanity test from zowe-install-packaging.
- **ZOWE_COMPONENTS_UPGRADE**: An optional boolean value to enable upgrading Zowe components to the latest version. If set to `true`,
the `zowe-upgrade-component.sh` script will be called to upgrade Zowe during the installation process.
