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
const {
  HTTPRequest,
  HTTP_STATUS,
  // APIMLAuth,
  ZluxAuth,
} = require('../http-helper');
const { APIML_AUTH_COOKIE } = require('../constants');

describe(`test zLux server https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}`, function() {

  let zluxHost;
  let zluxBaseUrl;
  let hqZlux;
  let zlux;
  let apimlHost;
  let apimlBaseUrl;
  let hqApiml;
  // let apiml;
  let token;

  before('verify environment variables', async function() {
    zluxHost = `${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}`;
    zluxBaseUrl = `https://${zluxHost}`;
    hqZlux = new HTTPRequest(zluxBaseUrl, null, { 'Content-Type': 'application/json' });
    zlux = new ZluxAuth(hqZlux);
    apimlHost = `${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`;
    apimlBaseUrl = `https://${apimlHost}`;
    hqApiml = new HTTPRequest(apimlBaseUrl, null, { 'Content-Type': 'application/json' });
    // apiml = new APIMLAuth(hqApiml);
    token = await zlux.login();
  });

  describe('GET /', function() {
    it(`should redirect to https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}/zlux/ui/v1/`, async function() {
      const res = await hqZlux.request({
        url: '/',
        maxRedirects: 0,
      });
      console.log('zlux:', res);
      expect(res).to.have.property('status');
      expect(res.status).to.equal(HTTP_STATUS.REDIRECT);
      expect(res).to.have.property('headers');
      expect(res.headers).to.have.property('location');
      expect(res.headers.location).to.equal(`https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}/zlux/ui/v1/`);
    });

    it('should return ok', async function() {
      const res = await hqZlux.request({
        url: '/',
      });

      expect(res).to.have.property('status');
      expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
      // has been renamed to Zowe Desktop
      expect(res.data).to.match(/(Mainframe Virtual Desktop|Zowe Desktop)/);
    });
  });

  describe('GET /ZLUX/plugins', function() {
    it('/org.zowe.explorer-jes/web/index.html is an unprotected path', async function() {
      const res = await hqZlux.request({
        method: 'get',
        url: '/ZLUX/plugins/org.zowe.explorer-jes/web/index.html',
      });

      expect(res).to.have.property('status');
      expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    });

    it('/org.zowe.explorer-mvs/web/index.html should return ok', async function() {
      const res = await hqZlux.request({
        method: 'get',
        url: '/ZLUX/plugins/org.zowe.explorer-mvs/web/index.html',
        headers: {
          Cookie: `${APIML_AUTH_COOKIE}=${token}`,
        }
      });

      expect(res).to.have.property('status');
      expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    });

    it('/org.zowe.explorer-uss/web/index.html should return ok', async function() {
      const res = await hqZlux.request({
        method: 'get',
        url: '/ZLUX/plugins/org.zowe.explorer-uss/web/index.html',
        headers: {
          Cookie: `${APIML_AUTH_COOKIE}=${token}`,
        }
      });

      expect(res).to.have.property('status');
      expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
    });
  });

  describe('GET ZLUX Logger and Iframe Adapter', function() {
    it('GET /zlux/ui/v1/ZLUX/plugins/org.zowe.zlux.bootstrap/web/iframe-adapter.js', async function() {
      const res = await hqApiml.request({
        method: 'get',
        url: '/zlux/ui/v1/ZLUX/plugins/org.zowe.zlux.bootstrap/web/iframe-adapter.js',
      });

      expect(res).to.have.property('status');
      expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
      expect(res).to.have.property('data');
      expect(JSON.stringify(res.data)).contains('ZoweZLUX.iframe');
    });

    it('GET /zlux/ui/v1/lib/org.zowe.zlux.logger/0.9.0/logger.js', async function() {
      const res = await hqApiml.request({
        method: 'get',
        url: '/zlux/ui/v1/lib/org.zowe.zlux.logger/0.9.0/logger.js',
      });

      expect(res).to.have.property('status');
      expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
      expect(res).to.have.property('data');
      expect(JSON.stringify(res.data)).contains('exports.Logger');
    });
  });

  describe('GET ZLUX & ZSS swagger docs', function() {
    it('GET ZLUX Swagger', async function() {
      const res = await hqApiml.request({
        method: 'get',
        url: '/zlux/ui/v1/ZLUX/plugins/org.zowe.zlux/catalogs/swagger',
      });

      expect(res).to.have.property('status');
      expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
      expect(res).to.have.property('data');

      expect(res.data).to.have.keys('info', 'paths','host', 'basePath', 'schemes', 'swagger');
      expect(res.data.host.toUpperCase()).equal(zluxHost.toUpperCase());
      expect(res.data.info.title).equal('org.zowe.zlux');
      expect(res.data.paths).to.have.property('/server/environment');
    });
  
    it('GET ZSS Swagger', async function() {
      const res = await hqApiml.request({
        method: 'get',
        url: '/zlux/ui/v1/ZLUX/plugins/org.zowe.zlux.agent/catalogs/swagger',
      });
  
      expect(res).to.have.property('status');
      expect(res.status).to.equal(HTTP_STATUS.SUCCESS);
      expect(res).to.have.property('data');
      expect(res.data).to.have.keys('info', 'paths','host', 'basePath', 'schemes', 'swagger');
      expect(res.data.info.title).equal('org.zowe.zlux.agent');
      expect(res.data.paths).to.have.property('/server/agent/environment');
    });
  });
});
