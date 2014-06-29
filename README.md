This tutorial describes how to leverage DagMAN to combine several steps in in an analysis into one script. The example includes running over multiple ROOT files in separate jobs, retrying failed jobs and automatically merging the results. For an introductory tutorial to DagMAN, refer to the official documentation.

The final code can be obtained from Git.
```
git clone git@github.com:ATLASConnect/tutorial-dagman.git
```

The first step is to create a DAG file that contains information about the Condor jobs and their interdependencies. The first part of this file should declare the different Condor files that should be run. Name this file *dagman_tutorial.dag*.

```
JOB PLOT1 plot.submit
JOB PLOT2 plot.submit
JOB PLOT3 plot.submit
```

This creates three different DagMAN nodes, each described by a different Condor submit file. The names of these nodes are **PLOT1**, **PLOT2** and **PLOT3**. Each will run over a different input NTUPle.

The next lines in the file declare variables that can be used to configure the Condor jobs. In this example, they set the path to the NTUPle that should be processed by the node and the name of the output file that will be copied to faxbox. The names of the variables will be **in** and **out**, and are referenced as `$(in)` and `$(out)` inside the Condor submit file.

```
VARS PLOT1 in="root://faxbox.usatlas.org://user/jolsson/rpv_GtoChi/datasets/SUSYBOOST/mc12_8TeV.183903.Herwigpp_UEEE3_CTEQ6L1_RPV_UDD_GluinoToChi_10q_M800_175.merge.NTUP_SUSYBOOST.e2406_s1581_s1586_r3658_r3549_p1364_tid01371979_00/NTUP_SUSYBOOST.01371979._000001.root.1" out="1"
VARS PLOT2 in="root://faxbox.usatlas.org://user/jolsson/rpv_GtoChi/datasets/SUSYBOOST/mc12_8TeV.183903.Herwigpp_UEEE3_CTEQ6L1_RPV_UDD_GluinoToChi_10q_M800_175.merge.NTUP_SUSYBOOST.e2406_s1581_s1586_r3658_r3549_p1364_tid01371979_00/NTUP_SUSYBOOST.01371979._000002.root.1" out="2"
VARS PLOT3 in="root://faxbox.usatlas.org://user/jolsson/rpv_GtoChi/datasets/SUSYBOOST/mc12_8TeV.183903.Herwigpp_UEEE3_CTEQ6L1_RPV_UDD_GluinoToChi_10q_M800_175.merge.NTUP_SUSYBOOST.e2406_s1581_s1586_r3658_r3549_p1364_tid01371979_00/NTUP_SUSYBOOST.01371979._000003.root.1" out="3"
```

The next lines in the file tell DagMAN to retry any failed nodes up to 100 times. A node is declared as failed if any job in its Condor cluster fails, indicated by a non-zero return code in the executable script. This is why each NTUPle is processed by a separate DagMAN node, so a single problematic job does not cause all of the jobs to fail.

```
RETRY PLOT1 100
RETRY PLOT2 100
RETRY PLOT3 100
```

The final lines in the file add one more DagMAN node, called **WAIT**, which will be responsible for merging the output of the first three nodes into a single ROOT file. This is done by adding a Condor dummy submit file, *wait.submit*, so the node can be forced to execute after all NTUPles have been processed. All of the processing is done in the `POST`-script, which is ran on the local computer after the **WAIT** Condor job finishes. The `NOOP` option means that the Condor job itself is not run, but the `PRE`/`POST`-scripts are still executed.

```
JOB WAIT wait.submit NOOP
SCRIPT POST WAIT merge.sh

PARENT PLOT1 PLOT2 PLOT3 CHILD WAIT
```

The Condor submit file, *plot.submit*, responsible for processing an NTUPle has the following contents.

