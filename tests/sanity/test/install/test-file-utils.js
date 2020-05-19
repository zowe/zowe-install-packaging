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

describe('verify file-utils', function() {
  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  let home_dir;
  before('get required parameters', async function() {
    home_dir = await sshHelper.executeCommandWithNoError('echo $HOME');
  });

  describe('verify get_full_path', function() {

    let curr_dir;
    // let parent_dir;
    before('get required parameters', async function() {
      curr_dir = await sshHelper.executeCommandWithNoError('echo $PWD');
      // parent_dir = await sshHelper.executeCommandWithNoError('echo $(cd ../;pwd)');
    });

    it('test home directory is expanded', async function() {
      const input = '~/test';
      const expected = home_dir + '/test';
      await test_get_full_path(input, expected);
    });

    it('test full path is not modified', async function() {
      const input = `${process.env.ZOWE_INSTANCE_DIR}/test123`;
      const expected = input;
      await test_get_full_path(input, expected);
    });

    it('test relative path is evaluated', async function() {
      const test_dir = 'test_dir123124';
      const input = `../${test_dir}`;
      const expected = `${curr_dir}/../${test_dir}`;// TODO - it would be evaluate to `${parent_dir}/${test_dir}`;
      await test_get_full_path(input, expected);
    });

    async function test_get_full_path(input, expected_stdout) {
      const command = `get_full_path "${input}"`;
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, 0, expected_stdout, '');
    }
  });

  describe('validate_file_not_in_directory', function() {

    it('test file in directory not valid', async function() {
      const file = `${home_dir}/test`;
      const directory = home_dir;
      await test_validate_file_not_in_directory(file, directory, false);
    });

    it('test file in home directory expanded not valid', async function() {
      const file = '~/test';
      const directory = home_dir;
      await test_validate_file_not_in_directory(file, directory, false);
    });

    it('test siblings without trailing slash is valid', async function() {
      const file = '/home/zowe/instance';
      const directory = '/home/zowe/root';
      await test_validate_file_not_in_directory(file, directory, true);
    });

    it('test siblings with trailing slash is valid', async function() {
      const file = '/home/zowe/instance';
      const directory = '/home/zowe/root/';
      await test_validate_file_not_in_directory(file, directory, true);
    });

    it('test siblings with both trailing slash is valid', async function() {
      const file = '/home/zowe/instance/';
      const directory = '/home/zowe/root/';
      await test_validate_file_not_in_directory(file, directory, true);
    });

    //TODO zip #1325 - until we can evaluate ../ this will fail
    it.skip('test relative sibling is valid', async function() {
      const file = '/home/zowe/root/../test';
      const directory = '/home/zowe/root/';
      await test_validate_file_not_in_directory(file, directory, true);
    });

    async function test_validate_file_not_in_directory(file, directory, expected_valid) {
      const command = `validate_file_not_in_directory "${file}" "${directory}"`;
      const expected_rc = expected_valid ? 0 : 1;
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', '');
    }
  });

  describe('validate_directory_is_accessible and writable', function() {

    let temp_dir = 'temp_' + Math.floor(Math.random() * 10e6);
    let inaccessible_dir = `${temp_dir}/inaccessible`;
    before('set up test directory', async function() {
      await sshHelper.executeCommandWithNoError(`mkdir -p ${inaccessible_dir} && chmod a-wx ${temp_dir}`);
    });

    function get_inaccessible_message(directory) {
      return `Directory '${directory}' doesn't exist, or is not accessible to ${process.env.SSH_USER.toUpperCase()}. If the directory exists, check all the parent directories have traversal permission (execute)`;
    }

    it('test home directory is accessible', async function() {
      const directory = home_dir;
      await test_validate_directory_is_accessible(directory, true);
    });

    it('test junk directory is not accessible', async function() {
      const directory = '/junk/rubbish/madeup';
      await test_validate_directory_is_accessible(directory, false);
    });

    // zip-1377 Marist seems to have elevated privileges be able to access non-traversable directories, so this fails
    it.skip('test non-traversable directory is not accessible', async function() {
      await test_validate_directory_is_accessible(inaccessible_dir, false);
    });

    async function test_validate_directory_is_accessible(directory, expected_valid) {
      const command = `validate_directory_is_accessible "${directory}"`;
      const expected_rc = expected_valid ? 0 : 1;
      const expected_err = expected_valid ? '' : get_inaccessible_message(directory);
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', expected_err);
    }

    it('test home directory is writable', async function() {
      const directory = home_dir;
      await test_validate_directory_is_writable(directory, true);
    });

    it('test junk directory shows as not accessible on writable check', async function() {
      const directory = '/junk/rubbish/madeup';
      const command = `validate_directory_is_writable "${directory}"`;
      const expected_rc = 1;
      const expected_err = get_inaccessible_message(directory);
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', expected_err);
    });

    // zip-1377 Marist's ACF2 and TS id seems to have elevated privileges be able to write non-writable directories, so this fails
    it.skip('test non-writable directory is not writable', async function() {
      await test_validate_directory_is_writable(temp_dir, false);
    });

    async function test_validate_directory_is_writable(directory, expected_valid) {
      const command = `validate_directory_is_writable "${directory}"`;
      const expected_rc = expected_valid ? 0 : 1;
      const expected_err = expected_valid ? '' : `Directory '${directory}' does not have write access`;
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', expected_err);
    }

    after('clean up test directory', async function() {
      await sshHelper.executeCommandWithNoError(`chmod 770 ${temp_dir} && rm -rf ${temp_dir}`);
    });
  });
  
  async function test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    const file_utils_path = process.env.ZOWE_ROOT_DIR+'/bin/utils/file-utils.sh';
    command = `export ZOWE_ROOT_DIR=${process.env.ZOWE_ROOT_DIR} && . ${file_utils_path} && ${command}`;
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
