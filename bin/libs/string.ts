/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as os from 'cm_os';

export const ENCODING_NAME_TO_CCSID:any = {
  'IBM-037': 37,
  'IBM-273': 273,
  'IBM-277': 277,
  'IBM-278': 278,
  'IBM-280': 280,
  'IBM-284': 284,
  'IBM-285': 285,
  'IBM-297': 297,
  'US-ASCII': 367,
  'IBM-420': 420,
  'IBM-423': 423,
  'IBM-424': 424,
  'IBM-437': 437,
  'IBM-500': 500,
  'IBM-808': 808,
  'ISO-8859-7': 813,
  'ISO-8859-1': 819,
 	'IBM-Thai': 838,
  'IBM-850': 850,
  'IBM-852': 852,
  'IBM-855': 855,
  'IBM-857': 857,
  'IBM-858': 858,
  'IBM-862': 862,
  'IBM-863': 863,
  'IBM-864': 864,
  'IBM-866': 866,
  'IBM-867': 867,
  'IBM-869': 869,
  'IBM-870': 870,
  'IBM-871': 871,
  'IBM-872': 872,
  'TIS-620': 874,
  'KOI8-R': 878,
  'ISO-8859-13': 901,
  'IBM-902': 902,
  'IBM-904': 904,
  'ISO-8859-2': 912,
  'ISO-8859-5': 915,
  'ISO-8859-8-I': 916,
 	'ISO-8859-9': 920,
  'IBM-921': 921,
  'IBM-922': 922,
 	'ISO-8859-15': 923,
  'IBM-924': 924,
 	'Shift_JIS': 932,
 	'Windows-31J': 943,
 	'EUC-KR': 949,
 	'Big5': 950,
 	'EUC-JP': 954,
 	'EUC-TW': 964,
 	'Microsoft-Publish': 1004,
  'IBM-1026': 1026,
  'IBM-1043': 1043,
  'IBM-1047': 1047,
 	'hp-roman8': 1051,
 	'ISO-8859-6': 1089,
 	'VISCII': 1129,
  'IBM-1140': 1140,
  'IBM-1141': 1141,
  'IBM-1142': 1142,
  'IBM-1143': 1143,
  'IBM-1144': 1144,
  'IBM-1145': 1145,
  'IBM-1146': 1146,
  'IBM-1147': 1147,
  'IBM-1148': 1148,
  'IBM-1149': 1149,
  'IBM-1153': 1153,
  'IBM-1155': 1155,
 	'KOI8-U': 1168,
 	'UTF-16BE': 1200,
 	'UTF-16LE': 1202,
 	'UTF-16': 1204,
 	'UTF-8': 1208,
 	'UTF-32BE': 1232,
 	'UTF-32LE': 1234,
 	'UTF-32': 1236,
 	'windows-1250': 1250,
 	'windows-1251': 1251,
 	'windows-1252': 1252,
 	'windows-1253': 1253,
 	'windows-1254': 1254,
 	'windows-1255': 1255,
 	'windows-1256': 1256,
 	'windows-1257': 1257,
 	'windows-1258': 1258,
 	'MACINTOSH': 1275,
	'KSC_5601': 1363,
 	'GBK': 1386,
 	'GB18030': 1392
};

