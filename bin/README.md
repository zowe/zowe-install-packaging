# Zowe bin/ directory

## Zowe server command

Zowe provides `zwe` command can help you manage Zowe instance.

To enable this command, you can add Zowe `<runtime>/bin` directory to your `PATH` environment variable. You can do so by running this command in USS or add it to your `~/.profile`.

```
# enable Zowe zwe command
export PATH=${PATH}:/path/to/my/zowe/bin
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

- `ZWE_zowe_runtimeDirectory`, parent directory of where `zwe` server command is located.
- `ZWE_CLI_COMMANDS_LIST`, list of command chain separated by comma.
- `ZWE_CLI_PARAMETERS_LIST`, command parameter names separated by comma.
- `ZWE_CLI_PARAMETER_<parameter-name>`, value of parameter `<parameter-name>`.
- `ZWE_CLI_INTERNAL_*` are variables used by Zowe launch script internally. It's not suggested for component to use or modify.
  * `ZWE_CLI_INTERNAL_PARAMETERS_DEFINITIONS`, this is a calculated variable holds all parameter definitions based on current command chain.
  * `ZWE_CLI_INTERNAL_LIBRARY_LOADED` indicates is `bin/libs` are already sourced or not.
  * `ZWE_CLI_INTERNAL_IS_TOP_LEVEL_COMMAND` indicates if currently is running as top-level command, or triggered by top-level command.
- `ZWE_LOG_LEVEL_CLI`, calculated log level based on `--debug|-v|--verbose|--trace|-vv` parameters. Default value is `INFO`. Other possible values are: `DEBUG` or `TRACE`.
- `ZWE_LOG_FILE` holds the value of log file if `--log-dir|--log|-l` is defined.
- `ZWE_DS_SZWEAUTH` is the data set name for Zowe load modules. Default value is `SZWEAUTH`.
- `ZWE_DS_SZWEPLUG` is the data set name for load modules from Zowe plug-ins. Default value is `SZWEPLUG`.
- `ZWE_DS_SZWESAMP` is the data set name for Zowe sample configurations . Default value is `SZWESAMP`.
- `ZWE_DS_SZWCLIB` is the data set name for Zowe CLIST library. Default value is `SZWCLIB`.
- `ZWE_DS_JCLLIB` is the data set name for Zowe JCL library . Default value is `JCLLIB`.
- `ZWE_CORE_COMPONENTS` is a constant holds names of core components.
- `ZWE_RUN_ON_ZOS` indicates if current is running on z/OS. If yes, the value is `true`.
- `ZWE_PWD` indicates which directory the user is located when executing `zwe` command.

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
