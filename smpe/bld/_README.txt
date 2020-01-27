Table of contents
-----------------
* Add product member to build
* Add SMPE member to build
* Flow for SMP/E packaging build
* Additional tools
* FMID (base) build
* USERMOD (service) build
* PTF (service) build
* APAR (service) build
* SMP/E terminology

Add product member to build
---------------------------
1. Add member to files/..., e.g. files/jcl/ZWENOSEC.jcl
2. Add member definition to smpe/bld/SMPMCS.txt, e.g.
++SAMP(ZWENOSEC)     SYSLIB(SZWESAMP) DISTLIB(AZWESAMP) RELFILE(2) .
3. update scripts/zowe-install-MVS.sh, e.g.
members='ZWESVSTC.jcl ZWESECUR.jcl ZWENOSEC.jcl'

Add SMPE member to build
------------------------
1. Add member to smpe/pax/..., e.g. smpe/pax/USS/ZWEYML01.yml
2. Add member definition to smpe/bld/SMPMCS.txt, e.g.
++HFS(ZWEYML01)      SYSLIB(SZWEZFS ) DISTLIB(AZWEZFS ) RELFILE(4)
   LINK('../workflow/install.yaml')
   TEXT              PARM(PATHMODE(0,7,5,5)) .
3. update smpe/pax/zowe-install-smpe.sh, e.g.
list="$list USS/ZWEYML01.yml"

Flow for SMP/E packaging build
------------------------------
smpe.sh             Wrapper to drive Zowe SMP/E packaging
1. smpe-install.sh  Install current zowe.pax build in staging area
2. smpe-split.sh    Split installed product in smaller chunks and pax them
3. smpe-fmid.sh     Create FMID (++FUNCTION)
4. smpe-gimzip.sh   Create downloadable archive of FMID (pax.Z)
5. smpe-pd.sh       Create Program Directory (SMP/E install documentation)
6. smpe-service.sh  Create fix-pack (++PTF/++APAR/++USERMOD)

Additional tools
----------------
* smpe-config.sh   Recreate smpe.yaml configuration file
* smpe-promote.sh  Update SMP/E build input during promote of current build

FMID (base) build
-----------------
The SMP/E packaging build always creates an FMID package (++FUNCTION)
that matches the current zowe.pax build. The result is placed in
Artifactory as [FMID].zip.
If smpe/bld/service/ptf-bucket.txt does NOT exist in this branch,
then the FMID package will be staged for promotion. If this build is
promoted, then the FMID package will be published on zowe.org.

USERMOD (service) build
-----------------------
The SMP/E packaging build always creates a service package that matches
the current zowe.pax build. The type of service, USERMOD, APAR, or
PTF, depends on various factors explained next. The result is placed in
Artifactory as [FMID].[SYSMOD].zip.
If smpe/bld/service/ptf-bucket.txt does NOT exist in this branch,
or the file is empty/has only comments, then a USERMOD package
(++USERMOD) is created.
A USERMOD will never be published on zowe.org, but can be retrieved
from Artifactory and provided to a customer that requires an SMP/E
installable fix.

PTF (service) build
-------------------
The SMP/E packaging build always creates a service package that matches
the current zowe.pax build. The type of service, USERMOD, APAR, or
PTF, depends on various factors explained next. The result is placed in
Artifactory as [FMID].[SYSMOD].zip.
A PTF package (++PTF) is created if smpe/bld/service/ptf-bucket.txt
exists in this branch, and the first non-comment line has a PTF number.
(See smpe/bld/service/_README.txt for ptf-bucket.txt layout details.)
If a PTF package (++PTF) is created, then this package will be staged
for promotion. If this build is promoted, then the PTF package will be
published on zowe.org.

APAR (service) build
--------------------
The SMP/E packaging build always creates a service package that matches
the current zowe.pax build. The type of service, USERMOD, APAR, or
PTF, depends on various factors explained next. The result is placed in
Artifactory as [FMID].[SYSMOD].zip.
An APAR-fix package (++APAR) is created if smpe/bld/service/ptf-bucket.txt
exists in this branch, and the first non-comment line has an APAR number.
(See smpe/bld/service/_README.txt for ptf-bucket.txt layout details.)
An APAR-fix will never be published on zowe.org, but can be retrieved
from Artifactory and provided to a customer that requires an SMP/E
installable fix.
Since an APAR-fix build requires updates to the zowe-install-packaging
repository, the creation of an APAR-fix requires the assistance of a
Zowe build engineer.
1. Open smpe/bld/service/apar-bucket.txt and comment out the line
   holding the APAR you want to use for this build. Before commenting,
   copy the line. Contact a Zowe build engineer working for IBM if
   there is no APAR number available.
2. Add the copied line as first line in smpe/bld/service/ptf-bucket.txt.
   This will tell the SMP/E packaging build to create an APAR-fix
   instead of a PTF.
3. Start a SMP/E packaging build to create the APAR-fix package.
4. Open smpe/bld/service/ptf-bucket.txt, copy the APAR line and then
   delete it (to revert to PTF build on the next build).
5. Open/create smpe/bld/service/current-apar.txt and add the copied
   line. This will tell the SMP/E packaging build to SUP the APAR in
   future PTF and USERMOD builds.
6. The updated smpe/bld/service/current-apar.txt must be part of the
   final pull request and trickle up to the staging branch so that it
   becomes part of the 'official' PTF build published on zowe.org.
