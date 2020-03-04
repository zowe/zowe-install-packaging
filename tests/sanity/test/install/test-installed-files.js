/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const expect = require('chai').expect;
const debug = require('debug')('test:install:installed-files');
const SSH = require('node-ssh');
const ssh = new SSH();

describe('verify installed files', function() {
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

  it('installed folder should exist', function() {
    return ssh.execCommand('test -d ' + process.env.ZOWE_ROOT_DIR)
      .then(function(result) {
        expect(result.stderr).to.be.empty;
        expect(result.code).to.equal(0);
      });
  });

  it('bin/zowe-start.sh should exist', function() {
    return ssh.execCommand('test -f ' + process.env.ZOWE_INSTANCE_DIR + '/bin/zowe-start.sh')
      .then(function(result) {
        expect(result.stderr).to.be.empty;
        expect(result.code).to.equal(0);
      });
  });

  it('scripts/internal/opercmd should exist', function() {
    return ssh.execCommand('test -f ' + process.env.ZOWE_ROOT_DIR + '/scripts/internal/opercmd')
      .then(function(result) {
        expect(result.stderr).to.be.empty;
        expect(result.code).to.equal(0);
      });
  });

  it('components/jobs-api/bin/jobs-api-server-*.jar should exist', function() {
    return ssh.execCommand('test -f ' + process.env.ZOWE_ROOT_DIR + '/components/jobs-api/bin/jobs-api-server-*.jar')
      .then(function(result) {
        expect(result.stderr).to.be.empty;
        expect(result.code).to.equal(0);
      });
  });

  after('dispose SSH connection', function() {
    ssh.dispose();
  });
});
