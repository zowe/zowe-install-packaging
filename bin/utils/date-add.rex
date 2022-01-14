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
 *   1: how many days in the future
 *   2: date format.
 *      For example, 1234-56-78 will be YYYY-MM-DD.
 *      For example, 56/78/34 will be MM/DD/YY.
 *
 * Example: date-add.rexx 7 1234-56-78
 */

arg options
parse var options days format

today = Date('Base')
target = today + days
ISOTarget = Date('Standard', target, 'Base')
result = Translate(format, ISOTarget, '12345678')
say result
