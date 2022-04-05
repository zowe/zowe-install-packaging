# Zowe bin/ directory

## Zowe server command

Zowe provides `zwe` command can help you manage Zowe instance.

To enable this command, you can add Zowe `<runtime>/bin` directory to your `PATH` environment variable. You can do so by running this command in USS or add it to your `~/.profile`.

```
# enable Zowe zwe command
export PATH="${PATH}:/path/to/my/zowe/bin"
```

Now you can issue `zwe` command in your USS terminal. You can start with `zwe --help` to see what commands you can use.

The `bin/commands` directory defines available commands.

### Command assistant files

Each command is represented as a directory with some assistant files.

- `.help`: This is an _optional_ plain text help message. You can put any text here and it will be displayed if the user issue `--help` with your command.
- `.errors`: This is a documentation file lists all possible error codes and exit codes for this command. Each line represents one error and is separated by `|` into 3 fields:
  1. is the error code like `ZWEL0102E`.
  2. is the command exit code in a range of 1 to 255. The caller can check the command exit code to determine what's the error caused the command to exit prematurely.
  3. is the error message.
- `.parameters`: This is an _optional_ definition of command line parameters for this command. Parameters defined in this file will be combined with all upper level `.parameters` file and be available for this command. Please note if the command has embedded sub-commands, all parameters defined in parent will also be propagated to all sub-commands. `zwe` command has global parameters like `--help`, `--verbose`, etc, which are defined in `bin/commands/.parameters` file. Every line of this file represents a command line parameter. Each parameter definition is separated by `|` into 8 fields:
  1. is the parameter id, or full name. This column is required and the user can use `--` prefix to customize this parameter. For example, with `config` definition, the user can use `--config` to pass value to `zwe` command.
  2. is the parameter alias. This column is optional. This column is usually with one letter and the user can use `-` prefix to customize this parameter. For example, with `c` definition, the user can use `-c` to pass value to `zwe` command.
  3. is the parameter type. This column is required and must be value of `boolean` or `string`, or abbreviation of them like `b`, `bool`, `s`, `str`. This indicates how the user can pass parameter value.
    * If it's `boolean` parameter, the user can just pass the parameter itself. For example, `--verbose` or `-v`.
    * If it's `string` parameter, the user must pass a value along with the parameter. For example, `--config /path/to/my/config/file`.
  4. is the requirement of this parameter. If this parameter is required, put value `required` in this column.
  5. is the default value of the parameter. This is only valid for `string` parameters.
  6. is reserved for future usage.
  7. is reserved for future usage.
  8. is the parameter help. This help message will be displayed if the user issue `--help` or `-h` parameter.
- `.exclusive-parameters`: is in same format of `.parameters` except all parameters defined in this file will NOT be propagated to sub-commands.
- `.experimental`: This is an _optional_ file indicate this command is for experimental purpose. It may be changed or improved in the future, and it may not be stable enough for extenders to use if they target to support multiple versions of Zowe.
- `.examples`: This is an _optional_ file contains examples of this command. These examples will be displayed if the user issue `--help` or `-h` parameter.
- `index.sh`: This is required file to process the command. This file will be sourced to `zwe` when it's executed.

### Extend new command

To define a new command, create the right folder structure under `bin/commands` and then create the assistant files described above.

## Libraries

`bin/libs` directory holds shell libraries used by Zowe, and you can take advantage of them too. Each library file and function may contain help messages.

Please be aware of using functions marked as `@experimental`. These functions may be changed or improved in the future, and they may not be stable enough for extenders to use if they target to support multiple versions of Zowe.

## Utilities

`bin/utils` directory holds several utility tools used by Zowe, and you can take advantage of them too.

- `bin/utils/opercmd.rex`: To issue operator command on z/OS. This script can only run on z/OS.
- `bin/utils/curl.js`: This is node.js script works similar to popular Linux tool `curl`. It can make HTTP/HTTPS request and display response.

Please be aware of using utilities marked as `@experimental`. These utilities may be changed or improved in the future, and they may not be stable enough for extenders to use if they target to support multiple versions of Zowe.

## Environment variables

All Zowe initialized variables are prefixed with `ZWE_`.

### Global Zowe environment variables

These Zowe environment variables are created globally. Any Zowe components, extensions can use these variables.

