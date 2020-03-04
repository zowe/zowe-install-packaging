/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const path = require('path');
const expect = require('chai').expect;
const debug = require('debug')('test:e2e:iframe');
const addContext = require('mochawesome/addContext');
const testName = path.basename(__filename, path.extname(__filename));
const {
  MVD_IFRAME_APP_CONTEXT,
  saveScreenshot,
  getDefaultDriver,
  getElement,
  waitUntilElement,
  waitUntilIframe,
  loginMVD,
  launchApp,
  locateApp,
  saveScreenshotWithIframeAppContext,
} = require('./utils');
let driver;

const APP_TO_TEST = 'IFrame Sample';
const APP_ID_TO_LAUNCH = 'org.zowe.terminal.tn3270';
const APP_NAME_TO_LAUNCH = 'TN3270';

let appLaunched = false;

describe(`test ${APP_TO_TEST}`, function() {
  before('verify environment variable and load login page', async function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ZLUX_HTTPS_PORT, 'ZOWE_ZLUX_HTTPS_PORT is not defined').to.not.be.empty;

    // init webdriver
    driver = await getDefaultDriver();
    debug('webdriver initialized');

    // load MVD login page
    await loginMVD(
      driver,
      `https://${process.env.SSH_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}/`,
      process.env.SSH_USER,
      process.env.SSH_PASSWD
    );
  });


  it('should launch app correctly', async function() {
    // load app
    await launchApp(driver, APP_TO_TEST);
    const app = await locateApp(driver, APP_TO_TEST);
    expect(app).to.be.an('object');
    debug('app launched');

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'app-loading');
    addContext(this, file);

    // locate app iframe
    const iframe = await waitUntilIframe(driver, 'rs-com-mvd-iframe-component > iframe', app);
    expect(iframe).to.be.an('object');
    debug('app iframe found');

    // wait for page is loaded
    const appTitle = await waitUntilElement(driver, 'div.bottom-10 div.iframe-desktop-mode div.dataservice-test-panel textarea');
    expect(appTitle).to.be.an('object');
    debug('page is fully loaded');

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'app-loaded', APP_TO_TEST, MVD_IFRAME_APP_CONTEXT);

    appLaunched = true;
  });

  it(`should be able to launch "${APP_NAME_TO_LAUNCH}" app`, async function() {
    if (!appLaunched) {
      this.skip();
    }

    // check app id
    const appNameInput = await getElement(driver, 'div.div-input input[name=appId]');
    expect(appNameInput).to.be.an('object');
    const appNameInputValue = await appNameInput.getAttribute('value');
    debug(`input appId value is: ${appNameInputValue}`);
    expect(appNameInputValue).to.be.equal(APP_ID_TO_LAUNCH);

    // click close "Iframe Plugin requests" accordion
    const accordionRequests = await getElement(driver, 'div.bottom-10 > button.iframe-accordion');
    expect(accordionRequests).to.be.an('object');
    const accordionRequestsText = await accordionRequests.getText();
    debug(`send request button text is: ${accordionRequestsText}`);
    expect(accordionRequestsText).to.be.equal('Iframe Plugin requests:');
    await accordionRequests.click();
    debug('"Iframe Plugin requests:" button clicked');

    // click open "App to App interaction:" accordion
    const accordionApp2App = await getElement(driver, 'div.bottom-10 div.iframe-desktop-mode button.iframe-accordion');
    expect(accordionApp2App).to.be.an('object');
    const accordionApp2AppText = await accordionApp2App.getText();
    debug(`send request button text is: ${accordionApp2AppText}`);
    expect(accordionApp2AppText).to.be.equal('App to App interaction:');
    await accordionApp2App.click();
    debug('"App to App interaction:" button clicked');

    // click on "Send App Request" button
    const appButton = await getElement(driver, 'div.bottom-10 div.iframe-desktop-mode div.panel button.iframe-button');
    expect(appButton).to.be.an('object');
    const appButtonText = await appButton.getText();
    debug(`send request button text is: ${appButtonText}`);
    expect(appButtonText).to.be.equal('Send App request');
    await appButton.click();
    debug('"Send App Request" button clicked');

    const app = await locateApp(driver, APP_NAME_TO_LAUNCH);
    expect(app).to.be.an('object');
    await driver.sleep(10000);
    debug('app launched');

    // save screenshot
    await saveScreenshotWithIframeAppContext(this, driver, testName, 'test-app-launched', APP_TO_TEST, MVD_IFRAME_APP_CONTEXT);
  });

  after('quit webdriver', async function() {
    // quit webdriver
    if (driver) {
      await driver.quit();
    }
  });
});
