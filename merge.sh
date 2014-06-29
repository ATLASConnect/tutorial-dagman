#!/bin/bash

export HOME=${PWD}

OUTPUT=${1}
INPUT=${2}

echo "Setup ROOT"

export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
export ALRB_localConfigDir=$HOME/localConfig
source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh

localSetupROOT

hadd -f output.root /home/${USER}/faxbox/dagman_tutorial/*.root > merge.log