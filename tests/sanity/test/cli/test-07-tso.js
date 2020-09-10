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
const debug = require('debug')('zowe-sanity-test:cli:tso');
// const addContext = require('mochawesome/addContext');
const util = require('util');
const exec = util.promisify(require('child_process').exec);
const { execZoweCli, defaultZOSMFProfileName, createDefaultZOSMFProfile } = require('./utils');

describe('cli runs tso commands', function() {
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

  it('returns the status of current running jobs', async function() {
    const acctNum = await exec(`zowe zos-uss issue ssh "tsocmd 'lu ibmuser noracf tso' && exit 0" | grep "ACCTNUM" | cut -f2 -d "=" | tr -d " \t\r\n"`);

    expect(acctNum).to.have.property('stdout');
    expect(acctNum).to.have.property('stderr');

    expect(acctNum.stderr).to.be.empty;
    expect(acctNum.stdout).to.not.be.empty;

    const result = await execZoweCli('zowe zos-tso issue command "status" --a '+ acctNum.stdout);

    debug('result:', result);
    // addContext(this, {
    //   title: 'cli result',
    //   value: result
    // });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    expect(result.stdout).to.have.string('This System is Running');
  });
});
