# Zowe

Zowe is an integrated and extensible open source framework for z/OS.  This README is for quick start purpose. To learn more about Zowe, please visit:

- https://zowe.org for general information,
- https://docs.zowe.org for detail documentation.

## Prepare

### Extract Zowe convenience build

When extracting Zowe convenience build (`zowe-<version>.pax`), please note you should always **preserve extended attributes and file mode** with `-ppx` option.

For example, `pax -ppx -rf zowe-<version>.pax`.

### PATH environment

After extract Zowe convenience build or apply SMPE, you can add Zowe bin directory to your `PATH` environment variable:

```
export PATH=${PATH}:/path/to/my/zowe/bin
```

Once this is done, you can access Zowe server command `zwe` from any USS directory. Type `zwe --help` or `zwe -h` to learn how to use this command.

_Note: this step is optional. If Zowe runtime bin directory is not added to `PATH`, you will need to refer `zwe` command with full path to where it's located._

### zowe.yaml

Zowe uses a YAML file, usually mentioned as `zowe.yaml` to instruct Zowe how to install, configure and start Zowe.

Copy the `example-zowe.yaml` located in Zowe `bin` directory to your preferred location, for example, your home directory. You can modify the file based on your environment and then move to next step.

## Install

If you are using Zowe convenience build, you should run `zwe install --config /path/to/my/zowe.yaml` command to install Zowe MVS data sets. If you are using Zowe SMPE build, you can skip this and move on to next step.

## Initialize

Zowe needs to be initialized with proper security configurations, certificates, etc.

Run `zwe init --config /path/to/my/zowe.yaml` command to initialize environment and permissions required by Zowe. Type `zwe init --help` to learn more about this command and what's needed in `zowe.yaml`.

`zwe init` command is a combination of multiple sub-commands: `mvs`, `certificate`, `security`, `vsam`, `apfauth`, and `stc`. Type `zwe init <sub-command> --help` (for example, `zwe init stc --help`) to learn how to run `zwe init` command step by step.

`zwe init` command will try to run all 6 sub-commands in sequence automatically. You can choose to run selected init sub-commands one by one to get better granular control on each step.

These `zwe init` arguments could be useful:

- `--update-config` argument allows the init process update your `zowe.yaml` based on automatic detection and your `zowe.setup`. For example, if `java.home` and `node.home` are not defined, they could be updated based on the information we collect on the system. Another example is `zowe.certificate` section can be updated automatically based on your `zowe.setup.certificate` settings.
- `--allow-overwritten` argument allows you to re-run `zwe init` command repeatedly, even though some data sets are already created.
- `-v` or `--verbose` will provide you more information on `zwe` command execution details. This is for troubleshooting purpose if the error message is not clear enough.
- `-vv` or `--trace` will provide you EVEN more information than `--verbose` mode on `zwe` command execution details. This is for troubleshooting purpose if the error message is not clear enough.

## Start and stop

- Run `zwe start --config /path/to/my/zowe.yaml` command to start Zowe. It will issue `S` command to Zowe `ZWESLSTC`.
- Run `zwe stop --config /path/to/my/zowe.yaml` command to stop Zowe. It will issue `P` command to Zowe job.
