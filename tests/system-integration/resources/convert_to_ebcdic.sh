#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project. 2018, 2024
#######################################################################

# Taken as-is from .pax/pre-packaging.sh, swapped encodings
#
# Used as part of globalSetup to ensure the `bin/` folder is in the right encoding

# ---------------------------------------------------------------------
# --- convert files to ascii
# $1: (input) pattern to convert.
#              Files will be determined by 'find <pattern> -type f'
# $2: (input) optional output directory.
#              If unset, conversion happens in-place
#              If set, conversion will mirror directory structure in output
# (output) converted files or directory following $2
# ---------------------------------------------------------------------
function _convertAsciiToEbcdic {
  input=$1
  output_dir=$2
  using_output_dir="no"
  if [ -z "$output_dir" ]; then
    echo "[$SCRIPT_NAME] converting $input to ebcdic in-place"
  else
    if [ -f "$output_dir" ]; then
      echo "[$SCRIPT_NAME] $output_dir already exists and is a file, aborting _convertAsciiToEbcdic"
      return 1
    elif [ ! -d "$output_dir" ]; then
      mkdir -p "$output_dir"
    fi
    using_output_dir="yes"
    echo "[$SCRIPT_NAME] will convert $input to ebcdic, results in $output_dir"
  fi

  files_to_convert=$(find $input -type f) # processes all files
  for ascii_file in $files_to_convert; do
    echo "[$SCRIPT_NAME] converting $ascii_file to ebcdic..."
    tmpfile="$(basename $ascii_file).tmp"
    iconv -f ISO8859-1 -t IBM-1047 "${ascii_file}" >${tmpfile}
    if [[ "$using_output_dir" == "yes" ]]; then
      dir_path=$(dirname $ascii_file)
      mkdir -p ${output_dir}/${dir_path}
      mv "${tmpfile}" "${output_dir}/${ascii_file}"
    else
      mv "${tmpfile}" "${ascii_file}"
    fi
  done

  return 0
} # _convertAsciiToEbcdic

_convertAsciiToEbcdic "./bin"
