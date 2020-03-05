# Zowe Installation Test

Perform Zowe build installation / upgrade / uninstall tests.

## Quick Start

```
ANSIBLE_HOST=marist-1 \
  SSH_HOST=test-server \
  SSH_PORT=12022 \
  SSH_USER=********* \
  SSH_PASSWD=********* \
  DEBUG=test:* \
  npm test
```
