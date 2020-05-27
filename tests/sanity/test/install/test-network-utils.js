/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const expect = require('chai').expect;
const sshHelper = require('./ssh-helper');

describe('verify network-utils', function() {
  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  before('verify environment variables', function() {
    expect(process.env.ZOSMF_PORT, 'ZOSMF_PORT is not defined').to.not.be.empty;
  });

  let unbound_port = 1;
  before('find unbound port', async function() {
    let found_unbound = false;
    while (! found_unbound && unbound_port <= 65535) {
      const report = await sshHelper.executeCommandWithNoError(`netstat -P ${unbound_port}`);
      if (report.split(/\r?\n/).length <= 3) {
        // netstat report of format:
        // MVS TCP/IP NETSTAT CS V2R3       TCPIP Name: TCPIP           11:49:59
        // User Id  Conn     State
        // -------  ----     -----
        found_unbound = true;
      } else {
        unbound_port++;
      }
    }
  });

  const validate_port_is_available = 'validate_port_is_available';
  describe(`verify ${validate_port_is_available}`, function() {

    it('test zosmf port is not available', async function() {
      await test_port_available(process.env.ZOSMF_PORT, 'IZUSVR1');
    });

    it('test unbound port is available', async function() {
      await test_port_available(unbound_port);
    });

    async function test_port_available(port, expected_process = undefined) {
      let command = `${validate_port_is_available} ${port}`;
      const expected_rc = expected_process ? 1 : 0;
      const expected_err = expected_process ? `Port ${port} is already in use by process ${expected_process}` : '';
      await test_network_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', expected_err);
    }
  });

  async function test_network_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    const network_utils_path = process.env.ZOWE_ROOT_DIR + '/bin/utils/network-utils.sh';
    command = `export ZOWE_ROOT_DIR=${process.env.ZOWE_ROOT_DIR} && . ${network_utils_path} && ${command}`;
    // Whilst printErrorMessage outputs to STDERR and STDOUT we need to expect the err in both
    if (expected_stderr != '') {
      expected_stdout = expected_stderr;
    }
    await sshHelper.testCommand(command, expected_rc, expected_stdout, expected_stderr);
  }

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
