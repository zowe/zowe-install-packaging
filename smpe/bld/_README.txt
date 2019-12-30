Flow for SMP/E packaging build
------------------------------
smpe.sh          Wrapper to drive Zowe SMP/E packaging
smpe-install.sh  Install Zowe convenience build in staging area
smpe-split.sh    Split installed product in smaller chunks and pax them
smpe-fmid.sh     Create FMID (++FUNCTION)
smpe-gimzip.sh   Create downloadable archive of FMID (pax.Z)
smpe-pd.sh       Create Program Directory (SMP/E install documentation)
smpe-service.sh  Create fix-pack (++PTF/++APAR/++USERMOD)

Additional tools
----------------
smpe-config.sh   Recreate smpe.yaml configuration file
smpe-promote.sh  Update SMPE/E build input during promote of current build

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
              Comparable to the build result of the master GitHub branch.
              Base version of a software product. Once installed and
              configured, this product can be used. All future updates
              must be applied on top of this base, even if the update is
              a full product replacement.
              With Zowe, each official convenience build with a version 
              change will have a matching FMID.
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
PTF           (Program Temporary Fix)
              SMP/E keyword: ++PTF
              Comparable to the build result of the master GitHub branch.
              Once an APAR-fix passes all testing, it is made available
              to all customers as PTF, which is the official solution
              for the issue described in the related APAR. A PTF can 
              hold one or more APAR fixes.
              When the first Zowe SMP/E package was created, PTFs used
              naming convention UOxxxxx to ensure uniqueness, where
              xxxxx is a 5-digit number. This might change in the future.
              With Zowe, each official convenience build that does not 
              have a version change will have a matching PTF.
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
              configuration option abc to control xyz.", etc.

