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
const debug = require('debug')('test:e2e:login');
const addContext = require('mochawesome/addContext');
const testName = path.basename(__filename, path.extname(__filename));

const {
  PRE_INSTALLED_APPS,
  PRE_PINNED_APPS,
  DEFAULT_PAGE_LOADING_TIMEOUT,
  DEFAULT_ELEMENT_CHECK_INTERVAL,
  getElements,
  getElement,
  getElementText,
  waitUntilElement,
  saveScreenshot,
  getDefaultDriver,
} = require('./utils');
let driver;

let loginSuccessfully = false;

describe('test MVD login page', function() {

  before('verify environment variable and load login page', async function() {
    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ZLUX_HTTPS_PORT, 'ZOWE_ZLUX_HTTPS_PORT is not defined').to.not.be.empty;

    // init webdriver
    driver = await getDefaultDriver();
    debug('webdriver initialized');

    // load MVD login page
    debug('loading login page');
    await driver.get(`https://${process.env.SSH_HOST}:${process.env.ZOWE_ZLUX_HTTPS_PORT}/`);
    try {
      await driver.wait(
        async() => {
          const loginButton = await getElement(driver, '#\\#loginButton', true);
          if (loginButton) {
            return true;
          }

          await driver.sleep(DEFAULT_ELEMENT_CHECK_INTERVAL); // not too fast
          return false;
        },
        DEFAULT_PAGE_LOADING_TIMEOUT
      );
    } catch (e) {
      // try to save screenshot for debug purpose
      await driver.switchTo().defaultContent();
      const failureSS = await saveScreenshot(driver, testName, 'login-button-missing');
      addContext(this, failureSS);

      const errName = e && e.name;
      if (errName === 'TimeoutError') {
        expect(errName).to.not.equal('TimeoutError');
      } else {
        expect(e).to.be.null;
      }
    }
    debug('login form is ready');
  });


  it('should redirect to login page', async function() {
    await driver.sleep(5000);
    // save screenshot
    const file = await saveScreenshot(driver, testName, 'login');
    addContext(this, file);

    const title = await driver.getTitle();
    debug(`Current MVD title is ${title}`);
    expect(title).to.be.oneOf(['Mainframe Virtual Desktop', 'Zowe Desktop']);
  });


  it('should show error with wrong login password', async function() {
    const loginForm = await getElement(driver, 'form.login-form');
    expect(loginForm).to.be.an('object');
    // fill in login form
    const usernameInput = await getElement(loginForm, 'input#usernameInput');
    expect(usernameInput).to.be.an('object');
    await usernameInput.clear();
    await driver.sleep(2000);
    await usernameInput.sendKeys(process.env.SSH_USER);
    await driver.sleep(2000);
    const passwordInput = await getElement(loginForm, 'input#passwordInput');
    expect(passwordInput).to.be.an('object');
    await passwordInput.clear();
    await driver.sleep(2000);
    await passwordInput.sendKeys('wrong+passdword!');
    await driver.sleep(2000);
    // submit login
    const loginButton = await getElement(driver, '#\\#loginButton');
    expect(loginButton).to.be.an('object');
    await driver.sleep(3000);
    await loginButton.click();
    debug('login button clicked');

    // save screenshot
    const file0 = await saveScreenshot(driver, testName, 'login-wrong-password-submitted');
    addContext(this, file0);

    // wait for login error
    try {
      await driver.wait(
        async() => {
          let result = false;

          let error = await getElementText(driver, 'p.login-error');
          if (error !== false) {
            error = error.trim();
            if (error && error !== '&nbsp;') {
              debug('login error message returned: %s', error);
              result = true;
            }
          }

          await driver.sleep(DEFAULT_ELEMENT_CHECK_INTERVAL); // not too fast
          return result;
        },
        DEFAULT_PAGE_LOADING_TIMEOUT
      );
    } catch (e) {
      // try to save screenshot for debug purpose
      await driver.switchTo().defaultContent();
      const failureSS = await saveScreenshot(driver, testName, 'login-error-incorrect');
      addContext(this, failureSS);

      const errName = e && e.name;
      if (errName === 'TimeoutError') {
        expect(errName).to.not.equal('TimeoutError');
      } else {
        expect(e).to.be.null;
      }
    }
    debug('login done');

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'login-wrong-password-returned');
    addContext(this, file);

    // make sure we got authentication error
    let error = await getElementText(driver, 'p.login-error');
    expect(error).to.be.a('string');
    error = error.trim();
    expect(error).to.match(/authentication\s*failed/i);
  });


  it('should login successfully with correct password', async function() {
    await driver.sleep(5000);
    // save screenshot
    const file0 = await saveScreenshot(driver, testName, 'before-login');
    addContext(this, file0);

    const loginForm = await getElement(driver, 'form.login-form');
    expect(loginForm).to.be.an('object');
    // fill in login form
    const usernameInput = await getElement(loginForm, 'input#usernameInput');
    expect(usernameInput).to.be.an('object');
    await usernameInput.clear();
    await driver.sleep(2000);
    await usernameInput.sendKeys(process.env.SSH_USER);
    await driver.sleep(2000);
    const passwordInput = await getElement(loginForm, 'input#passwordInput');
    expect(passwordInput).to.be.an('object');
    await passwordInput.clear();
    await driver.sleep(2000);
    await passwordInput.sendKeys(process.env.SSH_PASSWD);
    await driver.sleep(2000);
    // submit login
    const loginButton = await getElement(driver, '#\\#loginButton');
    expect(loginButton).to.be.an('object');
    await driver.sleep(3000);
    await loginButton.click();
    debug('login button clicked');
    // wait for login error or successfully
    try {
      await driver.wait(
        async() => {
          let result = false;

          let error = await getElementText(driver, 'p.login-error');
          if (error !== false) {
            error = error.trim();
            if (error && error !== '&nbsp;') {
              debug('login error message returned: %s', error);
              // authentication failed, no need to wait anymore
              result = true;
            }
          }

          if (!result) {
            const loginPanel = await getElement(driver, 'div.login-panel', false);
            const isDisplayed = await loginPanel.isDisplayed();
            if (!isDisplayed) {
              debug('login panel is hidden, login should be successfully');
              result = true;
            }
          }

          await driver.sleep(DEFAULT_ELEMENT_CHECK_INTERVAL); // not too fast
          return result;
        },
        DEFAULT_PAGE_LOADING_TIMEOUT
      );
    } catch (e) {
      // try to save screenshot for debug purpose
      await driver.switchTo().defaultContent();
      const failureSS = await saveScreenshot(driver, testName, 'login-failed');
      addContext(this, failureSS);

      const errName = e && e.name;
      if (errName === 'TimeoutError') {
        expect(errName).to.not.equal('TimeoutError');
      } else {
        expect(e).to.be.null;
      }
    }
    debug('login done');

    await driver.sleep(10000); // wait a little bit more
    // save screenshot
    const file = await saveScreenshot(driver, testName, 'login-successfully');
    addContext(this, file);

    // make sure we are not hitting login error
    let error = await getElementText(driver, 'p.login-error', false);
    expect(error).to.be.a('string');
    error = error.trim();
    expect(error).to.be.oneOf(['', '&nbsp;']);

    // launchbar should exist
    const launchbar = await getElement(driver, 'rs-com-launchbar');
    expect(launchbar).to.be.an('object');

    // check we have known apps launched
    const apps = await getElements(driver, 'rs-com-launchbar-icon');
    expect(apps).to.be.an('array').that.have.lengthOf(PRE_PINNED_APPS.length);
    // FIXME: ignore the title check now since title has been changed to show plugin description
    // for (let app of apps) {
    //   const icon = await getElement(app, 'div.launchbar-icon-image');
    //   const title = await icon.getAttribute('title');
    //   expect(title).to.be.oneOf(PRE_PINNED_APPS);
    // }

    // mark login succeeded
    loginSuccessfully = true;
  });


  it('should be able to popup apps menu', async function() {
    if (!loginSuccessfully) {
      this.skip();
    }

    // menu should exist
    const menu = await getElement(driver, 'rs-com-launchbar-menu');
    expect(menu).to.be.an('object');
    const menuIcon = await getElement(menu, '.launchbar-menu-icon');
    expect(menuIcon).to.be.an('object');

    // popup menu
    await driver.sleep(3000);
    await menuIcon.click();
    await driver.sleep(1000);

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'apps-menu-popped');
    addContext(this, file);

    // check popup menu existence
    const popup = await getElement(driver, 'rs-com-launchbar-menu .launch-widget-popup');
    expect(popup).to.be.an('object');

    // check popup menu items
    const menuItems = await getElements(popup, '.launch-widget-row > p');
    expect(menuItems).to.be.an('array').that.have.lengthOf(PRE_INSTALLED_APPS.length);
    for (let item of menuItems) {
      const text = await item.getText();
      expect(text).to.be.oneOf(PRE_INSTALLED_APPS);
    }
  });


  it('should be able to logout', async function() {
    if (!loginSuccessfully) {
      this.skip();
    }

    // widget should exist
    const widget = await getElement(driver, 'rs-com-launchbar-widget');
    expect(widget).to.be.an('object');
    const clock = await getElement(widget, '.launchbar-clock');
    expect(clock).to.be.an('object');
    const userIcon = await getElement(widget, '.launchbar-tray-icon.user');
    expect(userIcon).to.be.an('object');

    // popup user info
    await driver.sleep(3000);
    await userIcon.click();
    await driver.sleep(1000);

    // save screenshot
    const file = await saveScreenshot(driver, testName, 'user-info-popped');
    addContext(this, file);

    // check popup menu existence
    const popup = await getElement(widget, '.launchbar-user-popup');
    expect(popup).to.be.an('object');

    // check popup menu
    const usernameText = await getElementText(popup, 'h5');
    expect(usernameText).to.equal(process.env.SSH_USER);

    const signout = await getElement(popup, 'button');
    expect(signout).to.be.an('object');
    const signoutText = await signout.getText();
    expect(signoutText).to.equal('Log out');

    await driver.sleep(3000);
    await signout.click();
    await waitUntilElement(driver, '#\\#loginButton');

    // save screenshot
    const file2 = await saveScreenshot(driver, testName, 'user-logout');
    addContext(this, file2);

    // logged out
    const loginPanel = await getElement(driver, 'div.login-panel');
    expect(loginPanel).to.be.an('object');
  });


  after('quit webdriver', async function() {
    // quit webdriver
    if (driver) {
      await driver.quit();
    }
  });
});
