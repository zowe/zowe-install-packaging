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
      await test_common_function_has_expected_rc_stdout_stderr(command, 0, expected_err, expected_err);
    });

    async function test_print_error_message(message, expected_message) {
      const command = `${print_error_message} "${message}"`;
      // Currently we output errors to stdout and stderr
      await test_common_function_has_expected_rc_stdout_stderr(command, 0, expected_message, expected_message);
    }
  });

  const print_message = 'print_message';
  describe(`verify ${print_message}`, function() {

    it('test single message', async function() {
      const message = 'this is a printed message';
      const command = `${print_message} "${message}"`;
      await test_common_function_has_expected_rc_stdout_stderr(command, 0, message, '');
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
        await test_common_function_has_expected_rc_stdout_stderr(command, 0, expected_out, '');
      } else {
        //Nothing stdout
        await test_common_function_has_expected_rc_stdout_stderr(`export LOG_FILE=${log_file} && ${command}`, 0, '', '');
        //Check log content
        await test_common_function_has_expected_rc_stdout_stderr(`cat ${log_file}`, 0, expected_out, '');
      }
    }
  });

  async function test_common_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    const common_utils_path = process.env.ZOWE_ROOT_DIR + '/bin/utils/common.sh';
    command = `export ZOWE_ROOT_DIR=${process.env.ZOWE_ROOT_DIR} && . ${common_utils_path} && ${command}`;
    await sshHelper.testCommand(command, expected_rc, expected_stdout, expected_stderr);
  }

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