During promote, smpe/bld/service/current-apar.txt will be erased from
the staging branch, as the APAR(s) listed here are now part of the PTF
and no longer need special handling. The promote process keeps track
of all APARs and PTFs that have been promoted (see the description of
promoted-*.txt in smpe/bld/service/_README.txt for details).

SMP/E terminology
-----------------
SMP/E         (System Modification Program/Extended)
              A tool to manage the installation of software products on
              a z/OS system and to manage updates to those products.
sysmod        (SYStem MODification)
              Comparable to the build result of a GitHub branch.
              A change-set that, when applied, modifies your system.
              This can be a ++FUNCTION, ++PTF, ++APAR, or ++USERMOD.
FMID          (Function Modification IDentifier)
              SMP/E keyword: ++FUNCTION
              Comparable to the build result of the RC (release candidate)
              GitHub branch.
              Base level of a software product. Once installed and
              configured, this product can be used. All future updates
              must be applied on top of this base, even if the update is
              a full product replacement.
              With Zowe, each official convenience build with a version
              change (V in VRM) will have a matching FMID.
APAR          (Authorized Program Analysis Report)
              Comparable to a GitHub issue.
              Describes a bug in / enhancement for the code/documentation.
              When the first Zowe SMP/E package was created, APARs used
              naming convention IOxxxxx to ensure uniqueness, where
              xxxxx is a 5-digit number. This might change in the future.
APAR-fix      SMP/E keyword: ++APAR
              Comparable to the build result of a personal GitHub branch.
              A change-set that, once installed, provides a solution for
              the issue described in the related APAR. APAR-fixes are
              normally only used internally for testing the change-set,
              but can be given to a customer for testing/emergency fix.
              The name of an APAR-fix matches the name of the related
              APAR, with the first letter changed to A, so AOxxxxx.
              APAR-fixes will PRE all previous PTFs, and therefore
              always require that the latest PTF is installed. Once an
              APAR-fix passes all testing, it will be embedded in the
              next PTF build. This implies that unlike for a USERMOD,
              if a customer installed an APAR-fix, the PTF can be
              installed without first removing the APAR-fix.
PTF           (Program Temporary Fix)
              SMP/E keyword: ++PTF
              Comparable to the build result of the RC (release candidate)
              GitHub branch.
              Once an APAR-fix passes all testing, it is made available
              to all customers as PTF, which is the official solution
              for the issue described in the related APAR. A PTF can
              hold one or more APAR fixes.
              When the first Zowe SMP/E package was created, PTFs used
              naming convention UOxxxxx to ensure uniqueness, where
              xxxxx is a 5-digit number. This might change in the future.
              With Zowe, each official convenience build that does not
              have a version change (V in VRM) will have a matching PTF.
              With Zowe, a PTF will always SUP all APAR-fixes that are
              embedded in this PTF, and all previous PTFs. This implies
              that by installing a PTF, you automatically get all
              current and previous service.
USERMOD       (USER MODification)
              SMP/E keyword: ++USERMOD
              Comparable to the build result of a personal GitHub branch.
              A USERMOD allows a customer to inform SMP/E of changes
              to a product that are introduced by the customer instead
              of product development. A typical example is a
              customized sample user exit, like a security exit that
              provides site-specific password rules to the security
              product. The customer will update and compile the sample
              exit provided by the product, and create a USERMOD to
              let SMP/E know the file was changed. SMP/E will now
              warn the customer if the product wants to change this
              sample exit, so that the customer can redo his changes
              and recompile the code.
              Zowe does not have user exits, but uses USERMODs as a
              vehicle to provide unofficial product updates that follow
              SMP/E standards (used mostly by automated testing).
              Note that APAR-fixes and PTFs will never PRE or SUP a
              USERMOD. This implies that once a USERMOD is installed,
              this USERMOD must be removed before an APAR-fix or PTF
              can be installed. This also implies that a USERMOD is
              flexible and can be created based on an older PTF service
              level.
REQ           (REQuisite)
              When present, this keyword is followed by a names list of
              sysmods that must be installed at the same time this sysmod
              is installed. Used to overcome sysmod size limitations.
PRE           (PRE-requisite)
              When present, this keyword is followed by a names list of
              sysmods that must be already present or be installed at
              the same time this sysmod is installed. It indicates that
              this sysmod builds on top of the listed sysmods.
              PTFs only PRE other PTFs, never APAR-fixes or USERMODs.
              PTFs and APAR-fixes never PRE USERMODs.
SUP           (SUPersede)
              When present, this keyword is followed by a names list of
              sysmods that are included in this sysmod. SMP/E does
              nothing special when such a sysmod is already present,
              and marks it as present during install when it isn't.
              APAR-fixes and USERMODs never SUP PTFs (they PRE them),
              even with full product replacements.
              PTFs and APAR-fixes never SUP USERMODs.
part          A file for which metadata is defined to SMP/E. SMP/E can
              only update known parts. A part has a type, which
              determines how SMP/E treats it. Some examples: "++SAMP"
              is a (sample) text member, "++LMOD" is a load module,
              "++HFS" is a z/OS UNIX file, etc.
closing info  Comparable to the info provided in a GitHub pull request.
              Once an APAR-fix has been tested, the related APAR is
              closed. At this point, closing information is provided,
              which is later used by automation to document the change.
hold info     There is no traditional GitHub equivalent, but the Zowe
              GitHub pull request template does have a section for it.
              Hold information is information that is pertinent to the
              installation or customization of the sysmod, and thus
              must be provided to the person installing the sysmod at
              install time. Some examples: "restart the server after
              installing this sysmod", "this sysmod introduces new
              configuration option abc to control xyz", etc.
