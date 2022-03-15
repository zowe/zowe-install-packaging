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
const { HTTPRequest, HTTP_STATUS, APIMLAuth } = require('../http-helper');
const {
  APIML_AUTH_COOKIE,
  ZOWE_JOB_NAME,
} = require('../constants');

describe('test explorer server jobs api v2', function() {

  let hq;
  let apiml;
  let token;

  before('verify environment variables', async function() {
    hq = new HTTPRequest();
    apiml = new APIMLAuth(hq);
    token = await apiml.login();
  });

  it(`should be able to list jobs and have a job ${ZOWE_JOB_NAME} (v2 API)`, async function() {
    const res = await hq.request({
      url:'/jobs/api/v2',
      params: {
        prefix: `${ZOWE_JOB_NAME}*`,
        owner: 'ZWE*',
        status: 'ACTIVE',
      },
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      }
    });

    expect(res).to.have.property('status');
    expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    expect(res.data.items).to.be.an('array');
    expect(res.data.items).to.have.lengthOf(1);
    expect(res.data.items[0]).to.have.any.keys('jobName', 'jobId', 'owner', 'status', 'type', 'subsystem');
    expect(res.data.items[0].jobName).to.equal(ZOWE_JOB_NAME);
  });

  it(`should be able to list jobs and have a job ${ZOWE_JOB_NAME} (v2 API) (manual decompress)`, async function() {
    const res = await hq.request({
      url:'/jobs/api/v2',
      params: {
        prefix: `${ZOWE_JOB_NAME}*`,
        owner: 'ZWE*',
        status: 'ACTIVE',
      },
      headers: {
        Cookie: `${APIML_AUTH_COOKIE}=${token}`,
      }
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
});
