/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2020
 */

/* WORK IN PROGRESS.  DO NOT MERGE */
/* This is to test that zowe-support.sh produces the correct output */
/* CODE BELOW HERE IS A PLACEHOLDER */

const sshHelper = require('./ssh-helper');
const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:install:installed-files');
const addContext = require('mochawesome/addContext'); 

describe('verify zowe-support.sh', function() {
  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  it('installed folder should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -d ${process.env.ZOWE_ROOT_DIR}`);
  });

  it('bin/zowe-support.sh should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -f ${process.env.ZOWE_INSTANCE_DIR}/bin/zowe-support.sh`);
  });

//   params.ZOWE_RELEASE_VERSION ==~ 
//   /* "${params.ZOWE_RELEASE_VERSION} */

  if (params.ZOWE_RELEASE_VERSION >= "1.14.0") {
    it('fingerprint directory should exist', async function() {
        await sshHelper.executeCommandWithNoError(`test -d ${process.env.ZOWE_ROOT_DIR}/fingerprint`);
      });
    
    it('fingerprint RefRuntimeHash-*.txt should exist', async function() {
        await sshHelper.executeCommandWithNoError(`test -f ${process.env.ZOWE_ROOT_DIR}/fingerprint/RefRuntimeHash-*.txt`);
      });
  } else {
    debug(`No fingerprint: release is prior to 1.14.0`);
  }

  it('Support should produce output', async function() {
    const supportStdout = await sshHelper.executeCommandWithNoError(`touch ~/.profile && . ~/.profile && ${process.env.ZOWE_ROOT_DIR}/bin/zowe-support.sh`);
    debug('support show result:', supportStdout);
    addContext(this, {
      title: 'support show result',
      value: supportStdout
    });
    expect(supportStdout).to.contain('Collecting version of z/OS, Java, NodeJS');
    expect(supportStdout).to.contain('Collecting current process information based on the following prefix:');
    expect(supportStdout).to.contain('Adding');
    expect(supportStdout).to.contain('The support file was created');
  });

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
