/* REXX program to add specified days to today and display */

/*
 * This program and the accompanying materials are made available
 * under the terms of the Eclipse Public License v2.0 which
 * accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project. 2022
 */

/*
 * Parameters:
 *   1: days: how many days in the future or past
 *        negative number for past
 *   2: dformat: date format
 *        Combination of YY|YYYY, MM and DD and (optional) any separator
 *        For example: YYYY-MM-DD, MM/DD/YY, DD.MM.YY, YYMMDD...
 *
 * Examples:
 *   date-add.rex 7 YYYY-MM-DD
 *   date-add.rex -1 MM/DD/YY
 */

arg options
parse upper var options days dformat

ERR_DATE.1 = "YY or YYYY (year)"
ERR_DATE.2 = "MM (month)"
ERR_DATE.3 = "DD (day)"

if datatype(days) \= "NUM" then do
  say "ERROR: expected numeric value for days: '"days"'"
  exit 1
end
/* YYMMDD -> YYYY/MM/DD */
if length(dformat) < 6 | length(dformat) > 10 then do
  len = 'short'
  if length(dformat) > 10 then
    len = 'long'
  say "ERROR: invalid date format: '"||dformat||"' is too "||len
  exit 1
end
else do i = 1 to 3
  if pos(word(ERR_DATE.i, 1), dformat) = 0 then do
    say "ERROR: invalid date format: '"||dformat||,
        "' is missing "||ERR_DATE.i
    exit 1
  end
end

today = Date("Base")
target = today + days
ISOTarget = Date("Standard", target, "Base")

/* ISOTarget YYYYMMDD                                  */
/*           12344578 => YYYY = 1234, MM = 56, DD = 78 */

if pos("YYYY", dformat) = 0 then
  dformat = overlay("34", dformat, pos("YY", dformat))
else
  dformat = overlay("1234", dformat, pos("YYYY", dformat))
dformat = overlay("56", dformat, pos("MM", dformat))
dformat = overlay("78", dformat, pos("DD", dformat))

res = translate(dformat, ISOTarget, "12345678")
say res
exit 0
