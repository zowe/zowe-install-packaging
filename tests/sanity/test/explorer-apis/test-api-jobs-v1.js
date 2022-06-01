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
const { HTTPRequest, HTTP_STATUS } = require('../http-helper');
const { ZOWE_JOB_NAME } = require('../constants');

describe('test explorer server jobs api', function() {

  let hq;

  before('verify environment variables', function() {
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;

    hq = new HTTPRequest(null, null, null, {
      username: process.env.SSH_USER,
      password: process.env.SSH_PASSWD,
    });
  });

  it(`should be able to list jobs and have a job ${ZOWE_JOB_NAME}`, async function() {
    const res = await hq.request({
      url: '/jobs/api/v1',
      params: {
        prefix: `${ZOWE_JOB_NAME}*`,
        owner: 'ZWE*',
        status: 'ACTIVE',
      },
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data.items).to.be.an('array');
    expect(res.data.items).to.have.lengthOf(1);
    expect(res.data.items[0]).to.have.any.keys('jobName', 'jobId', 'owner', 'status', 'type', 'subsystem');
    expect(res.data.items[0].jobName).to.equal(ZOWE_JOB_NAME);
  });

  it(`should be able to list jobs and have a job ${ZOWE_JOB_NAME} (manual decompress)`, async function() {
    const res = await hq.request({
      url: '/jobs/api/v1',
      params: {
        prefix: `${ZOWE_JOB_NAME}*`,
        owner: 'ZWE*',
        status: 'ACTIVE',
      },
    }, {
      manualDecompress: true,
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data.items).to.be.an('array');
    expect(res.data.items).to.have.lengthOf(1);
    expect(res.data.items[0]).to.have.any.keys('jobName', 'jobId', 'owner', 'status', 'type', 'subsystem');
    expect(res.data.items[0].jobName).to.equal(ZOWE_JOB_NAME);
  });

  it('returns the current user\'s TSO userid', async function() {
    const res = await hq.request({
      url: '/jobs/api/v1/username',
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data).to.be.an('object');
    expect(res.data).to.have.property('username');
    expect(res.data.username).to.be.a('string');
  });
});
