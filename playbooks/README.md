# Use Ansible to control Zowe instance

This project targets to use Ansible to uninstall / install Zowe.

## Prepare Environment

You need Ansible v2.9.4+. Please check [Installation Document](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) from Ansible website.

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
- Check if Ansible is usable on the target host
  ```
  $ ansible <server> -m ping
  ```

  For example:

  ```
  $ ansible marist-1 -m ping
  ```

## Install (Uninstall) Zowe

### Convenient Build

To install Zowe convenient build, run playbook `install.yml`:

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

### SMPE Build

To install Zowe SMPE build, run playbook `install-fmid.yml`:

```
$ ansible-playbook -l <server> install-fmid.yml -v
```

Please Note:

- The playbook will install the `AZWE*.pax.Z` and `AZWE*.readme.txt` pre-uploaded to `work_dir_remote`.
- The SMPE build must be the new `.zip` format. The old release formats of `.pax.Z` or `.tar` are not supported.
- The install playbook will also uninstall Zowe by default.
- The `-v` option allows you to see stdout from server side, which includes installation log, etc.

If you want to install a Zowe downloaded to your local computer, you can run the playbook with variable `zowe_build_local`:

```
$ ansible-playbook -l <server> install-fmid.yml -v --extra-vars "zowe_build_local=/path/to/your/local/zowe-smpe.zip"
```

If you want to install a Zowe from a URL, you can run the playbook with variable `zowe_build_url`:

```
$ ansible-playbook -l <server> install-fmid.yml -v --extra-vars "zowe_build_url=https://zowe.jfrog.io/zowe/libs-release-local/org/zowe/1.9.0/zowe-smpe-package-1.9.0.zip"
```

### Other Build Variables

- **zos_java_home**: customize your Java version by specifying the full path to your Java folder.
- **zos_node_home**: customize your node.js version by specifying the full path to your node.js folder.

### Sanity Test a Zowe Instance

You can run a playbook to give a quick check if the Zowe instance is running as expected. The playbook will launch sanity tests defined in [tests/sanity](../tests/sanity/README.md).

```
$ ansible-playbook -l <server> verify.yml -v
```

_To run this playbook, you need node.js v8+ and npm installed on your computer._
