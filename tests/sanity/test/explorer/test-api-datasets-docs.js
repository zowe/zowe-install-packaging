/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2019
 */

const _ = require('lodash');
const expect = require('chai').expect;
const debug = require('debug')('test:explorer:docs');
const axios = require('axios');
const addContext = require('mochawesome/addContext');

let REQ;

// allow self signed certs
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

describe('test explorer server docs', function() {
  before('verify environment variables', function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.ZOWE_EXPLORER_DATASETS_PORT, 'ZOWE_EXPLORER_DATASETS_PORT is not defined').to.not.be.empty;

    REQ = axios.create({
      baseURL: `https://${process.env.SSH_HOST}:${process.env.ZOWE_EXPLORER_DATASETS_PORT}`,
      timeout: 30000,
    });
    debug(`Explorer server URL: https://${process.env.SSH_HOST}:${process.env.ZOWE_EXPLORER_DATASETS_PORT}`);
  });

  it('should be able to access Swagger UI (/swagger-ui.html)', function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/swagger-ui.html',
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
        expect(res.data).to.include('<html ');
        expect(res.data).to.include('<title>Swagger UI</title>');
      });
  });

  it('should be able to access Swagger JSON file (/v2/api-docs)', function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/v2/api-docs',
      params: {
        compact: 'true',
        displayPorts: 'true',
      },
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
        expect(res.data).to.nested.include({
          'swagger': '2.0',
        });
        expect(res.data).to.have.nested.property('paths./api/v1/datasets');
        expect(res.data).to.have.nested.property('paths./api/v1/datasets/username');
        expect(res.data).to.have.nested.property('paths./api/v1/datasets/{filter}');
      });
  });

});
