#!/bin/bash

uname -a

export HOME=${PWD}

OUTPUT=${1}
INPUT=${2}

echo "Setup ROOT"

export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
export ALRB_localConfigDir=$HOME/localConfig
source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh

localSetupROOT

r=$(( $RANDOM % 2 ));
if [ "x${r}x" == "x0x" ]; then
    echo "JOB WILL WAIT"
    INPUT=fail.root
fi

root -b -q -l "plot.C+(\"${INPUT}\")"
if [ "x${?}x" != "x0x" ]; then
    echo "Macro failed!"
    exit 1
fi

xrdcp -f output.root root://faxbox.usatlas.org://user/kkrizka/dagman_tutorial/output.${OUTPUT}.root

rm output.root