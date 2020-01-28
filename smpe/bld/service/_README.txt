+-----------------+
| apar-bucket.txt |
+-----------------+

List of APAR numbers (IOxxxxx) that can be be used for non-PTF APAR
builds. When an APAR must be created, cut the first line and paste it
to the top of ptf-bucket.txt before requesting a build.
- APAR numbers MUST be provided by a Zowe build engineer
  working for IBM, as the Zowe community currently relies on
  IBM-internal tooling to guarantee unique naming
- Lines starting with # are interpreted as comments
- A data line must have this format
  <apar>
  1) <apar> Blank-delimited list of 1 or more linked APAR numbers
            (IOxxxxx) to be used for a build.

+----------------+
| ptf-bucket.txt |
+----------------+

NOTE FOR PULL REQUEST APPROVER: 
This file may only be updated when IBM provides more PTF numbers, or
when a Release Candidate PTF is promoted. Reject ALL other updates.


The absence or presence of ptf-bucket.txt is used by the SMP/E build
process to determine whether the FMID or a PTF must be shipped.
If not present, we are in FMID mode, otherwise in PTF mode.

When ptf-bucket.txt is present, it is interpreted to determine whether
a PTF, APAR, or USERMOD must be created.
- PTF and APAR numbers MUST be provided by a Zowe build engineer
  working for IBM, as the Zowe community currently relies on
  IBM-internal tooling to guarantee unique naming
- Lines starting with # are interpreted as comments
- A data line must be one of these formats:
  <ptf> - <apar>
  or   [only when copied in from apar-bucket.txt]
  <apar>
  1) <ptf>  Blank-delimited list of 1 or more linked PTF numbers
            (UOxxxxx) to be used for a build
  2) -      Separator token between <ptf> and <apar>
  3) <apar> Blank-delimited list of 1 or more linked APAR numbers
            (IOxxxxx) to be used for a build. If <ptf> is present,
            then <apar> must be the APARs that are the base for <ptf>.
- There can be multiple data lines, only the first one will be used
- If no data lines are present, a USERMOD will be created
- If the first data line does not have "<ptf>", then an APAR will
  be created
- If the first data line has "<ptf>", then a PTF will be created that
  will SUP the APAR(s) listed in "<apar>"

The file will be updated during promote (promoted PTF is commented out).

+-------------------+
| current-close.txt |
+-------------------+

Generic text block that is used to create the closing information
comments inside a PTF. There are multiple syntax/content rules in play
for this so that the PTF can be processed by IBM's Shopz back-end.
DO NOT ALTER unless you consulted with a Zowe build engineer working
for IBM.
IBM reference: PDR602 - Standardization of SMP PTF
- Round brackets, ( & ), must be present in pairs
- Line length limitations:
  * Users affected: max 44 col
  * Problem Description: max 39 col
  * Problem Summary: max 64 col
  * Problem Conclusion: max 64 col

+--------------------+
| current-hold-*.txt |
+--------------------+

Hold information specific for this PTF/APAR/USERMOD. Can be created
manually when needed for shipping an APAR to a customer. The wildcard
in the file name must be a valid hold type in upper case (e.g. ACTION).
- ACTION: Action(s) required before/after applying PTF
- AO: Automated operations updates required before / after applying PTF
- DOC: Messages or codes added/changed by the PTF
- More types are possible, see the list of "System Reason IDs" in the
  z/OS Knowledge Center, "z/OS SMP/E Reference"
  > "SMP/E modification control statements" > "++HOLD MCS"
  https://www.ibm.com/support/knowledgecenter/SSLTBW_2.4.0/com.ibm.zos.v2r4.gim2000/mcshld.htm

For official PTF builds, this file is created by the build pipline, which
pulls the info from all the pull-requests contributing to this build.

This file will be erased & merged into promoted-hold.txt during promote.
Syntax rules:
- Max 64 col
- Round brackets, ( and ), must be present in pairs
- Comment markers, /* and */, must be present in pairs
- Hold text must start with a flower box
****************************************************************
* Affected function: {area that is impacted by this hold text} *
****************************************************************
* Description: {one-liner describing the hold text}            *
****************************************************************
* Timing: {"post-APPLY" or "pre-APPLY"                         *
*         pre-APPLY is for actions that must be done before    *
*         the service is installed (e.g. stop server)}         *
****************************************************************
* Part: {"not applicable" or name of file involved}            *
****************************************************************
{hold text}

+------------------+
| current-apar.txt |
+------------------+

After an APAR build (see ptf-bucket.txt), the developer must move the
APAR numbers from ptf-bucket.txt to this file so that future
PTF/APAR/USERMOD builds can supersede the APAR(s).
This file will be erased & merged into promoted-apar.txt during promote.

+------------------+
| fixed-hold-*.txt |
+------------------+

Hold information that is added to every PTF/APAR/USERMOD build. The
wildcard in the file name must be a valid hold type in upper case
(e.g. ACTION). See current-hold-*.txt for syntax information.

+-------------------+
| promoted-apar.txt |
+-------------------+

DO NOT ALTER - created & maintained by smpe-promote.sh
List of all APARs that have already shipped, and therefore
must be superseded by the current sysmod build.

+--------------------+
| promoted-close.txt |
+--------------------+

DO NOT ALTER - created & maintained by smpe-promote.sh
Closing information of promoted PTFs. This data is included as-is
in the current sysmod build.

+-------------------+
| promoted-hold.txt |
+-------------------+

DO NOT ALTER - created & maintained by smpe-promote.sh
Hold info of promoted PTFs. This data is included as-is in the
current sysmod build.

+------------------+
| promoted-ptf.txt |
+------------------+

DO NOT ALTER - created & maintained by smpe-promote.sh
List of all PTFs that have already shipped, and therefore
must be superseded or prereq'd by the current sysmod build.
