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
const utils = require('./utils');

const { ZOWE_JOB_NAME } = require('../constants');

let REQ;

describe('test explorer server jobs api', function() {
  before('verify environment variables', function() {
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    // sets up a request variable and retrieves the authentication needed for v2 APIs
    REQ = utils.verifyAndSetupEnvironment();
  });

  it(`should be able to list jobs and have a job ${ZOWE_JOB_NAME} (v2 API)`, async() => {
    const uuid = utils.uuid();
    const authenticationCookie = await utils.login(uuid);

    utils.log(uuid, ' URL: /api/v2/jobs');
    const res = await REQ.get('/api/v2/jobs', {
      params: {
        prefix: `${ZOWE_JOB_NAME}*`,
        owner: 'ZWE*',
        status: 'ACTIVE',
      },
      headers: {
        'Cookie': authenticationCookie,
        'X-CSRF-ZOSMF-HEADER': '*'
      }
    });
    utils.logResponse(uuid, res);

    expect(res).to.have.property('status');
    expect(res.status).to.equal(200);
    expect(res.data.items).to.be.an('array');
    expect(res.data.items).to.have.lengthOf(1);
    expect(res.data.items[0]).to.have.any.keys('jobName', 'jobId', 'owner', 'status', 'type', 'subsystem');
    expect(res.data.items[0].jobName).to.equal(ZOWE_JOB_NAME);
  });
});
