/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2019
 */

const path = require('path');
const expect = require('chai').expect;
const debug = require('debug')('test:e2e:react-sample');
const addContext = require('mochawesome/addContext');
const testName = path.basename(__filename, path.extname(__filename));
const {
  saveScreenshot,
  getDefaultDriver,
  getElement,
  waitUntilElement,
  loginMVD,
  launchApp,
  locateApp,
} = require('./utils');
let driver;

const APP_TO_TEST = 'Sample React App';
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

    // wait for caption is loaded
    const caption = await waitUntilElement(driver, 'rs-com-mvd-window .heading .caption');
    expect(caption).to.be.an('object');
    debug('caption is ready');
    const captionTest = await caption.getText();
    expect(captionTest).to.be.equal(APP_TO_TEST);
    debug('app caption checked ok');

    // wait for caption is loaded
    const viewport = await waitUntilElement(driver, 'rs-com-mvd-window .body com-rs-mvd-viewport');
    expect(viewport).to.be.an('object');
    debug('app viewport is ready');

    // wait for page is loaded
    const canvas = await waitUntilElement(driver, 'ng-component', viewport);
    expect(canvas).to.be.an('object');
    debug('app is fully loaded');

    // save screenshot
    const file2 = await saveScreenshot(driver, testName, 'app-loaded');
    addContext(this, file2);

    appLaunched = true;
  });

  it(`should be able to launch "${APP_NAME_TO_LAUNCH}" app`, async function() {
    if (!appLaunched) {
      this.skip();
    }

    // check app id
    const appNameInput = await getElement(driver, 'input');
    expect(appNameInput).to.be.an('object');
    const appNameInputValue = await appNameInput.getAttribute('value');
    debug(`input appId value is: ${appNameInputValue}`);
    expect(appNameInputValue).to.be.equal(APP_ID_TO_LAUNCH);

    // click on "Send App Request" button
    const appButton = await getElement(driver, 'button');
    expect(appButton).to.be.an('object');
    const appButtonText = await appButton.getText();
    debug(`send request button text is: ${appButtonText}`);
    expect(appButtonText).to.be.equal('Send App Request');
    await appButton.click();
    debug('"Send App Request" button clicked');

    const app = await locateApp(driver, APP_NAME_TO_LAUNCH);
    expect(app).to.be.an('object');
    await driver.sleep(10000);
    debug('app launched');

    // save screenshot
    const file3 = await saveScreenshot(driver, testName, 'test-app-launched');
    addContext(this, file3);
  });

  after('quit webdriver', async function() {
    // quit webdriver
    if (driver) {
      await driver.quit();
    }
  });
});
