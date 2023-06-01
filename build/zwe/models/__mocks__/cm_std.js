/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

const environment = new Map();

function getenv(varName) {
    return environment.get(varName);
}

function setenv(varName, value) {
    environment.set(varName, value);
}

function unsetenv(varName) {
    environment.delete(varName);
}

/**
   really key-value pairs, but no strong type for return yet 
*/
function getenviron() {
    return environment;
}

function exit(status) {

}

function loadFile(filename) {
    return null;
}

function fdopen(fd, fopenMode, errorObj) {
    return null;
}
function open(command, fopenMode, errorObj) {
    return null;
}
function popen(command, fopenMode, errorObj) {
    return null;
}

/* STDOUT convenience functions */
function puts(s) {

}
function printf(formatString, args) {

}

/* builds a new string */
function sprintf(formatString, args) {

}

function parseExtJSON(s) {

}

var out = null;
var err = null;
var frog = null;

var Error = null;

exports.getenv = getenv;
exports.setenv = setenv;
exports.unsetenv = unsetenv;
exports.getenviron = getenviron;
exports.exit = exit;
exports.loadFile = loadFile;
exports.fdopen = fdopen;
exports.open = open;
exports.popen = popen;
exports.puts = puts;
exports.printf = printf;
exports.sprintf = sprintf;
exports.parseExtJSON = parseExtJSON;

setenv('ZWE_CLI_PARAMETER_CONFIG', './test-zowe.yaml');
