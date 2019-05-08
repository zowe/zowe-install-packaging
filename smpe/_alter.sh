#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# 5698-ZWE Copyright Contributors to the Zowe Project. 2019, 2019
#######################################################################

# Adjust product to test new install scenario without updating build.
#
# Arguments:
# -d           (optional) debug mode
# PROD | SMPE  keyword indicating which install must be updated
# dir          target directory ($INSTALL_DIR)

new=/bld/zowe/_new             # location of overrides
me=$(basename $0)              # script name
#debug=-d                      # -d or null, -d triggers early debug
 IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo
test "$debug" && echo "> $me $@"

# ---------------------------------------------------------------------
function _product
{
# make zss part of base pax - update in Zowe build process
_cmd mkdir -p $dir/files/zss
_cmd cd $dir/files/zss
_cmd pax -r -px -f $dir/files/zss.pax
_cmd rm -f $dir/files/zss.pax

# clear data that will be replaced 
_cmd rm -r $dir/install/*                                           #*/
_cmd rm -r $dir/scripts/*                                           #*/
_cmd rm -r $dir/files/templates/*                                   #*/
_cmd rm -r $dir/files/zss/SAMPLIB/*                                 #*/

# add overrides - update in Zowe build process
_cmd cp $new/ZWESIP00                            $dir/files/zss/SAMPLIB
_cmd cp $new/ZWESIPRG                            $dir/files/zss/SAMPLIB
_cmd cp $new/ZWESISCH                            $dir/files/zss/SAMPLIB
_cmd cp $new/ZWESISTC.jcl                        $dir/files/zss/SAMPLIB
_cmd cp $new/ZWESECUR.jcl                        $dir/files/templates
_cmd cp $new/ZWESTC.jcl                          $dir/files/templates
_cmd cp $new/zowe.yaml                           $dir/install
_cmd cp $new/zowe-install.sh                     $dir/install
_cmd cp $new/zowe-configure.sh                   $dir/install
_cmd cp $new/zowe-parse-yaml.sh                  $dir/scripts
_cmd cp $new/zowe-set-envvars.sh                 $dir/scripts
_cmd cp $new/zowe-install-zlux.sh                $dir/scripts
_cmd cp $new/zowe-install-api-mediation.sh       $dir/scripts
_cmd cp $new/zowe-install-explorer-api.sh        $dir/scripts
_cmd cp $new/zowe-install-explorer-ui.sh         $dir/scripts
_cmd cp $new/zowe-install-misc.sh                $dir/scripts
_cmd cp $new/zowe-install-samplib.sh             $dir/scripts
_cmd cp $new/zowe-install-authlib.sh             $dir/scripts
_cmd cp $new/allocate-dataset.sh                 $dir/scripts
_cmd cp $new/check-dataset-exist.sh              $dir/scripts
_cmd cp $new/check-dataset-dcb.sh                $dir/scripts
_cmd cp $new/unpax.sh                            $dir/scripts
_cmd cp $new/copy.sh                             $dir/scripts
#_cmd cp $new/                                    $dir/scripts
}    # _product
# ---------------------------------------------------------------------
function _smpe
{
_cmd cp $new/ZWE1SMPE.jcl                                  $dir/MVS
_cmd cp $new/ZWE2RCVE.jcl                                  $dir/MVS
_cmd cp $new/ZWE3ALOC.jcl                                  $dir/MVS
_cmd cp $new/ZWE4ZFS.jcl                                   $dir/MVS
_cmd cp $new/ZWE5MKD.jcl                                   $dir/MVS
_cmd cp $new/ZWE6DDEF.jcl                                  $dir/MVS
_cmd cp $new/ZWE7APLY.jcl                                  $dir/MVS
_cmd cp $new/ZWE8ACPT.jcl                                  $dir/MVS
_cmd cp $new/ZWEMKDIR.rex                                  $dir/MVS
_cmd cp $new/ZWEMOUNT.rex                                  $dir/MVS
_cmd cp $new/ZWESHPAX.sh                                   $dir/USS
_cmd cp $new/allocate-dataset.sh                           $dir/scripts
_cmd cp $new/check-dataset-exist.sh                        $dir/scripts
_cmd cp $new/check-dataset-dcb.sh                          $dir/scripts
#_cmd cp $new/                                              $dir/scripts
}    # _smpe

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $1: if --repl then save stdout to $2, parms are removed when present
# $2: if $1 = --save or --repl then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _cmd
{
test "$debug" && echo
if test "$1" = "--null"
then         # stdout -> null, stderr -> stdout (without going to null)
  shift
  test "$debug" && echo "$@ 2>&1 >/dev/null"
                         $@ 2>&1 >/dev/null
elif test "$1" = "--save"
then         # stdout -> >>$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 >> $sAvE"
                         $@ 2>&1 >> $sAvE
elif test "$1" = "--repl"
then         # stdout -> >$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 > $sAvE"
                         $@ 2>&1 > $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "$@ 2>&1"
                         $@ 2>&1
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _cmd

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing

echo "**"
echo "** WARNING: EXTERNAL OVERRIDE OF INSTALL PROCESS"
echo "**"

# get startup arguments
while getopts d opt
do case "$opt" in
  d)   export debug="-d";;
  [?]) echo "** ERROR $me faulty startup argument: $@"
       test ! "$IgNoRe_ErRoR" && exit 8;;                        # EXIT
  esac    # $opt
done    # getopts
shift $OPTIND-1

dir=$2

if test ! -d $dir
then
  echo "** ERROR $me $dir is not a directory"
  echo "ls -ld \"$dir\""; ls -ld "$dir"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

_cmd chmod 755 $new/*                                               #*/
test "$1" = "PROD" && _product
test "$1" = "SMPE" && _smpe

test "$debug" && echo "< $me 0"
exit 0
