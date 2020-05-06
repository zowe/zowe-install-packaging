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

///TODO - NOW - refactor out into shared function?
describe.only('verify zowe-variable-utils', function() { //TODO NOW - remove only
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
      const command = `export ${variable_name}="true" && ${validate_variable_is_set} "${variable_name}" "\${${variable_name}}"`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, 0, '', '');
    });

    async function test_validate_variable_set(variable_name, expected_valid) {
      const command = `${validate_variable_is_set} "${variable_name}" "\${${variable_name}}"`;
      const expected_rc = expected_valid ? 0 : 1;
      const expected_err = expected_valid ? '' : `${variable_name} is empty`;
      await test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', expected_err);
    }
  });
  
  async function test_zowe_variable_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    const variable_utils_path = process.env.ZOWE_ROOT_DIR+'/bin/utils/zowe-variable-utils.sh';
    command = `. ${variable_utils_path} && ${command}`;
    await test_ssh_command_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr);
  }

  // TODO NOW - refactor out into shared file
  function test_ssh_command_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    console.log(command);
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