const MAP_1047_TO_819 = [
/*         0     1     2     3     4     5     6     7     8     9     A     B     C     D     E     F */
/* 0 */ 0x00, 0x01, 0x02, 0x03, 0x9C, 0x09, 0x86, 0x7F, 0x97, 0x8D, 0x8E, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
/* 1 */ 0x10, 0x11, 0x12, 0x13, 0x9D, 0x0A, 0x08, 0x87, 0x18, 0x19, 0x92, 0x8F, 0x1C, 0x1D, 0x1E, 0x1F,
/* 2 */ 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x17, 0x1B, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x05, 0x06, 0x07,
/* 3 */ 0x90, 0x91, 0x16, 0x93, 0x94, 0x95, 0x96, 0x04, 0x98, 0x99, 0x9A, 0x9B, 0x14, 0x15, 0x9E, 0x1A,
/* 4 */ 0x20, 0xA0, 0xE2, 0xE4, 0xE0, 0xE1, 0xE3, 0xE5, 0xE7, 0xF1, 0xA2, 0x2E, 0x3C, 0x28, 0x2B, 0x7C,
/* 5 */ 0x26, 0xE9, 0xEA, 0xEB, 0xE8, 0xED, 0xEE, 0xEF, 0xEC, 0xDF, 0x21, 0x24, 0x2A, 0x29, 0x3B, 0x5E,
/* 6 */ 0x2D, 0x2F, 0xC2, 0xC4, 0xC0, 0xC1, 0xC3, 0xC5, 0xC7, 0xD1, 0xA6, 0x2C, 0x25, 0x5F, 0x3E, 0x3F,
/* 7 */ 0xF8, 0xC9, 0xCA, 0xCB, 0xC8, 0xCD, 0xCE, 0xCF, 0xCC, 0x60, 0x3A, 0x23, 0x40, 0x27, 0x3D, 0x22,
/* 8 */ 0xD8, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0xAB, 0xBB, 0xF0, 0xFD, 0xFE, 0xB1,
/* 9 */ 0xB0, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0xAA, 0xBA, 0xE6, 0xB8, 0xC6, 0xA4,
/* A */ 0xB5, 0x7E, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0xA1, 0xBF, 0xD0, 0x5B, 0xDE, 0xAE,
/* B */ 0xAC, 0xA3, 0xA5, 0xB7, 0xA9, 0xA7, 0xB6, 0xBC, 0xBD, 0xBE, 0xDD, 0xA8, 0xAF, 0x5D, 0xB4, 0xD7,
/* C */ 0x7B, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0xAD, 0xF4, 0xF6, 0xF2, 0xF3, 0xF5,
/* D */ 0x7D, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0xB9, 0xFB, 0xFC, 0xF9, 0xFA, 0xFF,
/* E */ 0x5C, 0xF7, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0xB2, 0xD4, 0xD6, 0xD2, 0xD3, 0xD5,
/* F */ 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0xB3, 0xDB, 0xDC, 0xD9, 0xDA, 0x9F
];

const MAP_819_TO_1047 = [
/*         0     1     2     3     4     5     6     7     8     9     A     B     C     D     E     F */
/* 0 */ 0x00, 0x01, 0x02, 0x03, 0x37, 0x2D, 0x2E, 0x2F, 0x16, 0x05, 0x15, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
/* 1 */ 0x10, 0x11, 0x12, 0x13, 0x3C, 0x3D, 0x32, 0x26, 0x18, 0x19, 0x3F, 0x27, 0x1C, 0x1D, 0x1E, 0x1F,
/* 2 */ 0x40, 0x5A, 0x7F, 0x7B, 0x5B, 0x6C, 0x50, 0x7D, 0x4D, 0x5D, 0x5C, 0x4E, 0x6B, 0x60, 0x4B, 0x61,
/* 3 */ 0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0x7A, 0x5E, 0x4C, 0x7E, 0x6E, 0x6F,
/* 4 */ 0x7C, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6,
/* 5 */ 0xD7, 0xD8, 0xD9, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xAD, 0xE0, 0xBD, 0x5F, 0x6D,
/* 6 */ 0x79, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96,
/* 7 */ 0x97, 0x98, 0x99, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xC0, 0x4F, 0xD0, 0xA1, 0x07,
/* 8 */ 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x06, 0x17, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x09, 0x0A, 0x1B,
/* 9 */ 0x30, 0x31, 0x1A, 0x33, 0x34, 0x35, 0x36, 0x08, 0x38, 0x39, 0x3A, 0x3B, 0x04, 0x14, 0x3E, 0xFF,
/* A */ 0x41, 0xAA, 0x4A, 0xB1, 0x9F, 0xB2, 0x6A, 0xB5, 0xBB, 0xB4, 0x9A, 0x8A, 0xB0, 0xCA, 0xAF, 0xBC,
/* B */ 0x90, 0x8F, 0xEA, 0xFA, 0xBE, 0xA0, 0xB6, 0xB3, 0x9D, 0xDA, 0x9B, 0x8B, 0xB7, 0xB8, 0xB9, 0xAB,
/* C */ 0x64, 0x65, 0x62, 0x66, 0x63, 0x67, 0x9E, 0x68, 0x74, 0x71, 0x72, 0x73, 0x78, 0x75, 0x76, 0x77,
/* D */ 0xAC, 0x69, 0xED, 0xEE, 0xEB, 0xEF, 0xEC, 0xBF, 0x80, 0xFD, 0xFE, 0xFB, 0xFC, 0xBA, 0xAE, 0x59,
/* E */ 0x44, 0x45, 0x42, 0x46, 0x43, 0x47, 0x9C, 0x48, 0x54, 0x51, 0x52, 0x53, 0x58, 0x55, 0x56, 0x57,
/* F */ 0x8C, 0x49, 0xCD, 0xCE, 0xCB, 0xCF, 0xCC, 0xE1, 0x70, 0xDD, 0xDE, 0xDB, 0xDC, 0x8D, 0x8E, 0xDF
];

