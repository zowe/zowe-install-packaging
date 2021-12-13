/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020, 2021
 */

const sshHelper = require('../ssh-helper');


describe('verify utils/common', function() {

  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  const print_error_message = 'print_error_message';
  describe(`verify ${print_error_message}`, function() {

    it('test single message', async function() {
      const error = 'Oh, no - something went wrong';
      const expected_err = `Error 0: ${error}`;
      await test_print_error_message(error, expected_err);
    });

    it('test two messages', async function() {
      const error_0 = 'Oh, no - something went wrong';
      const error_1 = 'It happened again!';
      const expected_err = `Error 0: ${error_0}\nError 1: ${error_1}`;
      const command = `${print_error_message} "${error_0}" && ${print_error_message} "${error_1}"`;
      await test_common_function_has_expected_rc_stdout_stderr(command, {}, { stdout: expected_err, stderr: expected_err });
    });

    async function test_print_error_message(message, expected_message) {
      const command = `${print_error_message} "${message}"`;
      // Currently we output errors to stdout and stderr
      await test_common_function_has_expected_rc_stdout_stderr(command, {}, { stdout: expected_message, stderr: expected_message });
    }
  });

  const print_message = 'print_message';
  describe(`verify ${print_message}`, function() {

    it('test single message', async function() {
      const message = 'this is a printed message';
      const command = `${print_message} "${message}"`;
      await test_common_function_has_expected_rc_stdout_stderr(command, {}, { stdout: message });
    });
  });

  const log_message = 'log_message';
  describe(`verify ${log_message}`, function() {

    it('test log message with no log_file', async function() {
      const message = 'Log this';
      await test_log_message(message, message);
    });

    describe('with a log file created', async function() {
      const temp_dir = '~/delete_1234';
      const log_file = `${temp_dir}/log.txt`;
      before('create log file', async function() {
        await sshHelper.executeCommandWithNoError(`mkdir -p ${temp_dir} && touch ${log_file} && chmod u+w ${log_file}`);
      });

      after('dispose dummy node', async function() {
        await sshHelper.executeCommandWithNoError(`rm -rf ${temp_dir}`);
      });

      it('test log message with log_file', async function() {
        const message = 'Log this';
        await test_log_message(message, message, log_file);
      });
    });

    async function test_log_message(message, expected_out, log_file = '') {
      const command = `${log_message} "${message}"`;
      if (log_file == '') {
        await test_common_function_has_expected_rc_stdout_stderr(command, {}, { stdout: expected_out });
      } else {
        //Nothing stdout
        await test_common_function_has_expected_rc_stdout_stderr(command, { 'LOG_FILE': log_file });
        //Check log content
        await test_common_function_has_expected_rc_stdout_stderr(`cat ${log_file}`, {}, { stdout: expected_out });
      }
    }
  });

  const print_and_log_message = 'print_and_log_message';
  describe(`verify ${print_and_log_message}`, function() {

    it('test log message with no log_file', async function() {
      const message = 'Log this';
      await test_print_and_log_message(message, message);
    });

    describe('with a log file created', async function() {
      const temp_dir = '~/delete_1234';
      const log_file = `${temp_dir}/log.txt`;
      before('create log file', async function() {
        await sshHelper.executeCommandWithNoError(`mkdir -p ${temp_dir} && touch ${log_file} && chmod u+w ${log_file}`);
      });

      after('dispose dummy node', async function() {
        await sshHelper.executeCommandWithNoError(`rm -rf ${temp_dir}`);
      });

      it('test log message with log_file', async function() {
        const message = 'Log this';
        await test_print_and_log_message(message, message, log_file);
      });
    });

    async function test_print_and_log_message(message, expected_out, log_file = '') {
      const command = `${print_and_log_message} "${message}"`;
      if (log_file == '') {
        await test_common_function_has_expected_rc_stdout_stderr(command, {}, { stdout: expected_out });
      } else {
        //Check stdout
        await test_common_function_has_expected_rc_stdout_stderr(command, { 'LOG_FILE': log_file }, { stdout: expected_out });
        //Check log content
        await test_common_function_has_expected_rc_stdout_stderr(`cat ${log_file}`, {}, { stdout: expected_out });
      }
    }
  });

  const runtime_check_for_validation_errors_found = 'runtime_check_for_validation_errors_found';
  describe(`verify ${runtime_check_for_validation_errors_found}`, function() {

    it('test log message with no error', async function() {
      const errors_found = 0;
      await test_common_function_has_expected_rc_stdout_stderr(runtime_check_for_validation_errors_found, {
        'ERRORS_FOUND': errors_found,
        'INSTANCE_DIR': process.env.ZOWE_INSTANCE_DIR,
      });
    });

    it('test log message with specific errors', async function() {
      const errors_found = 10;
      const message = `${errors_found} errors were found during validation, please check the message, correct any properties required in ${process.env.ZOWE_INSTANCE_DIR}/instance.env and re-launch Zowe`;
      await test_common_function_has_expected_rc_stdout_stderr(runtime_check_for_validation_errors_found, {
        'ERRORS_FOUND': errors_found,
        'INSTANCE_DIR': process.env.ZOWE_INSTANCE_DIR,
      }, {
        rc: errors_found,
        stdout: message,
      });
    });

    it('test log message with specific errors without exit', async function() {
      const errors_found = 10;
      const message = `${errors_found} errors were found during validation, please check the message, correct any properties required in ${process.env.ZOWE_INSTANCE_DIR}/instance.env and re-launch Zowe`;
      await test_common_function_has_expected_rc_stdout_stderr(runtime_check_for_validation_errors_found, {
        'ERRORS_FOUND': errors_found,
        'INSTANCE_DIR': process.env.ZOWE_INSTANCE_DIR,
        'ZWE_IGNORE_VALIDATION_ERRORS': 'true',
      }, {
        rc: 0,
        stdout: message,
      });
    });
  });

  const print_formatted_message = 'print_formatted_message';
  describe(`verify ${print_formatted_message}`, function() {
    const log_service = 'SANITYTEST';
    const log_stack = 'stack1,stack2';
    const log_message = 'test message';
    const set_log_level = (lvl) => {
      const envs = {};
      envs[`ZWE_PRIVATE_LOG_LEVEL_${log_service}`] = lvl;
      return envs;
    };

    it('should display INFO formatted log without log level config', async function() {
      await test_common_function_has_expected_rc_stdout_stderr(`print_formatted_message "${log_service}" "${log_stack}" INFO "${log_message}"`,
        {},
        {
          stdout: `INFO (${log_stack}) ${log_message}`,
        },
        false);
    });

    it('should display ERROR formatted log without log level config', async function() {
      await test_common_function_has_expected_rc_stdout_stderr(`print_formatted_message "${log_service}" "${log_stack}" ERROR "${log_message}"`,
        {},
        {
          stderr: `ERROR (${log_stack}) ${log_message}`,
        },
        false);
    });

    it('should not display DEBUG formatted log without log level config', async function() {
      await test_common_function_has_expected_rc_stdout_stderr(`print_formatted_message "${log_service}" "${log_stack}" DEBUG "${log_message}"`,
        {},
        {},
        false);
    });

    it('should display DEBUG formatted log if log level is DEBUG', async function() {
      await test_common_function_has_expected_rc_stdout_stderr(`print_formatted_message "${log_service}" "${log_stack}" DEBUG "${log_message}"`,
        set_log_level('debug'),
        {
          stdout: `DEBUG (${log_stack}) ${log_message}`,
        },
        false);
    });
  });

  async function test_common_function_has_expected_rc_stdout_stderr(command, envs = {}, expected = {}, exact_match = true) {
    await sshHelper.testCommand(command, {
      envs: Object.assign({ 'ZOWE_ROOT_DIR': process.env.ZOWE_ROOT_DIR }, envs),
      sources: [ process.env.ZOWE_ROOT_DIR + '/bin/utils/common.sh' ]
    }, expected, exact_match);
  }

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
