/* REXX */

/**
 * This program and the accompanying materials are
 * made available under the terms of the Eclipse Public License v2.0 which accompanies
 * this distribution, and is available at https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */


/**
 * Script to copy a USS file to a shared dataset / shared PDS member using OCOPY.
 */


trace 'o'
parse arg filename dsname mode tail

if filename = '' | dsname = '' | (mode <> 'BINARY' & mode <> 'TEXT') | tail <> '' then
do
  say 'Usage: ocopyshr.rexx "<filename>" "<dsname[(member)]>" BINARY|TEXT'
  say '    <filename>            absolute path of file'
  say '    <dsname[(member)]>    data set name to copy into'
  exit 1
end

address TSO "alloc fi(file) path('"filename"')"
if rc <> 0 then exit rc
address TSO "alloc fi(ds) dataset('"dsname"') shr"
if rc <> 0 then exit rc
address TSO "ocopy indd(file) outdd(ds) "mode
if rc <> 0 then exit rc
address TSO "free fi(file ds)"
exit rc
