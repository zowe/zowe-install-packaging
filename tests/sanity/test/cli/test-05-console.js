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
const debug = require('debug')('zowe-sanity-test:cli:console');
// const addContext = require('mochawesome/addContext');
const { execZoweCli, defaultZOSMFProfileName, createDefaultZOSMFProfile } = require('./utils');

describe('cli console', function() {
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

    try {
      // Temporary Fix for random TSO/E address space failure
      result = await execZoweCli(`zowe zos-console issue command "D IPLINFO" --zosmf-profile ${defaultZOSMFProfileName}`);
    }
    catch(error) {
      // Do Nothing
    }
  });

  it('command should return the IPL information for the system', async function() {
    const result = await execZoweCli(`zowe zos-console issue command "D IPLINFO" --zosmf-profile ${defaultZOSMFProfileName}`);

    debug('result:', result);
    // addContext(this, {
    //   title: 'cli result',
    //   value: result
    // });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    expect(result.stdout).to.include('IPLINFO DISPLAY');
    expect(result.stdout).to.include('SYSTEM IPLED AT');
    expect(result.stdout).to.include('RELEASE z/OS');
    expect(result.stdout).to.include('IEASYM LIST');
    expect(result.stdout).to.include('IEASYS LIST');
    expect(result.stdout).to.include('IODF DEVICE:');
    expect(result.stdout).to.include('IPL DEVICE:');
  });

  it('command should return the universal time and date', async function() {
    const result = await execZoweCli(`zowe zos-console issue command "D T" --zosmf-profile ${defaultZOSMFProfileName}`);

    debug('result:', result);
    // addContext(this, {
    //   title: 'cli result',
    //   value: result
    // });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    expect(result.stdout).to.match(/LOCAL: TIME=\d{2}.\d{2}.\d{2} DATE=\d{4}.\d{3}/);
    expect(result.stdout).to.match(/UTC: TIME=\d{2}.\d{2}.\d{2} DATE=\d{4}.\d{3}/);
  });
});
