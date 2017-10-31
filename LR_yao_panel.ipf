#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "SIS_kspace"

//Function kspace_panel_func()
Window Panel_kspace() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(1115,57,1424,421)
	TitleBox version,pos={204,328},size={78,19},title="2017-1011-1339",fSize=8
	TitleBox version,fColor=(1,0,0)
	Button Duplicate,pos={100,8},size={70,28},proc=ButtonProc_Backup,title="Duplicate"
	Button setzero,pos={12,178},size={70,28},proc=ButtonProc_SetZero,title="SetZero"
	Button getinfo,pos={8,8},size={70,28},proc=ButtonProc_GetInfo,title="GetInfo"
	PopupMenu popup0,pos={11,63},size={60,17},proc=PopMenuProc_x
	PopupMenu popup0,mode=2,popvalue="theta",value= #"\"Eb;theta;tilt;hv;none\""
	PopupMenu popup1,pos={11,87},size={44,17},proc=PopMenuProc_y
	PopupMenu popup1,mode=1,popvalue="Eb",value= #"\"Eb;theta;tilt;hv;none\""
	PopupMenu popup2,pos={12,111},size={42,17},proc=PopMenuProc_z
	PopupMenu popup2,mode=3,popvalue="tilt",value= #"\"Eb;theta;tilt;hv;none\""
	PopupMenu popup3,pos={12,135},size={59,17},proc=PopMenuProc_t
	PopupMenu popup3,mode=5,popvalue="none",value= #"\"Eb;theta;tilt;hv;none\""
	SetVariable Gammatilt,pos={162,186},size={60,19},proc=SetVarProc_tilt,title=" "
	SetVariable Gammatilt,limits={-inf,inf,0},value= root:LR:gamma_tilt
	SetVariable GammaTheta,pos={93,186},size={60,19},proc=SetVarProc_theta,title=" "
	SetVariable GammaTheta,limits={-inf,inf,0},value= root:LR:gamma_theta
	SetVariable wavedim0,pos={83,62},size={70,19},proc=SetVarProc,title="x"
	SetVariable wavedim0,limits={-inf,inf,0},value= root:LR:wavedim0
	SetVariable wavedim1,pos={83,86},size={70,19},proc=SetVarProc,title="y"
	SetVariable wavedim1,limits={-inf,inf,0},value= root:LR:wavedim1
	SetVariable wavedim2,pos={83,110},size={70,19},proc=SetVarProc,title="z"
	SetVariable wavedim2,limits={-inf,inf,0},value= root:LR:wavedim2
	SetVariable wavedim3,pos={83,134},size={70,19},proc=SetVarProc,title="t"
	SetVariable wavedim3,limits={-inf,inf,0},value= root:LR:wavedim3
	SetVariable wavedelta0,pos={162,62},size={60,19},title=" "
	SetVariable wavedelta0,limits={-inf,inf,0},value= root:LR:wavedelta0,noedit= 1
	SetVariable wavedelta1,pos={162,86},size={60,19},title=" "
	SetVariable wavedelta1,limits={-inf,inf,0},value= root:LR:wavedelta1,noedit= 1
	SetVariable wavedelta2,pos={162,110},size={60,19},title=" "
	SetVariable wavedelta2,limits={-inf,inf,0},value= root:LR:wavedelta2,noedit= 1
	SetVariable wavedelta3,pos={162,134},size={60,19},title=" "
	SetVariable wavedelta3,limits={-inf,inf,0},value= root:LR:wavedelta3,noedit= 1
	Button AngToK,pos={12,218},size={85,28},proc=ButtonProc_DoTransform,title="DoTransform"
	SetVariable hv,pos={45,284},size={90,19},proc=SetVarProc_hv,title="hv"
	SetVariable hv,limits={0,inf,1},value= root:LR:hv
	GroupBox group0,pos={32,260},size={117,53},title="Fermi mapping",frame=0
	GroupBox group1,pos={172,260},size={117,53},title="hv dependence",frame=0
	SetVariable V0,pos={186,284},size={90,19},proc=SetVarProc_V0,title="V0"
	SetVariable V0,limits={0,inf,0.5},value= root:LR:V0
	SetVariable E_F,pos={231,186},size={60,19},proc=SetVarProc_ef,title=" "
	SetVariable E_F,limits={-inf,inf,0},value= root:LR:E_F
	Button Plot_kz,pos={191,8},size={70,28},proc=Plot_kz,title="Plot_kz"
	SetVariable waveend0,pos={231,62},size={60,19},title=" "
	SetVariable waveend0,limits={-inf,inf,0},value= root:LR:wavesize0,noedit= 1
	SetVariable waveend1,pos={231,86},size={60,19},title=" "
	SetVariable waveend1,limits={-inf,inf,0},value= root:LR:wavesize1,noedit= 1
	SetVariable waveend2,pos={231,110},size={60,19},title=" "
	SetVariable waveend2,limits={-inf,inf,0},value= root:LR:wavesize2,noedit= 1
	SetVariable waveend3,pos={231,134},size={60,19},title=" "
	SetVariable waveend3,limits={-inf,inf,0},value= root:LR:wavesize3,noedit= 1
	TitleBox waveend,pos={250,44},size={19,15},title="end",fSize=11,frame=0
	TitleBox waveend,fColor=(1,0,0)
	TitleBox wavestart,pos={110,44},size={26,15},title="start",fSize=11,frame=0
	TitleBox wavestart,fColor=(1,0,0)
	TitleBox wavedelta,pos={178,44},size={27,15},title="delta",fSize=11,frame=0
	TitleBox wavedelta,fColor=(1,0,0)
	TitleBox titlebox_theta,pos={107,168},size={29,15},title="theta",fSize=11
	TitleBox titlebox_theta,frame=0,fColor=(1,0,0)
	TitleBox titlebox_tilt,pos={185,168},size={15,15},title="tilt",fSize=11,frame=0
	TitleBox titlebox_tilt,fColor=(1,0,0)
	TitleBox titlebox_E_F,pos={227,168},size={69,15},title="Fermi energy",fSize=11
	TitleBox titlebox_E_F,frame=0,fColor=(1,0,0)
