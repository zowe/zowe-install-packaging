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
const debug = require('debug')('zowe-sanity-test:explorer:api-uss');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

let REQ, username, password;

describe('test explorer server uss files api', function() {
  before('verify environment variables', function() {
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ROOT_DIR, 'ZOWE_ROOT_DIR is not defined').to.not.be.empty;
    expect(process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;

    REQ = axios.create({
      baseURL: `https://${process.env.SSH_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`,
      timeout: 30000,
    });

    username = process.env.SSH_USER;
    password = process.env.SSH_PASSWD;

    debug(`Explorer server URL: https://${process.env.SSH_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`);
  });

  it(`should be able to list content of directory ${DIR_TO_TEST}`, function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/api/v1/uss/files/' + encodeURIComponent(testDir + '/' + DIR_TO_TEST),
      auth: {
        username,
        password,
      }
    };
    debug('request', req);

    debug(`Explorer server URL: https://${process.env.SSH_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`);
  });

  it('Gets a list of files and directories for a given path', function() {
    const _this = this;

    const req = {
      method: 'get',
      url: `/api/v1/unixfiles?path=${process.env.ZOWE_INSTANCE_DIR}`,
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
        expect(res.data).to.be.an('object');
        expect(res.data).to.have.property('type');
        expect(res.data.type).to.be.a('string');
        expect(res.data).to.have.property('owner');
        expect(res.data.owner).to.be.a('string');
        expect(res.data).to.have.property('group');
        expect(res.data.group).to.be.a('string');
        expect(res.data).to.have.property('permissionsSymbolic');
        expect(res.data.permissionsSymbolic).to.be.a('string');
      });
  });
});
