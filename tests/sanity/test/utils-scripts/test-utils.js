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
const sshHelper = require('../ssh-helper');

describe('verify utils', function() {
  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  before('verify environment variables', function() {
    expect(process.env.ZOSMF_PORT, 'ZOSMF_PORT is not defined').to.not.be.empty;
  });

  let home_dir;
  before('get required parameters', async function() {
    home_dir = await sshHelper.executeCommandWithNoError('echo $HOME');
  });

  it('test we can access function from zowe-variable-utils', async function() {
    const variable_name = 'test_unset_variable';
    const command = `is_variable_set "${variable_name}" "\${${variable_name}}"`;
    await test_utils_function_has_expected_rc_stdout_stderr(command, 1, '', `${variable_name} is empty`);
  });

  it('test we can access function from file-utils', async function() {
    const input = '~/test';
    const expected_out = home_dir + '/test';
    const command = `get_full_path "${input}"`;
    await test_utils_function_has_expected_rc_stdout_stderr(command, 0, expected_out, '');
  });

  it('test we can access function from network-utils', async function() {
    let command = `is_port_available ${process.env.ZOSMF_PORT}`;
    const expected_err = `Port ${process.env.ZOSMF_PORT} is already in use by process (IZUSVR1`;
    await test_utils_function_has_expected_rc_stdout_stderr(command, 1, '', expected_err);
  });
  
  async function test_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    await sshHelper.testCommand(command, {
      envs: {
        'ZOWE_ROOT_DIR': process.env.ZOWE_ROOT_DIR,
      },
      sources: [
        process.env.ZOWE_ROOT_DIR + '/bin/utils/utils.sh',
      ]
    }, {
      rc: expected_rc,
      // Whilst printErrorMessage outputs to STDERR and STDOUT we need to expect the err in both
      stdout: expected_stderr || expected_stdout,
      stderr: expected_stderr,
    });
  }

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
