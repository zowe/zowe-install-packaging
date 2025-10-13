/* REXX */

/********************************************************************/
/* This program and the accompanying materials are made available   */
/* under the terms of the Eclipse Public License v2.0 which         */
/* accompanies this distribution, and is available at               */
/* https://www.eclipse.org/legal/epl-v20.html                       */
/*                                                                  */
/* SPDX-License-Identifier: EPL-2.0                                 */
/*                                                                  */
/* Copyright Contributors to the Zowe Project.                      */
/********************************************************************/

/*

Tries to initilize SDSF host environment

  With SDSF:
    0   - host environment successfuly initialized
    > 0 - host environment not initialized

  Without SDSF: IRX0043I Error running getSDSF.rex, line 33: Routine not found

  Note:
    If isfcalls fails, rexx is terminated and the caller gets return code 255

  Return codes:
    0..4 - rc of isfcalls (0 = success)
    255 - no SDSF

*/
exit 255
