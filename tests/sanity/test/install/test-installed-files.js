/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2020
 */

const sshHelper = require('./ssh-helper');

describe('verify installed files', function() {
  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  it('installed folder should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -d ${process.env.ZOWE_ROOT_DIR}`);
  });

  it('bin/zowe-start.sh should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -f ${process.env.ZOWE_INSTANCE_DIR}/bin/zowe-start.sh`);
  });

  it('scripts/internal/opercmd should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -f ${process.env.ZOWE_ROOT_DIR}/scripts/internal/opercmd`);
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

  // # verify the checksums of ROOT_DIR, to self-check zowe-verify-authenticity.sh
  // $binDir/zowe-verify-authenticity.sh # No parameters! 
  // You need to 'source' the profile to get JAVA_HOME

  it('fingerprint should match', async function() {
    await sshHelper.executeCommandWithNoError(`. ~/.profile && ${process.env.ZOWE_ROOT_DIR}/bin/zowe-verify-authenticity.sh`);
  });

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