// Note: Will error if string contains characters not present in 1047
export function stringTo1047Buffer(input: string) {
  const ebcdic = new Array(input.length);
  for (let i = 0; i < input.length; i++){
    ebcdic[i] = MAP_819_TO_1047[input.charCodeAt(i)];
  }
  return Uint8Array.from(ebcdic);
}

export function ebcdicToAscii(input: string): string {
  let ascii = [];
  for (let i = 0; i < input.length; i++){
    ascii.push(MAP_1047_TO_819[input.charCodeAt(i)]);
  }
  return String.fromCharCode.apply(null, ascii);
}

export function asciiToEbcdic(input: string): string {
  let ebcdic = [];
  for (let i = 0; i < input.length; i++){
    ebcdic.push(MAP_819_TO_1047[input.charCodeAt(i)]);
  }
  return String.fromCharCode.apply(null, ebcdic);
}


// via https://gist.github.com/joni/3760795
export function stringToBuffer(input: string) {
  const utf8 = [];
  for (let i=0; i < input.length; i++) {
    let charcode = input.charCodeAt(i);
    if (charcode < 0x80) utf8.push(charcode);
    else if (charcode < 0x800) {
      utf8.push(0xc0 | (charcode >> 6), 
                0x80 | (charcode & 0x3f));
    }
    else if (charcode < 0xd800 || charcode >= 0xe000) {
      utf8.push(0xe0 | (charcode >> 12), 
                0x80 | ((charcode>>6) & 0x3f), 
                0x80 | (charcode & 0x3f));
    }
    // surrogate pair
    else {
      i++;
      // UTF-16 encodes 0x10000-0x10FFFF by
      // subtracting 0x10000 and splitting the
      // 20 bits of 0x0-0xFFFFF into two halves
      charcode = 0x10000 + (((charcode & 0x3ff)<<10)
                            | (input.charCodeAt(i) & 0x3ff))
      utf8.push(0xf0 | (charcode >>18), 
                0x80 | ((charcode>>12) & 0x3f), 
                0x80 | ((charcode>>6) & 0x3f), 
                0x80 | (charcode & 0x3f));
    }
  }
  return Uint8Array.from(utf8);
}

export function trim(input: string): string {
  return input.trim();
}

export function escapeDollar(str: string): string | undefined {
  if (str === null || str === undefined)
    return undefined;
  return str.replace(/[$]/g, '\\$&');
}

