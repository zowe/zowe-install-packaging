/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:cli:ssh');
// const addContext = require('mochawesome/addContext');
const { execZoweCli, defaultSSHProfileName, createDefaultSSHProfile } = require('./utils');

// marist servers are very unstable to make ssh connections, not sure why yet
describe.skip('cli perform ssh commands with zos-ssh', function() {
  before('verify environment variables', async function() {
    expect(process.env.ZOSMF_PORT, 'ZOSMF_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOWE_EXTERNAL_HOST, 'ZOWE_EXTERNAL_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_WORKSPACE_DIR, 'ZOWE_WORKSPACE_DIR is not defined').to.not.be.empty;

    const result = await createDefaultSSHProfile(
      process.env.ZOWE_EXTERNAL_HOST,
      process.env.SSH_USER,
      process.env.SSH_PASSWD,
      process.env.SSH_PORT,
    );

    debug('result:', result);

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    expect(result.stdout).to.be.empty;
  });

  it('checks to see if manifest.json exists in zowe-workspace-dir', async function() {
    const result = await execZoweCli(`zowe zos-ssh issue command "ls -la" --cwd ${process.env.ZOWE_WORKSPACE_DIR} --ssh-profile ${defaultSSHProfileName}`);

    debug('result:', result);
    // addContext(this, {
    //   title: 'cli result',
    //   value: result
    // });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');
    
    expect(result.stderr).to.be.empty;

    expect(result.stdout).to.have.string('manifest.json');
  });
});
