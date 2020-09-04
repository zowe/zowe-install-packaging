# Use Ansible to control Zowe instance

This project targets to use Ansible to uninstall / install Zowe.

- [Prepare Environment](#prepare-environment)
  - [Verify Inventory and Variables](#verify-inventory-and-variables)
  - [Other verifications or tools](#other-verifications-or-tools)
- [Install (Uninstall) Zowe](#install-uninstall-zowe)
  - [Convenience Build](#convenience-build)
  - [SMPE FMID](#smpe-fmid)
  - [SMPE PTF](#smpe-ptf)
  - [Uninstall Zowe](#uninstall-zowe)
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
- Verify values of `zowe_external_domain_name`, `zowe_external_ip_address`, `zowe_test_user` and `zowe_test_password` for your host.

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
$ ansible-playbook -l <server> install-fmid.yml -v --extra-vars "zowe_build_remote=AZWE001"
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
- **zos_java_home**: An optional string to customize your Java version by specifying the full path to your Java folder.
- **zos_node_home**: An optional string to customize your node.js version by specifying the full path to your node.js folder.
- **zowe_auto_create_user_group**: A boolean value to enable or disable creating Zowe user and group. Default value is `false`.
- **zowe_configure_skip_zwesecur**: A boolean value to skip running `ZWESECUR` job when configure Zowe instance.
- **zos_keystore_mode**: An optional string to configure Zowe instance to store certificates into Keyring instead of keystore. Valid values are `<empty>` (default value) or `KEYSTORE_MODE_KEYRING`.
- **skip_start**: A boolean value to skip automatically starting Zowe after installation. Default value is `false`.
