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

describe.only('verify installed utils', function() {
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

    function test_get_full_path(input, expected) {
      const file_utils_path = process.env.ZOWE_ROOT_DIR+'/bin/utils/file-utils.sh';
      return ssh.execCommand(`. ${file_utils_path} && get_full_path "${input}" actual && echo \${actual}`)
        .then(function(result) {
          expect(result.stdout).to.equal(expected);
          expect(result.stderr).to.be.empty;
          expect(result.code).to.equal(0);
        });
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
    xit('test relative sibling is valid', async function() {
      const file = '/home/zowe/root/../test';
      const directory = '/home/zowe/root/';
      await test_validate_file_not_in_directory(file, directory, true);
    });

    function test_validate_file_not_in_directory(file, directory, expected_valid) {
      const expected_rc = expected_valid ? 0 : 1;
      const file_utils_path = process.env.ZOWE_ROOT_DIR+'/bin/utils/file-utils.sh';
      return ssh.execCommand(`. ${file_utils_path} && validate_file_not_in_directory "${file}" "${directory}"`)
        .then(function(result) {
          expect(result.stderr).to.be.empty;
          expect(result.code).to.equal(expected_rc);
        });
    }
  });

  after('dispose SSH connection', function() {
    ssh.dispose();
  });
});
