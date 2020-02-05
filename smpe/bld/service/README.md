# Zowe SMP/E service build – sample output

## Table of Contents

   * [USERMOD build (GA)](#usermod-build-ga)
        * [Header SYSMOD 1](#header-sysmod-1)
   * [1st PTF build](#1st-ptf-build)
        * [Create ptf-bucket.txt](#create-ptf-buckettxt)
        * [Create apar-bucket.txt](#create-apar-buckettxt)
        * [Header SYSMOD 1](#header-sysmod-1-1)
   * [Force APAR build](#force-apar-build)
        * [Update ptf-bucket.txt](#update-ptf-buckettxt)
        * [Update apar-bucket.txt](#update-apar-buckettxt)
        * [Header SYSMOD 1](#header-sysmod-1-2)
        * [Final ptf-bucket.txt](#final-ptf-buckettxt)
        * [Final current-apar.txt](#final-current-apartxt)
   * [Rebuild 1st PTF with additional APAR](#rebuild-1st-ptf-with-additional-apar)
        * [Header SYSMOD 1](#header-sysmod-1-3)
   * [Promote PTF](#promote-ptf)
        * [Update ptf-bucket.txt](#update-ptf-buckettxt-1)
        * [Remove current-apar.txt](#remove-current-apartxt)
        * [Create/update promoted-apar.txt](#createupdate-promoted-apartxt)
        * [Create/update promoted-close.txt](#createupdate-promoted-closetxt)
        * [Create/update promoted-hold.txt](#createupdate-promoted-holdtxt)
        * [Create/update promoted-ptf.txt](#createupdate-promoted-ptftxt)
   * [2nd PTF build](#2nd-ptf-build)
        * [Header SYSMOD 1](#header-sysmod-1-4)
   * [2nd force APAR build](#2nd-force-apar-build)
        * [Update ptf-bucket.txt](#update-ptf-buckettxt-2)
        * [Update apar-bucket.txt](#update-apar-buckettxt-1)
        * [Create current-hold-AO.txt](#create-current-hold-aotxt)
        * [Header SYSMOD 1](#header-sysmod-1-5)
        * [Final ptf-bucket.txt](#final-ptf-buckettxt-1)
        * [Final current-apar.txt](#final-current-apartxt-1)
   * [Force USERMOD build](#force-usermod-build)
        * [Remove or update ptf-bucket.txt](#remove-or-update-ptf-buckettxt)
        * [Header SYSMOD 1](#header-sysmod-1-6)
        * [Final ptf-bucket.txt](#final-ptf-buckettxt-2)



## USERMOD build (GA)

While the FMID has not GA'd, smpe-service.sh will create a USERMOD that matches the FMID.

### Header SYSMOD 1
<pre>
++USERMOD(TMP0001) /* 5698-ZWE00-AZWE001 */ REWORK(2020013).
++VER(Z038,C150,P115) FMID(AZWE001)
  REQ(TMP0002)
 /*
  SPECIAL CONDITIONS:
    COPYRIGHT:
      5698-ZWE00 COPYRIGHT Contributors to the Zowe Project. 2020

  COMMENTS:
    COMMUNITY VERSION:
      1.8.0

    GITHUB BRANCH:
      ptf (build 16)
 */.
++HOLD(TMP0001) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(20013)
  COMMENT(
  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: stop servers                                    *
  ****************************************************************
  * Timing: pre-APPLY                                            *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Stop the Zowe servers before installing this update.

  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: start servers                                   *
  ****************************************************************
  * Timing: post-APPLY                                           *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Start the Zowe servers after installing this update.

  ).
</pre>

The second USERMOD (TMP0002) of the set does not have the ++HOLD info.



## **1st PTF build**

Once the FMID GA'd, ptf-bucket.txt is created and filled with PTF references. The presence of this file triggers PTF builds. apar-bucket.txt is also created and holds APARs for non-PTF builds.

### Create ptf-bucket.txt
<pre>
# format: PTF(s) – matching APAR(s)
UO12345 UO43210 - IO12345 IO43210
UO67890 UO98765 - IO67890 IO98765
</pre>
### Create apar-bucket.txt
<pre>
# format: APAR(s)
IO19283 IO74650
AO00001 AO00002
</pre>
### Header SYSMOD 1
<pre>
<b>++PTF(UO12345)</b> /* 5698-ZWE00-AZWE001 */ REWORK(2020013).
++VER(Z038,C150,P115) FMID(AZWE001)
  REQ(UO43210)
  <b>SUP(AO12345,AO43210)</b>
 /*
  <b>PROBLEM DESCRIPTION(S):
    IO12345 -
      PROBLEM SUMMARY:
      ****************************************************************
      * USERS AFFECTED: All Zowe users                               *
      ****************************************************************
      * PROBLEM DESCRIPTION: Update Zowe FMID AZWE001 to match the   *
      *                      community release                       *
      ****************************************************************
      * RECOMMENDATION: Apply provided service                       *
      ****************************************************************
      The Zowe community version was updated to 1.8.0.
      This PTF provides the community changes in SMP/E format.
      Follow this link for more details on the community changes:
      https://docs.zowe.org/stable/

    IO43210 -
      ...

  COMPONENT:
    5698-ZWE00-AZWE001

  APARS FIXED:
    IO12345
    IO43210

  SPECIAL CONDITIONS:
    ACTION:
      ****************************************************************
      * Affected function: Zowe servers                              *
      ****************************************************************
      * Description: stop servers                                    *
      ****************************************************************
      * Timing: pre-APPLY                                            *
      ****************************************************************
      * Part: ZOWESVR & ZWESISVR                                     *
      ****************************************************************
      Stop the Zowe servers before installing this update.
       
      ...</b>

    COPYRIGHT:
      5698-ZWE00 COPYRIGHT Contributors to the Zowe Project. 2020

  COMMENTS:
    COMMUNITY VERSION:
      1.8.0

    GITHUB BRANCH:
      ptf (build 20)
 */.
++HOLD(UO12345) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(20013)
  COMMENT(
  <hold info>
  ).
</pre>
The second PTF (UO43210) of the set does not have the ++HOLD info.

## **Force APAR build**

If a customer requires it, a Zowe build engineer can trigger an APAR build by updating ptf-bucket.txt. Usable APAR numbers can be found in apar-bucket.txt and must be removed here when used.

### Update ptf-bucket.txt
<pre>
<b>IO19283 IO74650</b>
# format: PTF(s) – matching APAR(s)
UO12345 UO43210 - IO12345 IO43210
UO67890 UO98765 - IO67890 IO98765
</pre>

### Update apar-bucket.txt
<pre>
# format: APAR(s)
<b># IO19283 IO74650 - issue 123 - Jan 13, 2020</b>
AO00001 AO00002
</pre>
### Header SYSMOD 1
<pre>
<b>++APAR(AO19283)</b> /* 5698-ZWE00-AZWE001 */ REWORK(2020013).
++VER(Z038,C150,P115) FMID(AZWE001)
  REQ(AO74650)
 /*
  SPECIAL CONDITIONS:
    COPYRIGHT:
      5698-ZWE00 COPYRIGHT Contributors to the Zowe Project. 2020

  COMMENTS:
    COMMUNITY VERSION:
      1.8.0

    GITHUB BRANCH:
      ptf (build 22)
 */.
++HOLD(AO12345) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(20013)
  COMMENT(
  <hold info>
  ).
</pre>
The second APAR (AO43210) of the set does not have the ++HOLD info.

After the build, ptf-bucket.txt must be restored (no more APAR reference), and current-apar.txt must be created/updated with APAR. The updated current-apar.txt file must move up to the staging branch.

### Final ptf-bucket.txt
<pre>
# format: PTF(s) – matching APAR(s)
UO12345 UO43210 - IO12345 IO43210
UO67890 UO98765 - IO67890 IO98765
</pre>
### Final current-apar.txt
<pre>
IO19283 IO74650
</pre>

## **Rebuild 1st PTF with additional APAR**
The presence of current-apar.txt will cause all future builds to supersede the APARs listed within (for any type of build, PTF, APAR, or USERMOD).

### Header SYSMOD 1
<pre>
++PTF(UO12345) /* 5698-ZWE00-AZWE001 */ REWORK(2020013).
++VER(Z038,C150,P115) FMID(AZWE001)
  REQ(UO43210)
  SUP(AO12345,<b>AO19283</b>,AO43210,<b>AO74650</b>)
 /*
  PROBLEM DESCRIPTION(S):
    IO12345 -
      PROBLEM SUMMARY:
      ****************************************************************
      * USERS AFFECTED: All Zowe users                               *
      ****************************************************************
      * PROBLEM DESCRIPTION: Update Zowe FMID AZWE001 to match the   *
      *                      community release                       *
      ****************************************************************
      * RECOMMENDATION: Apply provided service                       *
      ****************************************************************
      The Zowe community version was updated to 1.8.0.
      This PTF provides the community changes in SMP/E format.
      Follow this link for more details on the community changes:
      https://docs.zowe.org/stable/

    <b>IO19283</b> -
      ...

  COMPONENT:
    5698-ZWE00-AZWE001

  APARS FIXED:
    IO12345
    <b>IO19283</b>
    IO43210
    <b>IO74650</b>

  SPECIAL CONDITIONS:
    ACTION:
      ****************************************************************
      * Affected function: Zowe servers                              *
      ****************************************************************
      * Description: stop servers                                    *
      ****************************************************************
      * Timing: pre-APPLY                                            *
      ****************************************************************
      * Part: ZOWESVR & ZWESISVR                                     *
      ****************************************************************
      Stop the Zowe servers before installing this update.
       
      ...

    COPYRIGHT:
      5698-ZWE00 COPYRIGHT Contributors to the Zowe Project. 2020

  COMMENTS:
    COMMUNITY VERSION:
      1.8.0

    GITHUB BRANCH:
      ptf (build 24)
 */.
++HOLD(UO12345) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(20013)
  COMMENT(
  <hold info>
  ).
</pre>
The second PTF (UO43210) of the set does not have the ++HOLD info.

## **Promote PTF**

The staging branch is updated (using smpe.promote.sh) during the promote of a PTF so that future builds know that this PTF, and everything in it, shipped.

### Update ptf-bucket.txt
<pre>
<b>#UO12345 UO43210 - IO12345 IO43210 - Mon Jan 13 16:27:24 EST 2020</b>
UO67890 UO98765 - IO67890 IO98765
</pre>
### Remove current-apar.txt

&lt;the APARs are now embedded in the PTF, so this file may no longer exist&gt;
&lt;Note: the same is true for current-hold-\*.txt, which is not used in this sample&gt;

### Create/update promoted-apar.txt
<pre>
IO12345
IO19283
IO43210
IO74650
</pre>
### Create/update promoted-close.txt
<pre>
    IO12345 -
      PROBLEM SUMMARY:
      ****************************************************************
      * USERS AFFECTED: All Zowe users                               *
      ****************************************************************
      * PROBLEM DESCRIPTION: Update Zowe FMID AZWE001 to match the   *
      *                      community release                       *
      ****************************************************************
      * RECOMMENDATION: Apply provided service                       *
      ****************************************************************
      The Zowe community version was updated to 1.8.0.
      This PTF provides the community changes in SMP/E format.
      Follow this link for more details on the community changes:
      https://docs.zowe.org/stable/

    IO19283 -
      ...

    ...

</pre>
### Create/update promoted-hold.txt
<pre>
++HOLD(UO12345) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(20013)
  COMMENT(
  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: stop servers                                    *
  ****************************************************************
  * Timing: pre-APPLY                                            *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Stop the Zowe servers before installing this update.

  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: start servers                                   *
  ****************************************************************
  * Timing: post-APPLY                                           *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Start the Zowe servers after installing this update.

  ).

</pre>
### Create/update promoted-ptf.txt
<pre>
UO12345
UO43210
</pre>

## **2nd PTF build**

The presence of promoted-\*.txt will cause all future builds to pick up the info within as needed (for any type of build, PTF, APAR, or USERMOD). Note that PTFs supersede previous PTFs, so the closing and hold info of the previous PTFs is embedded in this PTF.

### Header SYSMOD 1
<pre>
<b>++PTF(UO67890)</b> /* 5698-ZWE00-AZWE001 */ REWORK(2020013).
++VER(Z038,C150,P115) FMID(AZWE001)
  REQ(UO98765)
  <b>SUP(AO12345,AO19283,AO43210,</b>AO67890,<b>AO74650,</b>AO98765,<b>UO12345,UO43210)</b>
 /*
  PROBLEM DESCRIPTION(S):
    IO67890 -
      PROBLEM SUMMARY:
      ****************************************************************
      * USERS AFFECTED: All Zowe users                               *
      ****************************************************************
      * PROBLEM DESCRIPTION: Update Zowe FMID AZWE001 to match the   *
      *                      community release                       *
      ****************************************************************
      * RECOMMENDATION: Apply provided service                       *
      ****************************************************************
      The Zowe community version was updated to 1.8.0.
      This PTF provides the community changes in SMP/E format.
      Follow this link for more details on the community changes:
      https://docs.zowe.org/stable/

    IO98765 -
      ...

    <b>IO12345 -
      ...

    ...</b>

  COMPONENT:
    5698-ZWE00-AZWE001

  APARS FIXED:
    IO67890
    IO98765
    <b>IO12345
    IO19283
    IO43210
    IO74650</b>

  SPECIAL CONDITIONS:
    ACTION:
      ****************************************************************
      * Affected function: Zowe servers                              *
      ****************************************************************
      * Description: stop servers                                    *
      ****************************************************************
      * Timing: pre-APPLY                                            *
      ****************************************************************
      * Part: ZOWESVR & ZWESISVR                                     *
      ****************************************************************
      Stop the Zowe servers before installing this update.
       
      ****************************************************************
      * Affected function: Zowe servers                              *
      ****************************************************************
      * Description: start servers                                   *
      ****************************************************************
      * Timing: post-APPLY                                           *
      ****************************************************************
      * Part: ZOWESVR & ZWESISVR                                     *
      ****************************************************************
      Start the Zowe servers after installing this update.

      <b>****************************************************************
      * Affected function: Zowe servers                              *
      ****************************************************************
      * Description: stop servers                                    *
      ****************************************************************
      * Timing: pre-APPLY                                            *
      ****************************************************************
      * Part: ZOWESVR & ZWESISVR                                     *
      ****************************************************************
      Stop the Zowe servers before installing this update.
      
      ****************************************************************
      * Affected function: Zowe servers                              *
      ****************************************************************
      * Description: start servers                                   *
      ****************************************************************
      * Timing: post-APPLY                                           *
      ****************************************************************
      * Part: ZOWESVR & ZWESISVR                                     *
      ****************************************************************
      Start the Zowe servers after installing this update.</b>
      
    COPYRIGHT:
      5698-ZWE00 COPYRIGHT Contributors to the Zowe Project. 2020

  COMMENTS:
    COMMUNITY VERSION:
      1.8.0

    GITHUB BRANCH:
      ptf (build 26)
 */.
++HOLD(UO67890) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(20013)
  COMMENT(
  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: stop servers                                    *
  ****************************************************************
  * Timing: pre-APPLY                                            *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Stop the Zowe servers before installing this update.
   
  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: start servers                                   *
  ****************************************************************
  * Timing: post-APPLY                                           *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Start the Zowe servers after installing this update.
  ).
<b>++HOLD(UO12345) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(20013)
  COMMENT(
  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: stop servers                                    *
  ****************************************************************
  * Timing: pre-APPLY                                            *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Stop the Zowe servers before installing this update.
  
  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: start servers                                   *
  ****************************************************************
  * Timing: post-APPLY                                           *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Start the Zowe servers after installing this update.
  
  ).</b>
</pre>
The second PTF (UO98765) of the set does not have the ++HOLD info.

## **2nd force APAR build**

This build is to show how APAR builds pick up the data of promoted PTFs in promoted-\*.txt. A USERMOD build has similar results. This build also shows how to add additional hold information. We&#39;re adding AO (automation) type hold information to show how it mixes with the always present ACTION type hold information of fixed-hold-ACTION.txt.

### Update ptf-bucket.txt
<pre>
<b>AO00001 AO00002</b>
# format: PTF(s) – matching APAR(s)
#UO12345 UO43210 - IO12345 IO43210 - Mon Jan 13 16:27:24 EST 2020
UO67890 UO98765 - IO67890 IO98765
</pre>
### Update apar-bucket.txt
<pre>
# format: APAR(s)
# IO19283 IO74650 - issue 123 - Jan 13, 2020
<b># IO00001 IO00002 - issue 456 - Jan 20, 2020</b>
</pre>
### Create current-hold-AO.txt
<pre>
****************************************************************
* Affected function: Zowe servers                              *
****************************************************************
* Description: rename of server                                *
****************************************************************
* Timing: post-APPLY                                           *
****************************************************************
* Part: ZOWESVR                                                *
****************************************************************
ZOWESVR becomes ZWESVSTC. Adjust your automation accordingly
before attempting to start the servers. 
</pre>
### Header SYSMOD 1
<pre>
<b>++APAR(AO00001)</b> /* 5698-ZWE00-AZWE001 */ REWORK(2020020). 
++VER(Z038,C150,P115) FMID(AZWE001)
  REQ(AO00002)
  <b>PRE(AO12345,AO19283,AO43210,AO74650,UO12345,UO43210)</b>
/*
  SPECIAL CONDITIONS:
    COPYRIGHT:
      5698-ZWE00 COPYRIGHT Contributors to the Zowe Project. 2020

  COMMENTS:
    COMMUNITY VERSION:
      1.8.0

    GITHUB BRANCH:
      unknown (build unknown)
 */.
++HOLD(AO00001) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(20020)
  COMMENT(
  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: stop servers                                    *
  ****************************************************************
  * Timing: pre-APPLY                                            *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Stop the Zowe servers before installing this update.

  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: start servers                                   *
  ****************************************************************
  * Timing: post-APPLY                                           *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Start the Zowe servers after installing this update.

  ).
<b>++HOLD(AO00001) SYSTEM FMID(AZWE001) REASON(AO) DATE(20020)
  COMMENT(
  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: rename of server                                *
  ****************************************************************
  * Timing: post-APPLY                                           *
  ****************************************************************
  * Part: ZOWESVR                                                *
  ****************************************************************
  ZOWESVR becomes ZWESVSTC. Adjust your automation accordingly
  before attempting to start the servers.

  ).</b>
</pre>
The second APAR (AO00002) of the set does not have the ++HOLD info.

After the build, ptf-bucket.txt must be restored (no more APAR reference), and current-apar.txt must be created/updated with APAR. The updated current-apar.txt file must move up to the staging branch.

### Final ptf-bucket.txt
<pre>
# format: PTF(s) – matching APAR(s)
#UO12345 UO43210 - IO12345 IO43210 - Mon Jan 13 16:27:24 EST 2020
UO67890 UO98765 - IO67890 IO98765
</pre>
### Final current-apar.txt
<pre>
AO00001 AO00002
</pre>

## **Force USERMOD build**

If required, a Zowe build engineer can trigger a USERMOD build instead of a PTF build by removing ptf-bucket.txt, or commenting out all its content. This also shows that APAR and USERMOD build will supersede APAR builds listed in current-apar.txt.

### Remove or update ptf-bucket.txt
<pre>
# format: PTF(s) – matching APAR(s)
#UO12345 UO43210 - IO12345 IO43210 - Mon Jan 13 16:27:24 EST 2020
<b>#UO67890 UO98765 - IO67890 IO98765 – temporary for usermod</b>
</pre>
### Header SYSMOD 1
<pre>
<b>++USERMOD(TMP0001)</b> /* 5698-ZWE00-AZWE001 */ REWORK(2020020).
++VER(Z038,C150,P115) FMID(AZWE001)
  REQ(TMP0002)
  <b>SUP(AO00001,AO00002)</b>
  PRE(AO12345,AO19283,AO43210,AO74650,UO12345,UO43210)
 /*
  SPECIAL CONDITIONS:
    COPYRIGHT:
      5698-ZWE00 COPYRIGHT Contributors to the Zowe Project. 2020

  COMMENTS:
    COMMUNITY VERSION:
      1.8.0

    GITHUB BRANCH:
      unknown (build unknown)
 */.
++HOLD(TMP0001) SYSTEM FMID(AZWE001) REASON(ACTION) DATE(20020)
  COMMENT(
  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: stop servers                                    *
  ****************************************************************
  * Timing: pre-APPLY                                            *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Stop the Zowe servers before installing this update.

  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: start servers                                   *
  ****************************************************************
  * Timing: post-APPLY                                           *
  ****************************************************************
  * Part: ZOWESVR & ZWESISVR                                     *
  ****************************************************************
  Start the Zowe servers after installing this update.

  ).
++HOLD(TMP0001) SYSTEM FMID(AZWE001) REASON(AO) DATE(20020)
  COMMENT(
  ****************************************************************
  * Affected function: Zowe servers                              *
  ****************************************************************
  * Description: rename of server                                *
  ****************************************************************
  * Timing: post-APPLY                                           *
  ****************************************************************
  * Part: ZOWESVR                                                *
  ****************************************************************
  ZOWESVR becomes ZWESVSTC. Adjust your automation accordingly
  before attempting to start the servers.

  ).
</pre>
The second USERMOD (TMP0002) of the set does not have the ++HOLD info.

After the build, ptf-bucket.txt must be restored.

### Final ptf-bucket.txt
<pre>
# format: PTF(s) – matching APAR(s)
#UO12345 UO43210 - IO12345 IO43210 - Mon Jan 13 16:27:24 EST 2020
UO67890 UO98765 - IO67890 IO98765
</pre>