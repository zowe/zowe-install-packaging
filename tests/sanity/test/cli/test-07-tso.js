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
const { execZoweCli, defaultUSSProfileName, defaultTSOProfileName, createDefaultUSSProfile, createDefaultTSOProfile } = require('./utils');

let acctNum;

describe('cli runs tso commands', function() {
  before('verify environment variables', async function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.SSH_PORT, 'SSH_PORT is not defined').to.not.be.empty;

    const ussprofile = await createDefaultUSSProfile(
      process.env.SSH_HOST,
      process.env.SSH_USER,
      process.env.SSH_PASSWD,
      process.env.SSH_PORT,
    );

    debug('result:', ussprofile);

    expect(ussprofile).to.have.property('stdout');
    expect(ussprofile).to.have.property('stderr');

    expect(ussprofile.stderr).to.be.empty;
    expect(ussprofile.stdout).to.have.string('Profile created successfully');

    acctNum = await exec('zowe zos-uss issue ssh "tsocmd \'lu ibmuser noracf tso\' && exit 0" --ssh-profile ' + defaultUSSProfileName + ' | grep "ACCTNUM" | cut -f2 -d "=" | tr -d " \t\r\n"');

    expect(acctNum).to.have.property('stdout');
    expect(acctNum).to.have.property('stderr');

    expect(acctNum.stderr).to.be.empty;
    expect(acctNum.stdout).to.not.be.empty;

    const tsoprofile = await createDefaultTSOProfile(
      acctNum.stdout,
    );

    debug('result:', tsoprofile);

    expect(tsoprofile).to.have.property('stdout');
    expect(tsoprofile).to.have.property('stderr');

    expect(tsoprofile.stderr).to.be.empty;
    expect(tsoprofile.stdout).to.have.string('Profile created successfully');
  });

  it('returns the status of current running jobs', async function() {
    const result = await execZoweCli('zowe zos-tso issue command "status" --a '+ acctNum.stdout + ' --tso-profile ' + defaultTSOProfileName);

    debug('result:', result);
    // addContext(this, {
    //   title: 'cli result',
    //   value: result
    // });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    expect(result.stdout).to.have.string('LOGON IN PROGRESS');
  });
});
