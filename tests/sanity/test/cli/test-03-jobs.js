/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

/*eslint no-console: ["error", { allow: ["log", "warn", "error"] }] */

const expect = require('chai').expect;
const debug = require('debug')('test:cli:jobs');
const addContext = require('mochawesome/addContext');
const { execZoweCli, defaultZOSMFProfileName, createDefaultZOSMFProfile } = require('./utils');
const { ZOWE_JOB_NAME } = require('../constants');
let testJobId;

describe('cli list jobs of ZWE*', function() {
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

  it(`should have an active job ${ZOWE_JOB_NAME}`, async function() {
    const result = await execZoweCli(`zowe zos-jobs list jobs --owner 'ZWE*' --prefix '${ZOWE_JOB_NAME}*' --response-format-json --zosmf-profile ${defaultZOSMFProfileName}`);

    debug('result:', result);
    addContext(this, {
      title: 'cli result',
      value: result
    });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    const res = JSON.parse(result.stdout);
    expect(res).to.be.an('object');
    expect(res.success).to.be.true;
    expect(res.data).to.be.an('array');

    const activeZoweJobs = res.data.filter(item => item.jobname === ZOWE_JOB_NAME && item.status === 'ACTIVE');
    expect(activeZoweJobs).to.be.an('array').that.have.lengthOf(1);
    testJobId = activeZoweJobs[0].jobid;
    expect(testJobId).to.be.a('string');
  });

  it('should be able to view job details', async function() {
    if (!testJobId) {
      debug('test skipped due to job id is missing');
      this.skip();
      return;
    }

    const result = await execZoweCli(`zowe zos-jobs view job-status-by-jobid ${testJobId} --response-format-json --zosmf-profile ${defaultZOSMFProfileName}`);

    debug('result:', result);
    addContext(this, {
      title: 'cli result',
      value: result
    });

    expect(result).to.have.property('stdout');
    expect(result).to.have.property('stderr');

    expect(result.stderr).to.be.empty;
    const res = JSON.parse(result.stdout);
    expect(res).to.be.an('object');
    expect(res.success).to.be.true;
    expect(res.data).to.be.an('object');
    expect(res.data.jobname).to.be.equal(ZOWE_JOB_NAME);
    expect(res.data.status).to.be.equal('ACTIVE');
  });
});
