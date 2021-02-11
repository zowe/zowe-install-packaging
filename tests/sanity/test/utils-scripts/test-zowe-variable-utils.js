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
const debug = require('debug')('zowe-sanity-test:utils-scripts:zowe-variable-utils');

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
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '', true);
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
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', expected_err, true);
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

  const source_env = 'source_env';
  describe.only(`verify ${source_env}`, function() {
    let TMP_DIR;
    const test_env_file = '.test-env';
    const test_env_content = [
      'GOOD_LINE1=value1', // most common case
      'GOOD_LINE2="value2"', // value wrapped with double quotation
      'GOOD_LINE3=\'value3\'', // value wrapped with single quotation
      '#COMMENT_LINE1=value1', // comment line
      '    #COMMENT_LINE2=value2', // comment line starts with spaces
      '\t#COMMENT_LINE3=value3', // comment line starts with tab
      '', // empty line
      '=value0', // key is not set
      'BAD_LINE', // line without =
      'BAD KEY1 #=value1', // line with bad key definition
      'GOOD_LINE4=value4 # with comments', // value with comments
      'GOOD_LINE5=line1\nline2\nline3', // value with multiple lines
    ].join('\\n').replace(/\n/g, '\\\\\\n').replace(/\r/g, '\\\\r').replace(/\t/g, '\\\\t').replace(/"/g, '\\"');
    before('create test env file', async function() {
      // retrieve tmp dir on server side
      TMP_DIR = await sshHelper.getTmpDir();
      debug(`${test_env_file}=${test_env_content}`);

      await sshHelper.executeCommandWithNoError(`rm -f ${TMP_DIR}/${test_env_file} && echo "${test_env_content}" > ${TMP_DIR}/${test_env_file}`);
    });

    after('dispose test env file', async function() {
      await sshHelper.executeCommandWithNoError(`rm -f ${TMP_DIR}/${test_env_file}`);
    });

    it('should be able to source the env file', async function() {
      const command = `${source_env} ${TMP_DIR}/${test_env_file} && env`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'GOOD_LINE1=value1', '', false);
    });

    it('should return value of regular line with key/value pair', async function() {
      const command = `${source_env} ${TMP_DIR}/${test_env_file} && echo "\${GOOD_LINE1}"`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'value1', '');
    });

    it('should return correct value if the value is wrapped with double quotation', async function() {
      const command = `${source_env} ${TMP_DIR}/${test_env_file} && echo "\${GOOD_LINE2}"`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'value2', '');
    });

    it('should return correct value if the value is wrapped with single quotation', async function() {
      const command = `${source_env} ${TMP_DIR}/${test_env_file} && echo "\${GOOD_LINE3}"`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'value3', '');
    });

    it('should return empty of line start with number sign', async function() {
      const command = `${source_env} ${TMP_DIR}/${test_env_file} && echo "\${COMMENT_LINE1}"`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '');
    });

    it('should return empty of line start with number sign and prefixed with spaces', async function() {
      const command = `${source_env} ${TMP_DIR}/${test_env_file} && echo "\${COMMENT_LINE2}"`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '');
    });

    it('should return empty of line start with number sign and prefixed with tab', async function() {
      const command = `${source_env} ${TMP_DIR}/${test_env_file} && echo "\${COMMENT_LINE3}"`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '');
    });

    it('should return empty of line doesn\'t has equation', async function() {
      const command = `${source_env} ${TMP_DIR}/${test_env_file} && echo "\${BAD_LINE}"`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '');
    });

    it('should return value with number sign if it\'s in the middle of the value', async function() {
      const command = `${source_env} ${TMP_DIR}/${test_env_file} && echo "\${GOOD_LINE4}"`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'value4 # with comments', '');
    });

    it('should return correct value if the value has line feeds', async function() {
      const command = `${source_env} ${TMP_DIR}/${test_env_file} && echo "\${GOOD_LINE5}"`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'line1\nline2\nline3', '');
    });
  });
  
  const read_zowe_instance_variable = 'read_zowe_instance_variable';
  const update_zowe_instance_variable = 'update_zowe_instance_variable';
  describe(`verify ${update_zowe_instance_variable}`, function() {
 
    it('test append new zowe instance environment variable', async function() {
      const command = `${update_zowe_instance_variable} TEST_INSTANCE_VAR test_value`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '', true);
    });

    it('test validate new zowe instance environment variable appended', async function() {
      const command = `${read_zowe_instance_variable} TEST_INSTANCE_VAR`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'test_value', '', true);
    });

    it('test append value into existing zowe instance environment variable', async function() {
      const command = `${update_zowe_instance_variable} TEST_INSTANCE_VAR secondtest123 true`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '', true);
    });

    it('test value appended into existing zowe instance environment variable', async function() {
      const command = `${read_zowe_instance_variable} TEST_INSTANCE_VAR`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'test_value,secondtest123', '', true);
    });

    it('test append existing value', async function() {
      const command = `${update_zowe_instance_variable} TEST_INSTANCE_VAR test_value true`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '', true);
    });

    it('test validate no change in zowe instance environment variable', async function() {
      const command = `${read_zowe_instance_variable} TEST_INSTANCE_VAR`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'test_value,secondtest123', '', true);
    });

    it('test replace value of a instance environment variable', async function() {
      const command = `${update_zowe_instance_variable} TEST_INSTANCE_VAR replaced_value`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '', true);
    });

    it('test validate value of environment variable has been replaced', async function() {
      const command = `${read_zowe_instance_variable} TEST_INSTANCE_VAR`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, 'replaced_value', '', true);
    });
    
    after('Clean up temporary instance variable', async function() {
      await sshHelper.executeCommandWithNoError(`sed '$d' ${process.env.ZOWE_INSTANCE_DIR}/instance.env > ${process.env.ZOWE_INSTANCE_DIR}/instance.env.tmp`);
      await sshHelper.executeCommandWithNoError(`mv ${process.env.ZOWE_INSTANCE_DIR}/instance.env.tmp ${process.env.ZOWE_INSTANCE_DIR}/instance.env`);
    });
  });


  async function test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr, exact_match = false) {
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
    },
    exact_match);
  }

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
