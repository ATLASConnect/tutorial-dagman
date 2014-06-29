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
