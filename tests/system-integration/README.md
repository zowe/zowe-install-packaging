# Zowe System-Integration Test

Runs integration tests for components in the zowe-install-packaging repository which require a backend system to execute.

## Programming Language And Main Testing Method

- Node.js, with recommended [v20.x LTS](https://nodejs.org/docs/latest-v20.x/api/index.html)
- [Jest](https://jestjs.io/)

## Testing Behaviors & Limitations

These tests currently work by uploading the `zwe` command line tool as it currently exists in this repo; i.e. not from a PAX file. This means that certain capabilities which require compiled java files in the `/bin/utils` dir will not work. 

These tests expect a valid configmgr PAX file to exist under a `.build` directory in the test directory (`tests/system-integration/.build/cfgmgr*pax`). The automated workflow will download configmgr using the `manifest.json.template`` in the root directory.


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
