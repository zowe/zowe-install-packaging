/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

function exec(a, options) {
    return 0;
}

var O_CREAT = 0;
var O_WRONLY = 0;
var O_RDONLY = 0;
var S_IFMT = 0;
var S_IFIFO = 0;
var S_IFCHR = 0;
var S_IFDIR = 0;
var S_IFBLK = 0;
var S_IFREG = 0;
var S_IFSOCK = 0;
var S_IFLNK = 0;
var S_IFGID = 0;
var S_IFUID = 0;
var ENOENT = 0;

var SIGINT = 0;
var SIGABRT = 0;
var SIGFPE = 0;
var SIGILL = 0;
var SIGSEGV = 0;
var SIGTERM = 0;

function open(filename, flags, mode) {
    return 0;
}
function close(fd) {
    return 0;
}
function read(fd, buffer, offset, length) {
    return 0;
}
function write(fd, buffer, offset, length) {
    return 0;
}

function remove(filename) {
    return 0;
}
function rename(oldname, newname) {
    return 0;
}

function stat(path) {
    return [{
        mode: 0
    }, 0];
}
function lstat(path){
    return [null, 0];
}

function signal(signal, fun) {

}
function kill(pid, signal) {

}
function waitpid(pid, options) {
    return [0, 0];
}

function readdir(path){
    return [[''], 0];
}
function realpath(path){
    return ['', 0];
}
function getcwd() {
    return ['', 0];
}
function chdir(path) {
    return 0;
}

function symlink(target, linkpath) {
    return 0;
}
function mkdir(path, mode) {
    return 0;
}
function dup2(oldfd, newfd) {
}
function sleep(millis) {
}
function pipe() {
    return null;
}

var platform = "test";

exports.exec = exec;
exports.open = open;
exports.close = close;
exports.read = read;
exports.write = write;
exports.remove = remove;
exports.rename = rename;
exports.stat = stat;
exports.lstat = lstat;
exports.signal = signal;
exports.kill = kill;
exports.waitpid = waitpid;
exports.readdir = readdir;
exports.realpath = realpath;
exports.getcwd = getcwd;
exports.chdir = chdir;
exports.symlink = symlink;
exports.mkdir = mkdir;
exports.dup2 = dup2;
exports.sleep = sleep;
exports.pipe = pipe;