export function escapeRegExp(str: string): string | undefined {
  if (str === null || str === undefined)
      return undefined;
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Replace all occurrences of a string with another	
export function replace(sourceString: string, searchTerm: string, replaceTerm: string): string {
  const all = new RegExp(searchTerm, 'g')
  return sourceString.replace(all, replaceTerm);
}	

// Return true if searchString is substring of string	
export function isSubstrOf(sourceString: string, searchString: string): boolean {
	return sourceString.includes(searchString);
}	

//TODO this is a way to not have lossy output https://github.com/zowe/zlux-server-framework/blob/v2.x/staging/utils/argumentParser.js
export function sanitizeAlphanum(input: string): string {
  const regex = /[^a-zA-Z0-9]/g;
  return input.replace(regex, '_');
}

export function sanitizeAlpha(input: string): string {
  const regex = /[^a-zA-Z]/g;
  return input.replace(regex, '_');
}

export function sanitizeNum(input: string): string {
  const regex = /[^0-9]/g;
  return input.replace(regex, '_');
}

export function lowerCase(input: string): string {
  return input.toLowerCase();
}

export function upperCase(input: string): string {
  return input.toUpperCase();
}


// Padding string on every lines of a multiple-line string
export function paddingLeft(str: string, pad: string): string {
  return str.split('\n')
    .map(function(line:string) {
      return pad+line;})
    .join('\n');
}

/*
###############################
# Padding string on every lines of a file
#
# @param string   optional string
file_padding_left() {
  file="${1}"
  pad="${2}"

  cat "${file}" | sed "s/^/${pad}/"
}

###############################
# Padding string on every lines of multiple files separated by comma
#
# @param string   optional string
files_padding_left() {
  files="${1}"
  pad="${2}"
  separator="${3:-,}"

  OLDIFS=$IFS
  IFS="${separator}"
  for file in ${files}; do
    file=$(trim "${file}")
    if [ -n "${file}" -a -f "${file}" ]; then
      cat "${file}" | sed "s/^/${pad}/"
    fi
  done
  IFS=$OLDIFS
}
*/

export function removeTrailingSlash(input: string): string {
  if (input.endsWith('/')) {
    return input.substring(0, input.length-1);
  } else {
    return input;
  }
}

const binToB64 =[0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,0x4F,0x50,
                 0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,0x61,0x62,0x63,0x64,0x65,0x66,
                 0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0x6F,0x70,0x71,0x72,0x73,0x74,0x75,0x76,
                 0x77,0x78,0x79,0x7A,0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x2B,0x2F];

//TODO may be more complex than this, we have more thorough functions elsewhere in zlux
export function base64Encode(input: string): string {
  let out = [];
  
  const inputLen = input.length;
  const numFullGroups = Math.floor(inputLen / 3);
  const numBytesInPartialGroup = inputLen - 3 * numFullGroups;
  let inCursor = 0;

  // Translate all full groups from byte array elements to Base64
  for (let i = 0; i < numFullGroups; i++) {
    let byte0 = input.charCodeAt(inCursor++) & 0xff;
    let byte1 = input.charCodeAt(inCursor++) & 0xff;
    let byte2 = input.charCodeAt(inCursor++) & 0xff;
    out.push(binToB64[byte0 >> 2]);
    out.push(binToB64[(byte0 << 4) & 0x3f | (byte1 >> 4)]);
    out.push(binToB64[(byte1 << 2) & 0x3f | (byte2 >> 6)]);
    out.push(binToB64[byte2 & 0x3f]);
  }

  // Translate partial group if present
  if (numBytesInPartialGroup != 0) {
    let byte0 = input.charCodeAt(inCursor++) & 0xff;
    out.push(binToB64[byte0 >> 2]);
    if (numBytesInPartialGroup == 1) {
      out.push(binToB64[(byte0 << 4) & 0x3f]);
      out.push(0x3d);
      out.push(0x3d);
    }
    else {
      let byte1 = input.charCodeAt(inCursor++) & 0xff;
      out.push(binToB64[(byte0 << 4) & 0x3f | (byte1 >> 4)]);
      out.push(binToB64[(byte1 << 2) & 0x3f]);
      out.push(0x3d);
    }
  }

  return String.fromCharCode.apply(null, out);
}

export function itemInList(stringList: string, stringToFind?: string, separator: string=','): boolean {
  if (!stringToFind) {
    return false;
  }
  return stringList.split(separator).includes(stringToFind);
}