```
universe = vanilla
executable = plot.sh
output =log.$(out)-$(Cluster).$(Process).out
error = log.$(out)-$(Cluster).$(Process).err
log = plot.log
when_to_transfer_output = ON_EXIT
should_transfer_files = YES
transfer_input_files = plot.C
+ProjectName="atlas-org-uchicago"
arguments = $(out) $(in)
queue
```

The executable script, *plot.sh*, has the following contents. It executes the ROOT macro *plot.C* using the third argument as the input. The first lines just setup ROOT and configuration.

```
#!/bin/bash

uname -a

export HOME=${PWD}

THEUSER=${1}
OUTPUT=${2}
INPUT=${3}

echo "Setup ROOT"

export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
export ALRB_localConfigDir=$HOME/localConfig
source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh

localSetupROOT

To demonstrate job failure, the next few lines randomly set the input file to fail.root. This will cause the ROOT macro to fail and return a non-zero code.

r=$(( $RANDOM % 2 ));
if [ "x${r}x" == "x0x" ]; then
    echo "JOB WILL WAIT"
    INPUT=fail.root
fi
```

The next few lines execute the ROOT macro and check its return code. The return code is checked by looking at the `${?}` variable. If it is non-zero, it also causes the execute script to also exit with a non-zero value.

```
root -b -q -l "plot.C+(\"${INPUT}\")"
if [ "x${?}x" != "x0x" ]; then
    echo "Macro failed!"
    exit 1
fi
```

Finally, copy the output file to faxbox like any other Condor job and clean-up.

```
xrdcp -f output.root root://faxbox.usatlas.org://user/${THEUSER}/dagman_tutorial/output.${OUTPUT}.root

rm output.root
```

The ROOT macro, *plot.C*, just does the plotting using the following code. Notice that it checks to make sure that the input file was opened correctly. Upon detecting the error, it returns value of `-1`. If the file was opened correctly, it returns `0`.

```
#include <TFile.h>
#include <TH1F.h>
#include <TTree.h>

#include <vector>
#include <iostream>

int plot(const TString& input)
{
  // Get the tree containing inputs and setup branches
  TFile *in=TFile::Open(input);
  if(in==0) return -1;

  TTree *susy=dynamic_cast<TTree*>(in->Get("susy"));

  susy->SetBranchStatus("*",0);

  susy->SetBranchStatus("jet_AntiKt4LCTopo_pt",1);
  std::vector<float> *jet_AntiKt4LCTopo_pt=new std::vector<float>();
  susy->SetBranchAddress("jet_AntiKt4LCTopo_pt", &jet_AntiKt4LCTopo_pt);

  // Prepare the outputs
  TFile *out=TFile::Open("output.root","RECREATE");

  TH1* hist=new TH1F("jet_pt_0",";Leading Jet P_{T} (GeV);Entries (per bin)",100,0,1000);

  // LOOP
  for(Int_t i=0;i<susy->GetEntries();i++)
    {
      if((i%1000)==0)
        std::cout << "Event " << i << std::endl;
      susy->GetEntry(i);

      if(jet_AntiKt4LCTopo_pt->size()>0)
        hist->Fill(jet_AntiKt4LCTopo_pt->at(0)*1e-3);
    }

  // Save
  out->cd();
  hist->Write();
  out->Close();

  return 0;
}
```

The contents of the dummy **WAIT** Condor submit file are as follows. The wait has to executable script, since it does not do nothing.

```
universe = vanilla
output = wait-$(Cluster).$(Process).out
error = wait-$(Cluster).$(Process).err
log = wait.log
+ProjectName="atlas-org-uchicago"
queue
```

The contents of **WAIT**’s `POST`-script, which does the merging, is as follows. This script is ran in the submitting directory, which means that the *output.root* file be stored there.

```
#!/bin/bash

export HOME=${PWD}

OUTPUT=${1}
INPUT=${2}

echo "Setup ROOT"

export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
export ALRB_localConfigDir=$HOME/localConfig
source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh

localSetupROOT

hadd -f output.root /home/${USER}/faxbox/dagman_tutorial/*.root
```