**These variables are generated by Zowe. Modifying the value of these variables are not recommended.**

- `ZWE_CLI_COMMANDS_LIST`, list of command chain separated by comma.
- `ZWE_CLI_PARAMETER_<parameter-name>`, value of parameter `<parameter-name>`.
  * `ZWE_CLI_PARAMETER_CONFIG` is a commonly used variable which shows where is the YAML configuration.
  * `ZWE_CLI_PARAMETER_HA_INSTANCE` is a commonly used variable which indicates the current HA instance ID.
- `ZWE_CLI_PARAMETERS_LIST`, command parameter names separated by comma.
- `ZWE_DISCOVERY_SERVICES_LIST` contains a full list of enabled discovery services.
- `ZWE_DISCOVERY_SHARED_LIBS` contains a directory where discovery shared libraries are installed.
- `ZWE_ENABLED_COMPONENTS` is a list of components will be started in current HA instance.
- `ZWE_GATEWAY_HOST` contains domain name to access gateway internally.
- `ZWE_GATEWAY_SHARED_LIBS` contains a directory where gateway shared libraries are installed.
- `ZWE_INSTALLED_COMPONENTS` is a list of all installed components.
- `ZWE_LAUNCH_COMPONENTS` is a list of enabled components for current HA instance and has start command defined.
- `ZWE_POD_CLUSTERNAME` indicates the current Kubernetes cluster name Zowe is running. This variable is only applicable when Zowe is running in Kubernetes.
- `ZWE_POD_NAMESPACE` indicates the current Kubernetes namespace Zowe is running. This variable is only applicable when Zowe is running in Kubernetes.
- `ZWE_PWD` indicates which directory the user is located when executing `zwe` command.
- `ZWE_RUN_IN_CONTAINER` indicates if current component is running inside a container.
- `ZWE_RUN_ON_ZOS` indicates if current is running on z/OS. If yes, the value is `true`.
- `ZWE_STATIC_DEFINITIONS_DIR` is where Zowe stores API-ML static registration files.
- `ZWE_VERSION` is the current Zowe version without `v` prefix. For example, `2.0.0`. It is the `version` defined in `manifest.json` located in Zowe runtime directory.

**`ZWE_PRIVATE_*` are variables used by Zowe internally. It's not suggested for component to use or modify.**

- `ZWE_PRIVATE_CLI_IS_TOP_LEVEL_COMMAND` indicates if currently is running as top-level command, or triggered by top-level command.
- `ZWE_PRIVATE_CLI_LIBRARY_LOADED` indicates is `bin/libs` are already sourced or not.
- `ZWE_PRIVATE_CLI_PARAMETERS_DEFINITIONS`, this is a calculated variable holds all parameter definitions based on current command chain.
- `ZWE_PRIVATE_CONTAINER_COMPONENT_ID` indicates the component ID of current container. This variable is only applicable when Zowe is running in Kubernetes.
- `ZWE_PRIVATE_CONTAINER_COMPONENT_RUNTIME_DIRECTORY` is the directory of component runtime in Kubernetes deployment. Default value is `/component`.
- `ZWE_PRIVATE_CONTAINER_HOME_DIRECTORY` is the directory of Zowe home directory in Kubernetes deployment. Default value is `/home/zowe`.
- `ZWE_PRIVATE_CONTAINER_KEYSTORE_DIRECTORY` is the directory of Keystore directory in Kubernetes deployment. Default value is `/home/zowe/keystore`.
- `ZWE_PRIVATE_CONTAINER_LOG_DIRECTORY` is the directory of logs in Kubernetes deployment. Default value is `/home/zowe/instance/logs`.
- `ZWE_PRIVATE_CONTAINER_RUNTIME_DIRECTORY` is the directory of Zowe runtime in Kubernetes deployment. Default value is `/home/zowe/runtime`.
- `ZWE_PRIVATE_CONTAINER_WORKSPACE_DIRECTORY` is the directory of workspace in Kubernetes deployment. Default value is `/home/zowe/instance/workspace`.
- `ZWE_PRIVATE_CORE_COMPONENTS_REQUIRE_JAVA` is a list of java components shipped with Zowe.
- `ZWE_PRIVATE_DEFAULT_ADMIN_GROUP` is the default Zowe admin group. Default value is `ZWEADMIN`.
- `ZWE_PRIVATE_DEFAULT_AUX_STC` is the default name of Zowe Auxiliary Server started task. Default value is `ZWESASTC`.
- `ZWE_PRIVATE_DEFAULT_ZIS_STC` is the default name of Zowe ZIS server started task. Default value is `ZWESISTC`.
- `ZWE_PRIVATE_DEFAULT_ZIS_USER` is the default Zowe ZIS server user. Default value is `ZWESIUSR`.
- `ZWE_PRIVATE_DEFAULT_ZOWE_STC` is the default name of Zowe started task. Default value is `ZWESLSTC`.
- `ZWE_PRIVATE_DEFAULT_ZOWE_USER` is the default Zowe user. Default value is `ZWESVUSR`.
- `ZWE_PRIVATE_DS_SZWEAUTH` is the data set name for Zowe load modules. Default value is `SZWEAUTH`.
- `ZWE_PRIVATE_DS_SZWEEXEC` is the data set name for Zowe executable utilities library. Default value is `SZWEEXEC`.
- `ZWE_PRIVATE_DS_SZWESAMP` is the data set name for Zowe sample configurations . Default value is `SZWESAMP`.
- `ZWE_PRIVATE_LOG_FILE` holds the value of log file if `--log-dir|--log|-l` is defined.
- `ZWE_PRIVATE_LOG_LEVEL_ZWELS`, calculated log level based on `--debug|-v|--verbose|--trace|-vv` `zwe` command parameters. Default value is `INFO`. Other possible values are: `DEBUG` or `TRACE`. In Zowe runtime, value of `zowe.launchScript.logLevel` defined in Zowe YAML configuration file will overwrite this value.
- `ZWE_PRIVATE_WORKSPACE_ENV_DIR` is where Zowe stores calculated environment

