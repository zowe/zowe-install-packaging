# Zowe bin/ directory

## Zowe server CLI command

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
- `.parameters`: This is an _optional_ definition of command line parameters for this command. Parameters defined in this file will be combined with all upper level `.parameters` file and be available for this command. `zwe` command has global parameters like `--help`, `--verbose`, etc, which are defined in `bin/commands/.parameters` file. Every line of this file represents a CLI parameter. Each parameter definition is separated by `|` into 5 fields:
  1. is the parameter id, or full name. This column is required and the user can use `--` prefix to customize this parameter. For example, with `config` definition, the user can use `--config` to pass value to `zwe` command.
  2. is the parameter alias. This column is optional. This column is usually with one letter and the user can use `-` prefix to customize this parameter. For example, with `c` definition, the user can use `-c` to pass value to `zwe` command.
  3. is the parameter type. This column is required and must be value of `boolean` or `string`, or abbreviation of them like `b`, `bool`, `s`, `str`. This indicates how the user can pass parameter value.
    * If it's `boolean` parameter, the user can just pass the parameter itself. For example, `--verbose` or `-v`.
    * If it's `string` parameter, the user must pass a value along with the parameter. For example, `--config /path/to/my/config/file`.
  4. is the requirement of this parameter. If this parameter is required, put value `required` in this column.
  5. is reserved for future.
  6. is reserved for future.
  7. is the parameter help. This help message will be displayed if the user issue `--help` or `-h` parameter.
- `.experimental`: This is an _optional_ file indicate this command is for experimental purpose. It may be changed or improved in the future, and it may not be stable enough for extenders to use if they target to support multiple versions of Zowe.
- `index.sh`: This is required file to process the command. This file will be sourced to `zwe` when it's executed.

### Extend new command

To define a new command, create the right folder structure under `bin/commands` and then create the assistant files described above.

### Exit codes

`zwe` command may exit with non-zero code with errors.

- `99`
- `1`:
- `2`:

### Error codes and messages

Errors may show in `stderr` and here is a list of error codes.

## Libraries

`bin/libs` directory holds shell libraries used by Zowe, and you can take advantage of them too. Each library file and function may contain help messages.

Please be aware of using functions marked as `@experimental`. These functions may be changed or improved in the future, and they may not be stable enough for extenders to use if they target to support multiple versions of Zowe.

## Utilities

`bin/utils` directory holds several utility tools used by Zowe, and you can take advantage of them too.

- `bin/utils/opercmd.rex`: To issue operator command on z/OS. This script can only run on z/OS.
- `bin/utils/curl.js`: This is node.js script works similar to popular Linux tool `curl`. It can make HTTP/HTTPS request and display response.

Please be aware of using utilities marked as `@experimental`. These utilities may be changed or improved in the future, and they may not be stable enough for extenders to use if they target to support multiple versions of Zowe.
