/*
  This program and the accompanying materials are
  made available under the terms of the Eclipse Public License v2.0 which accompanies
  this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/
console.log('js type='+process.env['KEYSTORE_TYPE']);
const { execSync } = require('child_process');
const fs = require('fs-extra');
const yaml = require('yaml');
const path = require('path');
const os = require('os');
const isZos = os.platform() == 'os390';

const TAG_FILES_LOCATION = '../../../scripts/utils';

const types = {
  "zos": 1,
  //aliases since there is uncertainty about zcx being independent or just "container"
  "container": 2,
  "docker": 2,
  "kubernetes": 2,
  "docker-bundle": 3
};

const TYPE_ZOS=1;
const TYPE_CONTAINER=2;
const TYPE_CONTAINER_BUNDLE=3;

const ebcdic1047Toiso819 = [
  0x00, 0x01, 0x02, 0x03, 0x00, 0x09, 0x00, 0x7f, 0x00, 0x00, 0x00, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
  0x10, 0x11, 0x12, 0x13, 0x00, 0x85, 0x08, 0x00, 0x18, 0x19, 0x00, 0x00, 0x1c, 0x1d, 0x1e, 0x1f,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0x17, 0x1b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05, 0x06, 0x07,
  0x00, 0x00, 0x16, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x14, 0x15, 0x00, 0x1a,
  0x20, 0xa0, 0xe2, 0xe4, 0xe0, 0xe1, 0xe3, 0xe5, 0xe7, 0xf1, 0xa2, 0x2e, 0x3c, 0x28, 0x2b, 0x7c,
  0x26, 0xe9, 0xea, 0xeb, 0xe8, 0xed, 0xee, 0xef, 0xec, 0xdf, 0x21, 0x24, 0x2a, 0x29, 0x3b, 0x5e,
  0x2d, 0x2f, 0xc2, 0xc4, 0xc0, 0xc1, 0xc3, 0xc5, 0xc7, 0xd1, 0xa6, 0x2c, 0x25, 0x5f, 0x3e, 0x3f,
  0xf8, 0xc9, 0xca, 0xcb, 0xc8, 0xcd, 0xce, 0xcf, 0xcc, 0x60, 0x3a, 0x23, 0x40, 0x27, 0x3d, 0x22,
  0xd8, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0xab, 0xbb, 0xf0, 0xfd, 0xfe, 0xb1,
  0xb0, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0xaa, 0xba, 0xe6, 0xb8, 0xc6, 0xa4,
  0xb5, 0x7e, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0xa1, 0xbf, 0xd0, 0x5b, 0xde, 0xae,
  0xac, 0xa3, 0xa5, 0xb7, 0xa9, 0xa7, 0xb6, 0xbc, 0xbd, 0xbe, 0xdd, 0xa8, 0xaf, 0x5d, 0xb4, 0xd7,
  0x7b, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0xad, 0xf4, 0xf6, 0xf2, 0xf3, 0xf5,
  0x7d, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f, 0x50, 0x51, 0x52, 0xb9, 0xfb, 0xfc, 0xf9, 0xfa, 0xff,
  0x5c, 0xf7, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0xb2, 0xd4, 0xd6, 0xd2, 0xd3, 0xd5,
  0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0xb3, 0xdb, 0xdc, 0xd9, 0xda, 0x00
];

const commandArgs = process.argv.slice(2);
if (commandArgs.length != 4) {
  console.error(`Usage: Run this from zowe-migrate-instance.sh`);
  process.exit(1);
}

const instanceDir = commandArgs[0];
const outputDir = commandArgs[1];
const toType = types[commandArgs[2]];
const fromType = types[commandArgs[3]];
console.log('keystore='+process.env['KEYSTORE_DIRECTORY']);

if (!process.env['KEYSTORE_TYPE']) {
  console.error(`Could not read KEYSTORE_TYPE env var. Env vars not set correctly for migration tool.`);
  process.exit(1);
}

const WORKSPACE_DIR = path.join(instanceDir, 'workspace');
console.log(`instance=${instanceDir}`);
let outputKeystoreDir = process.env['MIGRATE_KEYSTORE_DIRECTORY'] ? process.env['MIGRATE_KEYSTORE_DIRECTORY'] : path.join(outputDir, 'keystore');
let outputInstanceDir = process.env['MIGRATE_KEYSTORE_DIRECTORY'] ? outputDir : path.join(outputDir, 'instance');
console.log(`output instance=${outputInstanceDir}`);
console.log(`output keystore=${outputKeystoreDir}`);

const KEYSTORE_ENV_FILE = path.join(process.env['KEYSTORE_DIRECTORY'], 'zowe-certificates.env');
const INSTANCE_PATHS = {
  'ROOT_DIR': "/home/zowe/install",
  'JAVA_HOME': "/usr/local/openjdk-8",
  'NODE_HOME':'/usr/local/node',
  'KEYSTORE_DIRECTORY': "/home/zowe/certs"
}

const KEYSTORE_KEYS = ['KEYSTORE', 'TRUSTSTORE', 'KEYSTORE_KEY', 'KEYSTORE_CERTIFICATE', 'KEYSTORE_CERTIFICATE_AUTHORITY'];

const CONVERT_DIR_EXCEPTIONS = [ 'workspace/api-mediation/api-defs' ];

if (toType == fromType) {
  //this may be used to copy-paste duplicate instances in the future?
  console.error(`Error: same type migration not yet implemented`);
  process.exit(2);
}
if (fromType == TYPE_ZOS && toType == TYPE_CONTAINER) {
  migrateZosContainer();
} else if (fromType == TYPE_ZOS && toType == TYPE_CONTAINER_BUNDLE) {
  migrateZosBundle();
} else if (fromType == TYPE_CONTAINER && toType == TYPE_ZOS) {
  migrateContainerZos();
} else if (fromType == TYPE_CONTAINER_BUNDLE && toType == TYPE_ZOS) {
  migrateBundleZos();
} else if (fromType == TYPE_CONTAINER_BUNDLE && toType == TYPE_CONTAINER) {
  migrateBundleContainer();
} else if (fromType == TYPE_CONTAINER && toType == TYPE_CONTAINER_BUNDLE) {
  migrateContainerBundle();
} else {
  console.error(`Error: unimplemented migration from ${fromType} to ${toType}`);
  process.exit(3);
}
console.warn("Path references for 3rd party components are not altered by this tool. Please review third party component documentation if further correction is needed");

function migrateZosContainer() {
  console.error('nyi migrateZosContainer');
  process.exit(1);
}
function migrateContainerZos() {
  console.error('nyi migrateContainerZos');
  process.exit(1);
}
function migrateBundleContainer() {
  console.error(`nyi migrateBundleContainer`);
  process.exit(1);
}
function migrateContainerBundle() {
  console.error(`nyi migrateContainerBundle`);
  process.exit(1);
}

//ebcic -> ascii, keyring check (no support), path updating
function migrateZosBundle() {
  migrateKeystoreZosBundle();

  if (isZos) {
    migrateConfigZosBundle();
    //simple conversion: reading files and writing them will do ebcdic-ascii conversion automatically!
    convertRecursively(path.join(instanceDir, 'workspace'), path.join(outputInstanceDir, 'workspace'), undefined, WORKSPACE_DIR, simpleConvert);
  } else {
    //no tagging info, this is going to be guesswork.
    console.error(`Error: Cannot migrate instance while not on z/OS. Rerun this script on z/OS.`);
    process.exit(4);
  }
}

//ascii -> ebcdic, path updating
//tagfiles except for a few.
function migrateBundleZos() {
  if (isZos) {
    //instance
    let instWithSlash = instanceDir.endsWith('/') ? instanceDir : instanceDir+'/';
    execAndLogErrors(`cp -r ${instWithSlash} ${outputInstanceDir}`);
    tagRecursively(outputInstanceDir, CONVERT_DIR_EXCEPTIONS);
    //updatepaths
    console.log(`Run 'zowe-configure-instance.sh -c "${outputInstanceDir}"' to finalize the migrated instance.`);

    //keystore
    let keystoreWithSlash = process.env['KEYSTORE_DIRECTORY'].endsWith('/') ? process.env['KEYSTORE_DIRECTORY'] : process.env['KEYSTORE_DIRECTORY']+'/';
    execAndLogErrors(`cp -r ${keystoreWithSlash} ${outputKeystoreDir}`);
//  fs.copySync(process.env['KEYSTORE_DIRECTORY'], outputKeystoreDir);
    tagRecursively(outputKeystoreDir, []);
    //updatepaths
  } else {
    //chtag doesnt exist, needs iconv
    console.error(`Error: Cannot migrate instance while not on z/OS. Rerun this script on z/OS.`);
    process.exit(4);
  }
}



function canMigrateKeystore() {
  return process.env['KEYSTORE_TYPE'] == "PKCS12";
}

function migrateKeystoreZosBundle() {
  // ----- at beginning of file is a really good clue this is a text file
  //zowe-certificates.env
  if (!canMigrateKeystore()) {
    console.error(`Keystore type ${process.env['KEYSTORE_TYPE']} is not supported for migration`);
    process.exit(1);
  }
  fs.writeFileSync(path.join(outputKeystoreDir, 'zowe-certificates.env'), fs.readFileSync(KEYSTORE_ENV_FILE,'utf8'));
  convertRecursively(process.env['KEYSTORE_DIRECTORY'], outputKeystoreDir, undefined, WORKSPACE_DIR, certConvert);
  setDockerKeystorePaths();
}

function migrateConfigZosBundle() {
  //migrate instance minus workspace
  convertRecursively(instanceDir, outputInstanceDir, undefined, WORKSPACE_DIR, simpleConvert);
  setDockerInstancePaths();
}

function setDockerKeystorePaths() {
  let keystore = fs.readFileSync(path.join(outputKeystoreDir, 'zowe-certificates.env'), 'utf8');
  let lines = keystore.split('\n');
  let keystoreDir = process.env['KEYSTORE_DIRECTORY'];
  const migrateDir = path.join(outputKeystoreDir, 'migrated');

  for (let i = 0; i < lines.length; i++) {
    let line = lines[i].trim();
    for (let j = 0; j < KEYSTORE_KEYS.length; j++) {
      let key = KEYSTORE_KEYS[j];
      if (line.startsWith(key+'=')) {
        let value=line.substring(key.length+1);
        if (value.startsWith(keystoreDir)) {
          lines[i] = key + '=' + value.replace(keystoreDir, INSTANCE_PATHS.KEYSTORE_DIRECTORY);
        } else {
          //object does not originate in keystore. copy it out
          let filename = path.basename(value);
          let buf = fs.readFileSync(value);
          try {
            fs.mkdirSync(migrateDir);
          } catch (e) {
            if (e.code != 'EEXIST') {
              throw e;
            }
          }

          let destinationPath = path.join(migrateDir, filename);
          if (isTextCert(buf)) {
            fs.writeFileSync(destinationPath, fs.readFileSync(value, 'utf8'));
          } else {
            fs.writeFileSync(destinationPath, buf);
          }
          lines[i] = key + '=' + path.join(INSTANCE_PATHS.KEYSTORE_DIRECTORY, 'migrated', filename);
        }
        break;
      }
    };
  }
  keystore = lines.join('\n');
  fs.writeFileSync(path.join(outputKeystoreDir, 'zowe-certificates.env'), keystore);
}


function setZosInstancePaths(keystoreDir) {
  const nodePath = process.env['_'];
  try { 
    const javaPath = execSync('type java').substring(8); //omit "java is"
  } catch (e) {
    console.error("Java could not be located, migration cannot continue");
    process.exit(5);
  }

}

function setDockerInstancePaths() {
  let instance = fs.readFileSync(path.join(outputInstanceDir, 'instance.env'), 'utf8');
  let lines = instance.split('\n');
  const keys = Object.keys(INSTANCE_PATHS);
  for (let i = 0; i < lines.length; i++) {
    let line = lines[i].trim();
    for (let j = 0; j < keys.length; j++) {
      let key = keys[j];
      if (line.startsWith(key+'=')) {
        lines[i] = key+'='+INSTANCE_PATHS[key];
      }
    };
  }
  instance = lines.join('\n');
  fs.writeFileSync(path.join(outputInstanceDir, 'instance.env'), instance);
}

function isTextCert(buff) {
  const char = buff[0];
  //look for -----, 0x60, 0x2d, 0x05
  return buff.length > 5 && (buff[0] == buff[1]) && (buff[0] == buff[2]) && (buff[0] == buff[3]) && (buff[0] == buff[4]) && (char == 0x05 || char == 0x2d);
}


function certConvert(fullPath, destinationPath, convertMap) {
  const buff = fs.readFileSync(fullPath);
  if (fullPath.endsWith('.p12')){ //p12 is binary, dont convert
    //copy
    fs.writeFileSync(destinationPath, buff);
  } else {
    if (isTextCert(buff)) {
      //likely to be a text file cert or key
      if (!convertMap) {
        fs.writeFileSync(destinationPath, fs.readFileSync(fullPath, 'utf8'));
      } else {
        const content = fs.readFileSync(fullPath);
        for (let i = 0; i < content.length; i++) {
          content[i] = convertMap[i];
        }
        fs.writeFileSync(destinationPath, content);
      }
    } else { //i guess its binary
      console.warn(`file '${fullPath}' not identified as text. first char=${buff[0]}`);
      fs.writeFileSync(destinationPath, buff);
    }

  }
}

function simpleConvert(fullPath, destinationPath, convertMap) {
  if (!convertMap) {
    //TODO make more efficient by streaming buffer
    fs.writeFileSync(destinationPath, fs.readFileSync(fullPath, 'utf8'));
  } else if (convertMap != 'copy') {
    const content = fs.readFileSync(fullPath);
    for (let i = 0; i < content.length; i++) {
      content[i] = convertMap[i];
    }
    fs.writeFileSync(destinationPath, content);
  } else {
    fs.copyFileSync(fullPath, destinationPath);
  }
}

function execAndLogErrors(command) {
  try {
    console.log('exec: ',command);
    execSync(command);
  } catch (e) {
    //stderr seen here but could be warnings instead of errors
    console.warn(e.stderr);
  }
}

function untagInternal(inputPath, exceptions) {
  console.log('checking exceptions=',exceptions);

  exceptions.forEach(function(exception) {
    const fullPath = path.join(inputPath, exception);
    console.log('Checking path=',fullPath);
    try {
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        execAndLogErrors(`chtag -r -R ${fullPath}`);
      } else {
        execAndLogErrors(`chtag -r ${fullPath}`);
      }
    } catch (e) {
      console.error('Path lookup error=',e);
      //doesnt exist? permissions?
    }
  });
}

function tagRecursively(inputPath, exceptions) {
  //tag
  const tagScriptDir = path.isAbsolute(TAG_FILES_LOCATION) ?
        TAG_FILES_LOCATION :
        path.join(__dirname, TAG_FILES_LOCATION);
  execAndLogErrors(`${tagScriptDir}/tag-files.sh ${inputPath}`);

  //now, untag exceptions
  untagInternal(inputPath, exceptions);
}

//if convertMap is null, we use nodejs string conversion trick of zos to input ??? and output ascii
//TODO make async
function convertRecursively(inputPath, outputPath, convertMap, ignorePath, convertFunction) {
  try {
    fs.mkdirSync(outputPath);
  } catch (e) {
    if (e.code != 'EEXIST') {
      throw e;
    }
  }
  let dontConvert = false;
  for (let i = 0; i < CONVERT_DIR_EXCEPTIONS.length; i++) {
    if (inputPath.endsWith(CONVERT_DIR_EXCEPTIONS[i])) {
      dontConvert = true;
    }
  }

  const names = fs.readdirSync(inputPath);
  names.forEach(function(name) {
    const fullPath = path.join(inputPath, name);
    const destinationPath = path.join(outputPath, name);
    if (fullPath != ignorePath) {
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        try {
          fs.mkdirSync(destinationPath);
        } catch (e) {
          if (e.code != 'EEXIST') {
            throw e;
          }
        }
        convertRecursively(fullPath, destinationPath, convertMap, ignorePath, convertFunction);
      } else {
        convertFunction(fullPath, destinationPath, dontConvert ? 'copy' : convertMap);
      }
    }
  });
}