### Generated environment variables from Zowe YAML configuration

Each line of Zowe YAML configuration will have a matching environment variable. This is converted based on pre-defined pattern:

- All configurations under `zowe`, `components`, `haInstances` will be converted to a variable with name:
  * prefixed with `ZWE_`,
  * any non-alphabetic-numeric characters will be converted to underscore `_`,
  * and no double underscores like `__`.
- Calculated configurations of `haInstance`, which is portion of `haInstances.<current-ha-instance>` will be converted same way.
- Calculated configurations of `configs`, which is portion of `haInstances.<current-ha-instance>.components.<current-component>` will be converted same way.
- All other configuration entries will be converted to a variable with name:
  * all upper cases,
  * any non-alphabetic-numeric characters will be converted to underscore `_`,
  * and no double underscores like `__`.

For examples:

- `ZWE_zowe_runtimeDirectory`, parent directory of where `zwe` server command is located.
- `ZWE_zowe_workspaceDirectory` is the path of user customized workspace directory.
- `ZWE_zowe_setup_dataset_prefix` is the dataset prefix where Zowe MVS data sets are installed.
- `ZWE_zowe_setup_dataset_parmlib` is the data set that end-user configured to store his customized version of parameter library members.
- `ZWE_zowe_setup_dataset_authPluginLib` is the data set that end-user configured to store his APF authorized ZIS plugins load library.
- `ZWE_zowe_setup_security_users_zowe` is the name of Zowe runtime user.
- `ZWE_configs_port` is your component port number you can use in your start script. It points to the value of `haInstances.<current-ha-instance>.components.<your-component>.port`, or fall back to `components.<my-component>.port`, or fall back to `configs.port` defined in your component manifest.

### Global shell environment variables

These environment variables are initialized globally to customize shell behaviors.

- `_CEE_RUNOPTS`: with value `FILETAG(AUTOCVT,AUTOTAG) POSIX(ON)`
- `_TAG_REDIR_IN`: with value `txt`
- `_TAG_REDIR_OUT`: with value `txt`
- `_TAG_REDIR_ERR`: with value `txt`
- `_BPXK_AUTOCVT`: with value `"ON"`
- `_EDC_ADD_ERRNO2`: with value `1`

### Global node.js environment variables

These environment variables are initialized globally to customize node.js behaviors.

- `NODE_STDOUT_CCSID`: with value `1047`
- `NODE_STDERR_CCSID`: with value `1047`
- `NODE_STDIN_CCSID`: with value `1047`
- `__UNTAGGED_READ_MODE`: with value `V6`
