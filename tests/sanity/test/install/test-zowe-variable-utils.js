/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const sshHelper = require('./ssh-helper');

describe('verify zowe-variable-utils', function() {
  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  const validate_variable_is_set = 'validate_variable_is_set';
  describe(`verify ${validate_variable_is_set}`, function() {

    it('test home env_var is set', async function() {
      const input = 'HOME';
      await test_validate_variable_set(input, true);
    });

    it('test new variable is not set', async function() {
      const variable_name = 'test_unset_variable';
      await test_validate_variable_set(variable_name, false);
    });

    it('test set variable is set', async function() {
      const variable_name = 'test_set_variable';
      const command = `export ${variable_name}="true" && ${validate_variable_is_set} "${variable_name}"`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '');
    });

    async function test_validate_variable_set(variable_name, expected_valid) {
      const command = `${validate_variable_is_set} "${variable_name}" "\${${variable_name}}"`;
      const expected_rc = expected_valid ? 0 : 1;
      const expected_err = expected_valid ? '' : `${variable_name} is empty`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', expected_err);
    }
  });

  const validate_zowe_prefix = 'validate_zowe_prefix';
  describe(`verify ${validate_zowe_prefix}`, function() {

    it('test empty prefix validated false', async function() {
      const command = `export ZOWE_PREFIX="" && ${validate_zowe_prefix}`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 1, '', 'ZOWE_PREFIX is empty');
    });

    it('test variable length 2 is valid', async function() {
      await test_validate_zowe_prefix('Z1', true);
    });

    it('test default variable is valid', async function() {
      await test_validate_zowe_prefix('ZWE1', true);
    });

    it('test variable length 6 is valid', async function() {
      await test_validate_zowe_prefix('ZWESJH', true);
    });

    it('test variable length 7 is not valid', async function() {
      await test_validate_zowe_prefix('ZWE1234', false);
    });

    async function test_validate_zowe_prefix(prefix, expected_valid) {
      const command = `export ZOWE_PREFIX=${prefix} && ${validate_zowe_prefix}`;
      const expected_rc = expected_valid ? 0 : 1;
      const expected_err = expected_valid ? '' : `ZOWE_PREFIX '${prefix}' should be less than 7 characters`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', expected_err);
    }
  });
  
  async function test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    const variable_utils_path = process.env.ZOWE_ROOT_DIR+'/bin/utils/zowe-variable-utils.sh';
    command = `export ZOWE_ROOT_DIR=${process.env.ZOWE_ROOT_DIR} && . ${variable_utils_path} && ${command}`;
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
