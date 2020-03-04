/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const _ = require('lodash');
const expect = require('chai').expect;
const debug = require('debug')('test:explorer:api-jobs');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

const { ZOWE_JOB_NAME } = require('../constants');

let REQ, username, password;

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

describe('test explorer server jobs api', function() {
  before('verify environment variables', function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;

    REQ = axios.create({
      baseURL: `https://${process.env.SSH_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`,
      timeout: 30000,
    });
    username = process.env.SSH_USER;
    password = process.env.SSH_PASSWD;
    debug(`Explorer server URL: https://${process.env.SSH_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`);
  });

  it(`should be able to list jobs and have a job ${ZOWE_JOB_NAME}`, function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/api/v1/jobs',
      params: {
        prefix: `${ZOWE_JOB_NAME}*`,
        owner: 'ZWE*',
        status: 'ACTIVE',
      },
      auth: {
        username,
        password,
      }
    };
    debug('request', req);

    return REQ.request(req)
      .then(function(res) {
        debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
        addContext(_this, {
          title: 'http response',
          value: res && res.data
        });

        expect(res).to.have.property('status');
        expect(res.status).to.equal(200);
        expect(res.data.items).to.be.an('array');
        expect(res.data.items).to.have.lengthOf(1);
        expect(res.data.items[0]).to.have.any.keys('jobName', 'jobId', 'owner', 'status', 'type', 'subsystem');
        expect(res.data.items[0].jobName).to.equal(ZOWE_JOB_NAME);
      });
  });
});
