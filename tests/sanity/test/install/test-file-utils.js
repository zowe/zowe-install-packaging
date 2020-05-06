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
const debug = require('debug')('zowe-sanity-test:install:installed-utils');
const SSH = require('node-ssh');
const ssh = new SSH();

describe('verify file-utils', function() {
  before('prepare SSH connection', function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_PORT, 'SSH_PORT is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ROOT_DIR, 'ZOWE_ROOT_DIR is not defined').to.not.be.empty;
    expect(process.env.ZOWE_INSTANCE_DIR, 'ZOWE_INSTANCE_DIR is not defined').to.not.be.empty;

    const password = process.env.SSH_PASSWD;

    return ssh.connect({
      host: process.env.SSH_HOST,
      username: process.env.SSH_USER,
      port: process.env.SSH_PORT,
      password,
      tryKeyboard: true,
      onKeyboardInteractive: (name, instructions, instructionsLang, prompts, finish) => {
        if (prompts.length > 0 && prompts[0].prompt.toLowerCase().includes('password')) {
          finish([password]);
        }
      }
    })
      .then(function() {
        debug('ssh connected');
      });
  });

  let home_dir;
  before('get required parameters', function() {
    ssh.execCommand('echo $HOME')
      .then(function(result) {
        expect(result.stderr).to.be.empty;
        expect(result.code).to.equal(0);
        home_dir = result.stdout;
      });
  });

  describe('verify get_full_path', function() {

    let curr_dir;
    // let parent_dir;
    before('get required parameters', function() {
      // return ssh.execCommand(`echo $(cd ../;pwd)`)
      //   .then(function(result) {
      //     expect(result.stderr).to.be.empty;
      //     expect(result.code).to.equal(0);
      //     parent_dir = result.stdout;
      //   });
      return ssh.execCommand('echo $PWD')
        .then(function(result) {
          expect(result.stderr).to.be.empty;
          expect(result.code).to.equal(0);
          curr_dir = result.stdout;
        });
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
      const command = `get_full_path "${input}" actual && echo \${actual}`;
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
    before('set up test directory', function() {
      return ssh.execCommand(`mkdir -p ${inaccessible_dir} && chmod a-x ${temp_dir} && chmod a-w ${temp_dir}`)
        .then(function(result) {
          expect(result.stderr).to.be.empty;
          expect(result.code).to.equal(0);
        });
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

    it('test non-traversable directory is not accessible', async function() {
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

    it('test non-writable directory is not writable', async function() {
      await test_validate_directory_is_writable(temp_dir, false);
    });

    async function test_validate_directory_is_writable(directory, expected_valid) {
      const command = `validate_directory_is_writable "${directory}"`;
      const expected_rc = expected_valid ? 0 : 1;
      const expected_err = expected_valid ? '' : `Directory '${directory}' does not have write access`;
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', expected_err);
    }

    after('clean up test directory', function() {
      return ssh.execCommand(`chmod 770 ${temp_dir} && rm -rf ${temp_dir}`)
        .then(function(result) {
          expect(result.stderr).to.be.empty;
          expect(result.code).to.equal(0);
        });
    });
  });
  
  async function test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    const file_utils_path = process.env.ZOWE_ROOT_DIR+'/bin/utils/file-utils.sh';
    command = `. ${file_utils_path} && ${command}`;
    await test_ssh_command_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr);
  }

  function test_ssh_command_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    return ssh.execCommand(command)
      .then(function(result) {
        expect(result.code).to.equal(expected_rc);
        expect(result.stdout).to.have.string(expected_stdout);
        expect(result.stderr).to.have.string(expected_stderr);
      });
  }

  after('dispose SSH connection', function() {
    ssh.dispose();
  });
});