EndMacro

Function Plot_kz(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			NVAR V0=root:LR:V0,hv=root:LR:hv
			WAVE theta_=root:LR:theta_,kx_hv=root:LR:kx_hv,kz_hv=root:LR:kz_hv
			//String initialFolder = GetDataFolder(1)
			//String wList = GetBrowserSelectionList(1)
			//Wave w = $StringFromList(0, wList)
			//SetDataFolder $GetWavesDataFolder(w, 1)
			kx_hv=0.512*sqrt(hv-4.7)*sin(theta_/180*pi)
			kz_hv=0.512*sqrt(hv-4.7+V0)*cos(theta_/180*pi)
			AppendToGraph kz_hv vs kx_hv

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ButtonProc_GetInfo(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here

			String initialFolder = GetDataFolder(1)
			String wList = GetBrowserSelectionList(1)
			//Wave w = $StringFromList(0, wList)
			Wave w = $GetBrowserSelection(0)
			//SetDataFolder $GetWavesDataFolder(w, 1)
			NVAR dim0=root:LR:wavedim0,dim1=root:LR:wavedim1,dim2=root:LR:wavedim2,dim3=root:LR:wavedim3
			NVAR delta0=root:LR:wavedelta0,delta1=root:LR:wavedelta1,delta2=root:LR:wavedelta2,delta3=root:LR:wavedelta3
			NVAR size0=root:LR:wavesize0,size1=root:LR:wavesize1,size2=root:LR:wavesize2,size3=root:LR:wavesize3
			//NVAR tilt=root:LR:gamma_tilt, theta=root:LR:gamma_theta,E_F=root:LR:E_F
			//tilt=0
			//theta=0
			//E_F=0

			dim0=dimoffset($NameOfWave(w),0)
			dim1=dimoffset($NameOfWave(w),1)
			dim2=dimoffset($NameOfWave(w),2)
			dim3=dimoffset($NameOfWave(w),3)

			delta0=dimdelta($NameOfWave(w),0)
			delta1=dimdelta($NameOfWave(w),1)
			delta2=dimdelta($NameOfWave(w),2)
			delta3=dimdelta($NameOfWave(w),3)

			size0=dim0+delta0*dimsize($NameOfWave(w),0)
			size1=dim1+delta1*dimsize($NameOfWave(w),1)
			size2=dim2+delta2*dimsize($NameOfWave(w),2)
			size3=dim3+delta3*dimsize($NameOfWave(w),3)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ButtonProc_SetZero(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			String initialFolder = GetDataFolder(1)
			String wList = GetBrowserSelectionList(1)
			//Wave w = $StringFromList(0, wList)
			Wave w = $GetBrowserSelection(0)
			NVAR tilt=root:LR:gamma_tilt, theta=root:LR:gamma_theta,E_F=root:LR:E_F
			NVAR dim1=root:LR:popNum_x			//read dim1
			NVAR dim2=root:LR:popNum_y			//read dim1
			NVAR dim3=root:LR:popNum_z			//read dim3

			if (dim1==1&&dim2==2)		//SIS
				// Shift the angle scale by theta
				print nameofwave(w),"theta=",theta
				SetScale/P y, DimOffset(w, 1)-theta, DimDelta(w, 1), WaveUnits(w, 1), w
			endif
			if (dim1==2&&dim2==1)		//ADRESS
				// Shift the angle scale by theta
				print nameofwave(w),"theta=",theta
				SetScale/P x, DimOffset(w, 0)-theta, DimDelta(w, 0), WaveUnits(w, 0), w
			endif
			if (dim3==3)							//tilt exists
				// Shift the angle scale by tilt
				print "tilt=",tilt
				SetScale/P z, DimOffset(w, 2)-tilt, DimDelta(w, 2), WaveUnits(w, 2), w
			endif
			if(dim1==1&&E_F!=0)		//shift Fermi level
				print "E_F=",E_F
				SetScale/P x, DimOffset(w, 0)-E_F, DimDelta(w, 0), WaveUnits(w, 0), w
			endif
			if(dim2==1&&E_F!=0)		//ADRESS shift Fermi level
				print "E_F=",E_F
				SetScale/P y, DimOffset(w, 1)-E_F, DimDelta(w, 1), WaveUnits(w, 1), w
			endif

			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function ButtonProc_Backup(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			String initialFolder = GetDataFolder(1)
			String wList = GetBrowserSelectionList(1)
			Wave w = $StringFromList(0, wList)
			SetDataFolder $GetWavesDataFolder(w, 1)
			duplicate /o w,$nameofwave(w)+"_tmp"
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ButtonProc_DoTransform(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			String initialFolder = GetDataFolder(1)
			String wList = GetBrowserSelectionList(1)
			Wave w = $GetBrowserSelection(0)
			NVAR dim1=root:LR:popNum_x,dim2=root:LR:popNum_y,dim3=root:LR:popNum_z,dim4=root:LR:popNum_t
			NVAR hv=root:LR:hv,V0=root:LR:V0
			STRUCT kTransformSettings s
			WAVE s.rawData = w
			s.angularMode = 1
			s.slitAlongTheta = 1
			s.invertDetectorScale = 0
			s.rotateAzimuth = 0
			s.includePhotonMomentum = 0
			s.workFunction = 4.5
			s.innerPotential = V0
			s.destination = "root:'"+nameofwave(w)+"_kspace'"
			s.useInterpolation = 1
	//1=Eb,2=theta,3=tilt(along slit),4=hv,5=none
			if (dim1==1&&dim2==2&&dim3==3&&dim4==5)				//Fermi mapping
				print "Fermi mapping"
				s.fixedEnergy = -1
				s.energyDim = 0
				s.thetaDim = 1
				s.tiltDim = 2
				s.hvDim = -1
				s.fixedHv = hv
				k#Init(s)
				k#Transform(s)
			elseif (dim1==2&&dim2==1&&dim3==3&&dim4==5)				//ADRESS Fermi mapping
				print "ADRESS Fermi mapping"
				s.fixedEnergy = -1
				s.energyDim = 1
				s.thetaDim = 0
				s.tiltDim = 2
				s.hvDim = -1
				s.fixedHv = hv
				k#Init(s)
				k#Transform(s)
			elseif (dim1==1&&dim2==2&&dim3==4&&dim4==5)			//hv dependence
				print "hv dependence"
				s.fixedEnergy = -1
				s.energyDim = 0
				s.thetaDim = 1
				s.tiltDim = -1
				s.hvDim = 2
				s.fixedHv = -1
				k#Init(s)
				k#Transform(s)
			elseif (dim1==2&&dim2==1&&dim3==4&&dim4==5)			//ADRESS hv dependence
				print "ADRESS hv dependence"
				s.fixedEnergy = -1
				s.energyDim = 1
				s.thetaDim = 0
				s.tiltDim = -1
				s.hvDim = 2
				s.fixedHv = -1
				k#Init(s)
				k#Transform(s)
			elseif (dim1==1&&dim2==2&&dim3==5&&dim4==5)			//cut
				print "cut"
				s.fixedEnergy = -1
				s.energyDim = 0
				s.thetaDim = 1
				s.tiltDim = -1
				s.hvDim = -1
				s.fixedHv = hv
				k#Init(s)
				k#Transform(s)
			elseif (dim1==2&&dim2==1&&dim3==5&&dim4==5)			//cut
				print "cut"
				s.fixedEnergy = -1
				s.energyDim = 1
				s.thetaDim = 0
				s.tiltDim = -1
				s.hvDim = -1
				s.fixedHv = hv
				k#Init(s)
				k#Transform(s)
			else
				print "break"
				break						// Optionally execute if all conditions are FALSE
			endif
				break

		case -1: // control being killed
			break
	endswitch
		return 0
End

Function PopMenuProc_x(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	switch( pa.eventCode )
	case 2: // mouse up
		Variable popNum
		Variable/G root:LR:popNum_x = pa.popNum
	//String popStr = pa.popStr
	//print root:LR:popNum_x
		break
	case -1: // control being killed
		break
	endswitch
	return 0
End

Function PopMenuProc_y(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	switch( pa.eventCode )
	case 2: // mouse up
		Variable/G root:LR:popNum_y = pa.popNum
	//String popStr = pa.popStr
	//print root:LR:popNum_y
		break
	case -1: // control being killed
		break
	endswitch
	return 0
End

Function PopMenuProc_z(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	switch( pa.eventCode )
	case 2: // mouse up
		Variable/G root:LR:popNum_z = pa.popNum
	//String popStr = pa.popStr
		break
	case -1: // control being killed
		break
	endswitch
return 0
End

Function PopMenuProc_t(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	switch( pa.eventCode )
	case 2: // mouse up
		Variable/G root:LR:popNum_t = pa.popNum
	//String popStr = pa.popStr
		break
		case -1: // control being killed
		break
		endswitch
		return 0
End

Function SetVarProc_hv(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
	case 1: // mouse up
	case 2: // Enter key
	case 3: // Live update
	Variable/G root:LR:hv = sva.dval
	String sval = sva.sval
	break
case -1: // control being killed
	break
endswitch
return 0
End

Function SetVarProc_tilt(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
	case 1: // mouse up
	case 2: // Enter key
	case 3: // Live update
		Variable/G root:LR:gamma_tilt = sva.dval
		String sval = sva.sval
		break
	case -1: // control being killed
		break
	endswitch
return 0
End

Function SetVarProc_theta(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
	case 1: // mouse up
	case 2: // Enter key
	case 3: // Live update
		Variable/G root:LR:gamma_theta = sva.dval
		String sval = sva.sval
		break
	case -1: // control being killed
		break
	endswitch
return 0
End

Function SetVarProc_ef(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
	case 1: // mouse up
	case 2: // Enter key
	case 3: // Live update
		Variable/G root:LR:E_F = sva.dval
		String sval = sva.sval
		break
	case -1: // control being killed
		break
	endswitch
return 0
End

Function SetVarProc_V0(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	switch( sva.eventCode )
	case 1: // mouse up
	case 2: // Enter key
	case 3: // Live update
		Variable/G root:LR:V0 = sva.dval
		String sval = sva.sval
		break
	case -1: // control being killed
		break
	endswitch
		return 0
End
