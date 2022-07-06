/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2020
 */

const sshHelper = require('../ssh-helper');
const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:install:installed-files');
const addContext = require('mochawesome/addContext'); 


describe('verify installed files', function() {

  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  it('installed folder should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -d ${process.env.ZOWE_ROOT_DIR}`);
  });

  it('bin/zwe should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -f ${process.env.ZOWE_ROOT_DIR}/bin/zwe`);
  });

  it('bin/utils/opercmd.rex should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -f ${process.env.ZOWE_ROOT_DIR}/bin/utils/opercmd.rex`);
  });

  it('components/jobs-api/bin/jobs-api-server-*.jar should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -f ${process.env.ZOWE_ROOT_DIR}/components/jobs-api/bin/jobs-api-server-*.jar`);
  });

  it('fingerprint directory should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -d ${process.env.ZOWE_ROOT_DIR}/fingerprint`);
  });

  it('fingerprint RefRuntimeHash-*.txt should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -f ${process.env.ZOWE_ROOT_DIR}/fingerprint/RefRuntimeHash-*.txt`);
  });

  it('fingerprint should match', async function() {
    // IMPORT: After 'source' the profile, JAVA_HOME environment variable must exist
    const fingerprintStdout = await sshHelper.executeCommandWithNoError(`touch ~/.profile && . ~/.profile && ${process.env.ZOWE_ROOT_DIR}/bin/zwe support verify-fingerprints`);
    debug('fingerprint show result:', fingerprintStdout);
    addContext(this, {
      title: 'fingerprint show result',
      value: fingerprintStdout
    });
    expect(fingerprintStdout).to.contain('Number of different files: 0');
    expect(fingerprintStdout).to.contain('Number of extra files: 0');
    expect(fingerprintStdout).to.contain('Number of missing files: 0');
    expect(fingerprintStdout).to.contain('Zowe file fingerprints verification passed.');
  });

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
