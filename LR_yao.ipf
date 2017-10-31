#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "SIS_kspace"
#include "LR_yao_panel"

Function Panel_kspace_init()
	newdatafolder/o root:LR
	Variable/G root:LR:wavedim0,root:LR:wavedim1,root:LR:wavedim2,root:LR:wavedim3
	Variable/G root:LR:wavedelta0,root:LR:wavedelta1,root:LR:wavedelta2,root:LR:wavedelta3
	Variable/G root:LR:wavesize0,root:LR:wavesize1,root:LR:wavesize2,root:LR:wavesize3

	Variable/G root:LR:gamma_tilt=0, root:LR:gamma_theta=0,root:LR:E_F=0,root:LR:hv=50,root:LR:V0=10
	Make/O root:LR:kz_hv,root:LR:kx_hv,root:LR:theta_=-15+40/127*p

	Execute "Panel_kspace()"
end
