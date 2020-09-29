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
const debug = require('debug')('zowe-sanity-test:cli:uss');
// const addContext = require('mochawesome/addContext');
const { execZoweCli, defaultUSSProfileName, createDefaultUSSProfile } = require('./utils');

describe('cli perform ssh commands with zos-uss', function() {
  before('verify environment variables', async function() {
    expect(process.env.ZOSMF_PORT, 'ZOSMF_PORT is not defined').to.not.be.empty;
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_INSTANCE_DIR, 'ZOWE_INSTANCE_DIR is not defined').to.not.be.empty;

    const result = await createDefaultUSSProfile(
      process.env.SSH_HOST,
      process.env.SSH_USER,
      process.env.SSH_PASSWD,
      process.env.SSH_PORT,
    );

    debug('result:', result);

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    expect(result.stdout).to.have.string('Profile created successfully');
  });

  it('checks to see if instance.env exists in zowe-instance-dir', async function() {
    const result = await execZoweCli(`zowe zos-uss issue ssh "ls -la" --cwd ${process.env.ZOWE_INSTANCE_DIR} --ssh-profile ${defaultUSSProfileName}`);

    debug('result:', result);
    // addContext(this, {
    //   title: 'cli result',
    //   value: result
    // });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');
    
    expect(result.stderr).to.be.empty;

    expect(result.stdout).to.have.string('instance.env');
  });
});
