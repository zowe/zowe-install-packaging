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
const debug = require('debug')('test:cli:zosmf');
const addContext = require('mochawesome/addContext');
const { execZoweCli, defaultZOSMFProfileName, createDefaultZOSMFProfile } = require('./utils');

describe('cli check zosmf status', function() {
  before('verify environment variables', async function() {
    expect(process.env.ZOSMF_PORT, 'ZOSMF_PORT is not defined').to.not.be.empty;
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;

    const result = await createDefaultZOSMFProfile(
      process.env.SSH_HOST,
      process.env.ZOSMF_PORT,
      process.env.SSH_USER,
      process.env.SSH_PASSWD
    );

    debug('result:', result);

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    expect(result.stdout).to.have.string('Profile created successfully');
  });

  it('should be able to return zosmf status', async function() {
    const result = await execZoweCli(`zowe zosmf check status --zosmf-profile ${defaultZOSMFProfileName}`);

    debug('result:', result);
    addContext(this, {
      title: 'cli result',
      value: result
    });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    expect(result.stdout).to.include('zosmf_port:');
    expect(result.stdout).to.include('zos_version:');
    expect(result.stdout).to.include('zosmf_full_version:');
    expect(result.stdout).to.include('z/OSMF Plug-ins that are installed on');
  });
});
