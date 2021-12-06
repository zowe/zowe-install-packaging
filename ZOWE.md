# Zowe

Zowe is an integrated and extensible open source framework for z/OS.  This README is for quick start purpose. To learn more about Zowe, please visit:

- https://zowe.org for general information,
- https://docs.zowe.org for detail documentation.

## Prepare

### Extract Zowe convenience build

When extracting Zowe convenience build (`zowe-<version>.pax`), please note you should always **preserve extended attributes and file mode** with `-ppx` option.

For example, `pax -ppx -rf zowe-<version>.pax`.

### PATH environment

After extract Zowe convenience build or applied SMPE, you can add Zowe bin directory to your `PATH` environment variable:

```
export PATH=${PATH}:/path/to/my/zowe/bin
```

Once this is done, you can access Zowe server command `zwe` from any USS directory. Type `zwe --help` or `zwe -h` to learn how to use this command.

### zowe.yaml

Zowe uses a YAML file, usually mentioned as `zowe.yaml` to instruct Zowe how to install, configure and start Zowe.

Copy the `sample-zowe.yaml` located in Zowe bin directory to your preferred location, for example, your home directory. You can modify the file based on your environment and then move to next step.

## Install and configure

If you are using Zowe convenience build, you should run `zwe install --config /path/to/my/zowe.yaml` command to initialize Zowe MVS data sets. If you are using Zowe SMPE build, you can move on to next command.

Run `zwe init` command to initialize environment and permissions required by Zowe. Type `zwe init --help` to learn more about the command.

## Start and stop

- Run `zwe start --config /path/to/my/zowe.yaml` command to start Zowe.
- Run `zwe stop --config /path/to/my/zowe.yaml` command to stop Zowe.
