#!/bin/sh

################################################################################
# This program and the accompanying materials are made available under the terms of the
# Eclipse Public License v2.0 which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright IBM Corporation 2022
################################################################################

function jfrog_search_latest {
    search_pattern=$1
    if [[ -z "$search_pattern" ]]; then
        echo -e "${RED}In jfrog search latest function, search pattern is not provided" > /dev/stderr
        exit 1
    fi
    out=$(jfrog rt search --sort-by=created --sort-order=desc --limit=1 "$search_pattern" | jq -r '.[].path')
    if [[ -z "$out" ]]; then
        echo -e "${RED}Cannot find latest artifact in pattern: $search_pattern" > /dev/stderr
        exit 1
    fi
    echo $out
}

function jfrog_search_build {
    search_pattern=$1
    build_name=$2
    bld_num=$3
    if [[ -z "$search_pattern" ]]; then
        echo -e "${RED}In jfrog_search_build function, search pattern is not provided" > /dev/stderr
        exit 1
    fi
    if [[ -z "$build_name" ]]; then
        echo -e "${RED}In jfrog_search_build function, build name is not provided" > /dev/stderr
        exit 1
    fi
    if [[ -z "$bld_num" ]]; then
        echo -e "${RED}In jfrog_search_build function, build number is not provided" > /dev/stderr
        exit 1
    fi
    out=$(jfrog rt search --build="$build_name/$bld_num" "$search_pattern" | jq -r '.[-1].path')
    if [[ "$out" == "null" ]]; then
        echo -e "${RED}Cannot find the artifact in pattern: $search_pattern associated with $bld_num of $build_name" > /dev/stderr
        exit 1
    fi
    echo $out
}

function assert_env_var {
    envvar_name=$1
    eval envvar_val='$'$envvar_name
    if [[ -z "$envvar_val" ]]; then
        echo -e "${RED}$envvar_name" is not set > /dev/stderr
        exit 1
    fi
}


