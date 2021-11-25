# Zowe

Zowe is an integrated and extensible open source framework for z/OS.  This README is for quick start purpose. To learn more about Zowe, please visit:

- https://zowe.org for general information,
- https://docs.zowe.org for detail documentation.

## Prepare

### PATH environment

After extract Zowe convenience build or applied SMPE build, you can add Zowe bin directory to your `PATH` environment variable like this:

```
export PATH=${PATH}:/path/to/my/zowe/bin
```

For example, if you extract Zowe to /usr/lpp/zowe, you can define like this on your `~/.profile`:

```
export PATH=${PATH}:/usr/lpp/zowe/bin
```

Once this is added, you can access Zowe server-side CLI `zwe` command from any directory.

Anytime if you feel lost on the command, type `zwe --help` to get more information.

### zowe.yaml

Zowe uses a YAML file, usually mentioned as `zowe.yaml` to instruct Zowe how to install, configure and start Zowe.

Copy the `sample-zowe.yaml` located in Zowe bin directory to your preferred location, for example, your home directory. You can modify the file based on your environment and then move to next step.

## Install and configure

If you are using Zowe convenience build, you should run `zwe install --config /path/to/my/zowe.yaml` command to initialize Zowe MVS datasets. If you are using Zowe SMPE build, you can go straight to next step.

Run `zwe init` command to initialize environment and permissions required by Zowe.

## Start and stop

You can run `zwe start --config /path/to/my/zowe.yaml` command to start Zowe.
You can run `zwe stop --config /path/to/my/zowe.yaml` command to stop Zowe.
