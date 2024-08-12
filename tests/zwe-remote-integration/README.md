# Zowe System-Integration Test

Runs integration-style tests for the `zwe` command line utility. The `zwe` tool requires a backend system to run these tests and some tests may modify system state as part of their execution. (TODO: more information on system state changes / accepted tests, e.g. dataset creation happens but security manager updates will not)

## Programming Languages, Tools, Pre-Reqs

- Node.js, with recommended [v20.x LTS](https://nodejs.org/docs/latest-v20.x/api/index.html)
- [Jest](https://jestjs.io/)
- Requires `tar` and `unzip` on the command line
- Makes heavy use of [@zowe/cli](https://github.com/zowe/zowe-cli) Node SDKs

## Testing Behaviors & Limitations

These tests currently work by deploying a working `zwe` command line tool to a remote system, using the `zwe` component as-is from this repo; i.e. not from a pre-built PAX file. All of `zwe`'s dependencies will be set in place on the remote system as part of setup.

Each test runs a given `zwe` command and compares both stdout and return codes to pre


## Run Test Cases On Your Local

### Prepare NPM Packages

Run `npm install` to install dependencies.

### Build the test cases

Run `npm run-script build` to build the test cases.

### Prepare a configmgr PAX

Download and place a valid config manager PAX file under the `.build` directory in this project.

### Start Test

Example command:

```
TEST_SERVER=my-server \
  SSH_HOST=test-server-host-name \
  SSH_PORT=22 \
  ZOSMF_PORT = 10443 \ 
  SSH_USER=********* \
  SSH_PASSWORD=********* \
  REMOTE_TEST_ROOT_DIR=/some/dir \ 
  DEBUG=zowe-system-integration-test:* \
  npm test
```

**Notes**:
- `my-server` should be a valid host defined in [Ansible hosts file](../../playbooks/hosts).
- Default Ansible verbose mode is `-v`. You can change by assign environment variable `ANSIBLE_VERBOSE`.
