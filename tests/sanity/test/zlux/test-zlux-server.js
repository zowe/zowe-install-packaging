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
const debug = require('debug')('zowe-sanity-test:install:explore-server');
const axios = require('axios');
const addContext = require('mochawesome/addContext');
const {zluxAuth} = require('./utils');

let REQ, REQ_APIML, zluxBaseUrl, apimlBaseUrl, apimlAuthCookie, zluxHost, apimlHost, zssHost;

describe(`test zLux server https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}`, function() {

  before('verify environment variables', async function() {
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    expect(process.env.ZOWE_EXTERNAL_HOST, 'ZOWE_EXTERNAL_HOST is empty').to.not.be.empty;
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ZLUX_HTTPS_PORT, 'ZOWE_ZLUX_HTTPS_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ZSS_PORT, 'ZOWE_ZSS_PORT is not defined').to.not.be.empty;

    zluxHost = `${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}`;
    apimlHost = `${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`;
    zssHost = `${process.env.SSH_HOST}:${process.env.ZOWE_ZSS_PORT}`;
    zluxBaseUrl = `https://${zluxHost}`;
    apimlBaseUrl = `https://${apimlHost}`;
    REQ = axios.create({
      baseURL: zluxBaseUrl,
      timeout: 20000,
      headers: { 'Content-Type': 'application/json' },
    });

    REQ_APIML = axios.create({
      baseURL: apimlBaseUrl,
      timeout: 20000,
      headers: { 'Content-Type': 'application/json' },
    });

    apimlAuthCookie = await zluxAuth(REQ, process.env.SSH_USER, process.env.SSH_PASSWD);
  });

  describe('GET /', function() {
    it('should redirect to ./ZLUX/plugins/org.zowe.zlux.bootstrap/web/', function() {
      const req = {
        method: 'get',
        url: '/',
        maxRedirects: 0,
      };
      debug('request', req);

      return REQ.request(req)
        .catch(function(err) {
          debug('response err', err);

          expect(err).to.have.property('response');
          const res = err.response;
          expect(res).to.have.property('status');
          expect(res.status).to.equal(302);
          expect(res).to.have.property('headers');
          expect(res.headers).to.have.property('location');
          expect(res.headers.location).to.equal('./ZLUX/plugins/org.zowe.zlux.bootstrap/web/');
        });
    });

    it('should return ok', function() {
      const _this = this;

      const req = {
        method: 'get',
        url: '/'
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
          // has been renamed to Zowe Desktop
          expect(res.data).to.match(/(Mainframe Virtual Desktop|Zowe Desktop)/);
        });
    });
  });

  describe('GET /ZLUX/plugins', function() {
    
    it('/org.zowe.explorer-jes/iframe is a protected path needs authentication', function() {
      const _this = this;

      const req = {
        method: 'get',
        url: '/ZLUX/plugins/org.zowe.explorer-jes/iframe',
      };
      debug('request', req);

      return REQ.request(req).catch(function(err) {
        expect(err).to.have.property('response');
        let res = err.response;
        debug('response', _.pick(err.response, ['status', 'statusText', 'headers', 'data']));
        addContext(_this, {
          title: 'http response',
          value: res && res.data
        });

        expect(res).to.have.property('status');
        expect(res.status).to.equal(401);
        expect(res).to.have.property('data');
        expect(res.data).to.have.property('result');
        expect(res.data.result).to.have.property('authenticated');
        expect(res.data.result.authenticated).to.be.false;
        expect(res.data.result).to.have.property('authorized');
        expect(res.data.result.authenticated).to.be.false;
      });
    });

    it('/org.zowe.explorer-jes/iframe should return ok', function() {
      const _this = this;

      const req = {
        method: 'get',
        url: '/ZLUX/plugins/org.zowe.explorer-jes/iframe',
        headers: {
          cookie: apimlAuthCookie
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
          let respStr = JSON.stringify(res.data).toLowerCase();
          expect(respStr).to.contain('zluxiframe');
          expect(respStr).to.contain(`${apimlBaseUrl.toLowerCase()}/ui/v1/explorer-jes`);
        }).catch(function(err) {
          throw err;
        });
    });

    it('/org.zowe.explorer-mvs/iframe should return ok', function() {
      const _this = this;

      const req = {
        method: 'get',
        url: '/ZLUX/plugins/org.zowe.explorer-mvs/iframe',
        headers: {
          cookie: apimlAuthCookie
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
          let respStr = JSON.stringify(res.data).toLowerCase();
          expect(respStr).to.contain('zluxiframe');
          expect(respStr).to.contain(`${apimlBaseUrl.toLowerCase()}/ui/v1/explorer-mvs`);
        }).catch(function(err) {
          throw err;
        });
    });

    it('/org.zowe.explorer-uss/iframe should return ok', function() {
      const _this = this;

      const req = {
        method: 'get',
        url: '/ZLUX/plugins/org.zowe.explorer-uss/iframe',
        headers: {
          cookie: apimlAuthCookie
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
          let respStr = JSON.stringify(res.data).toLowerCase();
          expect(respStr).to.contain('zluxiframe');
          expect(respStr).to.contain(`${apimlBaseUrl.toLowerCase()}/ui/v1/explorer-uss`);
        }).catch(function(err) {
          throw err;
        });
    });
  });

  describe('GET ZLUX Logger and Iframe Adapter', function() {
    it('GET /ui/v1/zlux/ZLUX/plugins/org.zowe.zlux.bootstrap/web/iframe-adapter.js', function() {
      const _this = this;

      const req = {
        method: 'get',
        url: '/ui/v1/zlux/ZLUX/plugins/org.zowe.zlux.bootstrap/web/iframe-adapter.js',
      };
      debug('request', req);

      return REQ_APIML.request(req).then(function(res) {
        debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
        addContext(_this, {
          title: 'http response',
          value: res && res.data
        });

        expect(res).to.have.property('status');
        expect(res.status).to.equal(200);
        expect(res).to.have.property('data');
        expect(JSON.stringify(res.data)).contains('ZoweZLUX.iframe');
      });
    });

    it('GET /ui/v1/zlux/lib/org.zowe.zlux.logger/0.9.0/logger.js', function() {
      const _this = this;

      const req = {
        method: 'get',
        url: '/ui/v1/zlux/lib/org.zowe.zlux.logger/0.9.0/logger.js',
      };
      debug('request', req);

      return REQ_APIML.request(req).then(function(res) {
        debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
        addContext(_this, {
          title: 'http response',
          value: res && res.data
        });

        expect(res).to.have.property('status');
        expect(res.status).to.equal(200);
        expect(res).to.have.property('data');
        expect(JSON.stringify(res.data)).contains('exports.Logger');
      });
    });
    
  });

  describe('GET ZLUX & ZSS swagger docs', function() {
    it('GET ZLUX Swagger', function() {
      const _this = this;
  
      const req = {
        method: 'get',
        url: '/ui/v1/zlux/ZLUX/plugins/org.zowe.zlux/catalogs/swagger',
      };
      debug('request', req);
  
      return REQ_APIML.request(req).then(function(res) {
        debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
        addContext(_this, {
          title: 'http response',
          value: res && res.data
        });
  
        expect(res).to.have.property('status');
        expect(res.status).to.equal(200);
        expect(res).to.have.property('data');

        expect(res.data).to.have.keys('info', 'paths','host', 'basePath', 'schemes', 'swagger');
        expect(res.data.host.toUpperCase()).equal(zluxHost.toUpperCase());
        expect(res.data.info.title).equal('org.zowe.zlux');
        expect(res.data.paths).to.have.property('/server/environment');
      });
    });
  
    it('GET ZSS Swagger', function() {
      const _this = this;
  
      const req = {
        method: 'get',
        url: '/ui/v1/zlux/ZLUX/plugins/org.zowe.zlux.agent/catalogs/swagger',
      };
      debug('request', req);
  
      return REQ_APIML.request(req).then(function(res) {
        debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
        addContext(_this, {
          title: 'http response',
          value: res && res.data
        });
  
        expect(res).to.have.property('status');
        expect(res.status).to.equal(200);
        expect(res).to.have.property('data');
        expect(res.data).to.have.keys('info', 'paths','host', 'basePath', 'schemes', 'swagger');
        expect(res.data.host.toUpperCase()).equal(zssHost.toUpperCase());
        expect(res.data.info.title).equal('org.zowe.zlux.agent');
        expect(res.data.paths).to.have.property('/server/agent/environment');
      });
    });
    
  });
});





