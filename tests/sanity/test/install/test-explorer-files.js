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

describe('verify installed files', function() {

  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  it('installed explorer actions should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -f ${process.env.ZOWE_WORKSPACE_DIR}/app-server/ZLUX/pluginStorage/org.zowe.zlux.ng2desktop/actions/org.zowe.explorer-jes`);
  });

  it('installed explorer recognizer should exist', async function() {
    await sshHelper.executeCommandWithNoError(`test -f ${process.env.ZOWE_WORKSPACE_DIR}/app-server/ZLUX/pluginStorage/org.zowe.zlux.ng2desktop/recognizers/org.zowe.explorer-jes`);
  });

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
