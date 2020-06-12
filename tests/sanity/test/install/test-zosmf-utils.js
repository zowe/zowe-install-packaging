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

describe('verify zosmf-utils', function() {
  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  before('verify environment variables', function() {
    expect(process.env.ZOSMF_PORT, 'ZOSMF_PORT is not defined').to.not.be.empty;
  });

  const get_zosmf_port = 'prompt_zosmf_port_if_required';
  describe(`verify ${get_zosmf_port}`, function() {

    it('test that we get the correct port', async function() {
      const command = `${get_zosmf_port} && echo "\${ZOWE_ZOSMF_PORT}"`;
      await test_zosmf_utils_function_has_expected_rc_stdout_stderr(command, 0, process.env.ZOSMF_PORT, '');
    });
  });

  const extract_zosmf_port = 'extract_zosmf_port';
  describe(`verify ${extract_zosmf_port}`, function() {

    it('test that we get the correct port given a list of 1', async function() {
      const port_list = process.env.ZOSMF_PORT;
      await test_extract_zosmf_port(port_list, 0, process.env.ZOSMF_PORT, '');
    });

    // a good NODE_HOME isn't available to the test at this point, so we can't get this to go into the correct if block. Tested manually
    it.skip('test that we get the correct port given a list of 3 and a host', async function() {
      const port_list = `2020
${process.env.ZOSMF_PORT}
80`;
      await test_extract_zosmf_port(port_list, 0, process.env.ZOSMF_PORT, '', process.env.SSH_HOST);
    });

    it('test that we return non-zero given a list of 2 and no host', async function() {
      const port_list = `2020
${process.env.ZOSMF_PORT}`;
      await test_extract_zosmf_port(port_list, 1, '', '');
    });

    it('test that we return non-zero given a list of 0', async function() {
      const port_list = '';
      await test_extract_zosmf_port(port_list, 1, '', '');
    });

    async function test_extract_zosmf_port(port_list, expected_rc, expected_stdout, expected_stderr, zosmf_host = '') {
      const command = `export ZOSMF_HOST=${zosmf_host} && ${extract_zosmf_port} "${port_list}" && echo "\${ZOWE_ZOSMF_PORT}"`;
      await test_zosmf_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr, true);
    }
  });

  const validate_zosmf_host_and_port = 'validate_zosmf_host_and_port';
  describe(`verify ${validate_zosmf_host_and_port}`, function() {

    let start_node_home;
    before('get required parameters', async function() {
      start_node_home = await sshHelper.executeCommandWithNoError('echo $NODE_HOME');
    });

    after('restore env', async function() {
      await sshHelper.executeCommandWithNoError(`export NODE_HOME=${start_node_home}`);
    });

    it('test empty zosmf_host throws error', async function() {
      await test_validate_zosmf_host_and_port('', process.env.ZOSMF_PORT, 1, '', 'The z/OSMF host was not set');
    });

    it('test empty zosmf_port throws error', async function() {
      await test_validate_zosmf_host_and_port(process.env.SSH_HOST, '', 1, '', 'The z/OSMF port was not set');
    });

    it('test empty node home logs a warning', async function() {
      const pre_command = 'export NODE_HOME= &&';
      const expected_std_out = `Warning: Could not validate if z/OS MF is available on 'https://${process.env.SSH_HOST}:${process.env.ZOSMF_PORT}/zosmf/info'`;
      await test_validate_zosmf_host_and_port(process.env.SSH_HOST, process.env.ZOSMF_PORT, 0, expected_std_out, '', pre_command);
    });

    async function test_validate_zosmf_host_and_port(zosmf_host, zosmf_port, expected_rc, expected_stdout, expected_stderr, pre_command = '') {
      const command = `${pre_command} ${validate_zosmf_host_and_port} "${zosmf_host}" "${zosmf_port}"`;
      await test_zosmf_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr);
    }
  });

  const check_zosmf_info_response_code = 'check_zosmf_info_response_code';
  describe(`verify ${check_zosmf_info_response_code}`, function() {

    it('test empty https_response_code logs a warning', async function() {
      const expected_std_out = `Warning: Could not validate if z/OS MF is available on 'https://${process.env.SSH_HOST}:${process.env.ZOSMF_PORT}/zosmf/info'`;
      await test_validate_zosmf_host_and_port('', 0, expected_std_out, '');
    });

    it('test https_response_code 200 succeeds', async function() {
      const expected_stdout = `Successfully checked z/OS MF is available on 'https://${process.env.SSH_HOST}:${process.env.ZOSMF_PORT}/zosmf/info'`;
      await test_validate_zosmf_host_and_port('200', 0, expected_stdout, '');
    });

    it('test https_response_code 500 prints error', async function() {
      const http_response_code = 500;
      const expected_stderr = `Could not contact z/OS MF on 'https://${process.env.SSH_HOST}:${process.env.ZOSMF_PORT}/zosmf/info' - ${http_response_code}`;
      await test_validate_zosmf_host_and_port(http_response_code, 1, '', expected_stderr);
    });

    async function test_validate_zosmf_host_and_port(http_response_code, expected_rc, expected_stdout, expected_stderr) {
      const command = `export ZOSMF_HOST=${process.env.SSH_HOST} && export ZOSMF_PORT=${process.env.ZOSMF_PORT} && ${check_zosmf_info_response_code} ${http_response_code}`;
      await test_zosmf_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr);
    }
  });

  async function test_zosmf_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr, exact_match = false) {
    const zosmf_utils_path = process.env.ZOWE_ROOT_DIR + '/bin/utils/zosmf-utils.sh';
    command = `export ZOWE_ROOT_DIR=${process.env.ZOWE_ROOT_DIR} && . ${zosmf_utils_path} && ${command}`;
    // Whilst printErrorMessage outputs to STDERR and STDOUT we need to expect the err in both
    if (expected_stderr != '') {
      expected_stdout = expected_stderr;
    }
    await sshHelper.testCommand(command, expected_rc, expected_stdout, expected_stderr, exact_match);
  }

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
