/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 20120
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

  describe('verify get_full_path', function() {

    let home_dir;
    before('get required parameters', function() {
      return ssh.execCommand('echo $HOME')
        .then(function(result) {
          expect(result.stderr).to.be.empty;
          expect(result.code).to.equal(0);
          home_dir = result.stdout;
        });
    });

    it('test home directory is expanded', function() {
      const file_utils_path = process.env.ZOWE_ROOT_DIR+'/bin/utils/file-utils.sh';
      const input = '~/test';
      const expected = home_dir + '/test';
      
      return ssh.execCommand(`. ${file_utils_path} && get_full_path "${input}" actual && echo \${actual}`)
        .then(function(result) {
          expect(result.stdout).to.equal(expected);
          expect(result.stderr).to.be.empty;
          expect(result.code).to.equal(0);
        });
    });
  });

  after('dispose SSH connection', function() {
    ssh.dispose();
  });
});
