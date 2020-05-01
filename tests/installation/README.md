# Zowe Installation Test

Perform Zowe build installation / upgrade / uninstall tests.

## Programming Language And Main Testing Method

- Node.js, with recommended [v8.x LTS](https://nodejs.org/docs/latest-v8.x/api/index.html)
- [Jest](https://jestjs.io/)

_Please note, currently package.json doesn't include *Babel JS*, which means all test cases are written in vanilla node.js v8.x supported syntax. ES2017 and ES2018 syntax are not fully supported. Please check [Node.js Support](https://node.green/) website._

## Run Test Cases On Your Local

### Prepare NPM Packages

Run `npm install` to install dependencies.

### Start Test

Example command:

```
TEST_SERVER=my-server \
  SSH_HOST=test-server-host-name \
  SSH_PORT=22 \
  SSH_USER=********* \
  SSH_PASSWD=********* \
  DEBUG=zowe-install-test:* \
  npm test
```

**Notes**:
- `my-server` should be a valid host defined in [Ansible hosts file](../../playbooks/hosts).
- Default Ansible verbose mode is `-v`. You can change by assign environment variable `ANSIBLE_VERBOSE`.
