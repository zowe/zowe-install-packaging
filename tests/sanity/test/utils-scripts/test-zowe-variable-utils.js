/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const sshHelper = require('../ssh-helper');


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
      const command = `${validate_variable_is_set} "${variable_name}"`;
      const expected_rc = expected_valid ? 0 : 1;
      const expected_err = expected_valid ? '' : `${variable_name} is empty`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', expected_err);
    }
  });

  const validate_variables_are_set = 'validate_variables_are_set';
  describe(`verify ${validate_variables_are_set}`, function() {

    it('test single set variable works', async function() {
      const input = ['HOME'];
      await test_validate_variables_set(input, []);
    });

    it('test one set and one unset variable gives a single error', async function() {
      const variable_list = ['HOME', 'test_unset_variable'];
      await test_validate_variables_set(variable_list, ['test_unset_variable']);
    });

    it('test two unset variable gives two errors', async function() {
      const variable_list = ['test_unset_variable1', 'test_unset_variable2'];
      await test_validate_variables_set(variable_list, variable_list);
    });

    async function test_validate_variables_set(variables_list, invalid_variables) {
      const command = `${validate_variables_are_set} "${variables_list.join()}"`;
      const expected_rc = invalid_variables.length;
      const error_list = invalid_variables.map((variable, index) => {
        return `Error ${index}: ${variable} is empty`;
      });
      const expected_err = error_list.join('\n');
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
  
  const update_zowe_instance_variable = 'update_zowe_instance_variable';
  describe(`verify ${update_zowe_instance_variable}`, function() {

    it('test append new zowe instance environment variable', async function() {
      const command = `${update_zowe_instance_variable} TEST_INSTANCE_VAR test_value`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '');
    });

    it('test validate new zowe instance environment variable appended', async function() {
      const command = `cat ${process.env.ZOWE_INSTANCE_DIR}/instance.env | grep '^ *TEST_INSTANCE_VAR=' | cut -f2 -d= | cut -f1 -d# | xargs`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'test_value', '');
    });

    it('test append value into existing zowe instance environment variable', async function() {
      const command = `${update_zowe_instance_variable} TEST_INSTANCE_VAR secondtest123`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '');
    });

    it('test value appended into existing zowe instance environment variable', async function() {
      const command = `cat ${process.env.ZOWE_INSTANCE_DIR}/instance.env | grep '^ *TEST_INSTANCE_VAR=' | cut -f2 -d= | cut -f1 -d# | xargs`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'secondtest123', '');
    });

    it('test append existing value', async function() {
      const command = `${update_zowe_instance_variable} TEST_INSTANCE_VAR test_value`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '');
    });

    it('test validate no change in zowe instance environment variable', async function() {
      const command = `cat ${process.env.ZOWE_INSTANCE_DIR}/instance.env | grep '^ *TEST_INSTANCE_VAR=' | cut -f2 -d= | cut -f1 -d# | xargs`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'test_value,secondtest123', '');
    });

    it('test replace value of a instance environment variable', async function() {
      const command = `${update_zowe_instance_variable} TEST_INSTANCE_VAR replaced_value false`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '');
    });

    it('test validate value of environment variable has been replaced', async function() {
      const command = `cat ${process.env.ZOWE_INSTANCE_DIR}/instance.env | grep '^TEST_INSTANCE_VAR=' | cut -f2 -d= | cut -f1 -d# | xargs`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'replaced_value', '');
    });
    
    after('Clean up temporary instance variable', async function() {
      await sshHelper.executeCommandWithNoError(`sed '$d' ${process.env.ZOWE_INSTANCE_DIR}/instance.env > ${process.env.ZOWE_INSTANCE_DIR}/instance.env.tmp`);
      await sshHelper.executeCommandWithNoError(`mv ${process.env.ZOWE_INSTANCE_DIR}/instance.env.tmp ${process.env.ZOWE_INSTANCE_DIR}/instance.env`);
    });
  });


  async function test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    await sshHelper.testCommand(command, {
      envs: {
        'ZOWE_ROOT_DIR': process.env.ZOWE_ROOT_DIR,
        'INSTANCE_DIR': process.env.ZOWE_INSTANCE_DIR,
      },
      sources: [
        process.env.ZOWE_ROOT_DIR + '/bin/utils/zowe-variable-utils.sh',
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
