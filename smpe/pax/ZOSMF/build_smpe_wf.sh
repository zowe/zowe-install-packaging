#!/bin/sh
set -x
awk -f ./build_smpe_wf.awk smpe_workflow.xml > ZWEWRF01.xml