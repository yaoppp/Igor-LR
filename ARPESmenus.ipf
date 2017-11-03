#pragma rtGlobals=1		// Use modern global access method.
#include "ARPESDataLoader"
#include "ARPESDataUtilities"
#include "BatchFitting"
#include "MappingTools"
#include "ARPESGraph"
#include "BitwiseOperations"
#include "WaveUtilities"
#include "NumericUtilities"
#include <WaveSelectorWidget>
#include "ARPEScustomMenu", optional
#include "MultiItemSelectDialog"
#include "Image_Tool4026_ncp"
#include "BackgroundRemoval"
#include "SIStem_HDF5"
#include "SIStemLabNotebook"
#include "LR_yao" //Yao tools
#include "HDF5_oldstyle"

Static Function IgorStartOrNewHook(igorApplicationNameStr)
	String igorApplicationNameStr

	Execute/Q "CreateBrowser"
	Execute/Q "ModifyBrowser appendUserButton={ARPES, \"ARPESMenuBtnClick()\", 1},echoCommands=0"
End

Function ARPESMenuBtnClick()
	PopupContextualMenu/N "ARPES"
End

Menu "ARPES", ContextualMenu
	Submenu "Data Loader"
		"Open...", /Q, ARPESMenu_ARPESDataLoader()
		"-"
		"Export Database as .txt...", /Q, Save/J/U={0,0,1,0} root:dataLoader:database:M_database as "database"
	End
	"-"
	"Load SIStem HDF5 data...", /Q, LoadSIStemHDF5_EasyMulti()
	"SIStem Lab Notebook...", /Q, SLN#Init(0);SLN#OpenGUI()
	"Load ADRESS HDF5 data...", /Q, LoadHDF5_EasyMulti_oldstyle()
	"Panel_kspace...", /Q, Panel_kspace_init()
	"-"
	Submenu "MDC Analysis"
		Submenu "Peak Fitting"
			"MDC Single-peak Batch Fit...", /Q, ARPESMenu_MDCSinglePeakBatchFit()
			"MDC Multi-peak Auto Batch Fit...", /Q, ARPESMenu_MDCMultipeakBatchFit()
		End
		Submenu "Post-Peak Fitting"
			"Fit Polynomial Bare Band...", /Q, ARPESMenu_FitPolyBareBand()
			"Get band velocity...", /Q, ARPESMenu_GetVelocity()
		End
		"Analyze MDC maxima...", /Q, ARPESMenu_MDCmaxima()
	End
	Submenu "EDC Analysis"
		"Analyze EDC maxima...", /Q, ARPESMenu_EDCmaxima()
		"EDC centers of mass...", /Q, ARPESMenu_EDCcom()
		"Analyze symmetrized kF EDCs...", /Q, ARPESMenu_symEDC()
		"Gap from EDC maxima...", /Q, ARPESMenu_GapFromEDC()
	End
	Submenu "Surface Mapping"
		"\\M0Extract Energy Surface (3D/4D)...", /Q, ARPESMenu_ExtractSurface()
		"\\M0Rotate (2D/3D)...", /Q, ARPESMenu_Rotate()
		"\\M0Find Origin (2D)...", /Q, ARPESMenu_FindOrigin()
		"\\M0Find Symmetry Angle (2D)...", /Q, ARPESMenu_FindSymmetryAngle()
		"\\M0Auto Normalize (2D)...", /Q, ARPESMenu_AutoNorm2D()
//		"\\M0Auto Normalize (3D)...", /Q, ARPESMenu_AutoNorm3D()
//		"Make Radial Slices...", /Q, ARPESMenu_RadialSlices()
//		"Fit Surface...", /Q, ARPESMenu_FitSurface()
	End
	Submenu "XPS"
		"\M0Remove Shirley Background (KE scale)...", /Q, ARPESMenu_RemoveShirleyBG()
		"Remove Linear Background...", /Q, ARPESMenu_RemoveLinearBG()
	End
	Submenu "Math"
		"1D Differentiation...", /Q, ARPESMenu_1DDifferentiate()
		"1D Integration...", /Q, ARPESMenu_1DIntegrate()
		"2D Laplacian...", /Q, ARPESMenu_2DLaplacian()
		"3D Laplacian...", /Q, ARPESMenu_3DLaplacian()
//		"1D Pseudo-curvature...", /Q, ARPESMenu_1DCurvature()
		"2D Pseudo-curvature...", /Q, ARPESMenu_2DCurvature()
//		"\\M0Normalize each slice (2D input)...", /Q, ARPESMenu_NormalizeSlices2D()
		"Smooth...", /Q, ARPESMenu_Smooth()
		"Normalize...", /Q, ARPESMenu_Normalize()
		"\\M0Sum/Avg/Area Along Axis...", /Q, ARPESMenu_SumAlongAxis()
	End
	Submenu "Wave Operations"
		"Concatenate...", /Q, ARPESMenu_Concatenate()
		help={"Appends waves to each other using Igor's Concatenate operation. For more details, see help for that operation."}
		"Downsample...", /Q, ARPESMenu_Downsample()
		"Crop...", /Q, ARPESMenu_Crop()
	End
	Submenu "Graph"
		"As E-vs.-k", /Q, ARPESMenu_GraphEvsK()
		"As Energy Surface", /Q, ARPESMenu_GraphMap()
		"In ImageTool", /Q, ARPESMenu_ImageTool()
//		"In ARPES Viewer", /Q, ARPESMenu_OpenInARPESviewer()
	End
//	"Sum along k or angle axis...", /Q, ARPESMenu_kSum()
//	"Find leading edge...", /Q, ARPESMenu_GapLeadingEdge()
End

Function ARPESMenu_RemoveShirleyBG()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable x1=-inf, x2=inf, sm=10
	Prompt x1, "Start kinetic energy (eV)"
	Prompt x2, "End kinetic energy (eV)"
	Prompt sm, "Boxcar smoothing factor (for no smoothing, set to <2)"
	DoPrompt "Remove Shirley XPS background: "+wList, x1, x2, sm
	if(V_flag)
		abort
	endif

	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		NewDataFolder/O/S GetWavesDataFolderDFR(w):RemoveShirleyBG
		NewDataFolder/O/S $NameOfWave(w)
		BackgroundRemoval#RemoveShirley(w, ke1=x1, ke2=x2, smoothNum=sm)
	endfor
	SetDataFolder initialFolder
End

Function ARPESMenu_RemoveLinearBG()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable x1=-inf, x2=inf, sm=10
	Prompt x1, "Start energy (eV)"
	Prompt x2, "End energy (eV)"
	Prompt sm, "Boxcar smoothing factor (for no smoothing, set to <2)"
	DoPrompt "Remove linear XPS background: "+wList, x1, x2, sm
	if(V_flag)
		abort
	endif

	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		NewDataFolder/O/S GetWavesDataFolderDFR(w):RemoveLinearBG
		NewDataFolder/O/S $NameOfWave(w)
		BackgroundRemoval#RemoveLinear(w, e1=x1, e2=x2, smoothNum=sm)
	endfor
	SetDataFolder initialFolder
End

Function ARPESMenu_2DCurvature()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable a = 1
	Variable sX = 0, sY = 0
	String planeList = "x-y;y-z;x-z;"
	String plane = StringFromList(0, planeList)
	Prompt a, "Scaling parameter \"I_0\""
	Prompt sX, "Horizontal smoothing factor (0 = no smoothing)"
	Prompt sY, "Vertical smoothing factor (0 = no smoothing)"
	Prompt plane, "Plane", popup, planeList
	DoPrompt "2D Pseudo-curvature: "+wList, a, sX, sY, plane
	if(V_flag)
		abort
	endif

	Variable dim
	strswitch(plane)
		case "x-y":
			dim = 2
			break
		case "y-z":
			dim = 0
			break
		case "x-z":
			dim = 1
			break
	endswitch

	DFREF tempFolder = NewFreeDataFolder()
	SetDataFolder tempFolder
	Variable i, j
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		NewDataFolder/O GetWavesDataFolderDFR(w):Curvature2D
		DFREF destFolder = GetWavesDataFolderDFR(w):Curvature2D
		if(WaveDims(w) == 2 && dim == 2)
			Curvature2D(w, I0=a, smthX=sX, smthY=sY)
			Wave M_curvature2D
			Duplicate/O M_curvature2D, destFolder:$NameOfWave(w)
			Wave dest = destFolder:$NameOfWave(w)
			Note/K dest, note(w)
			Note dest, "[Curvature2D]"
			Note dest, "I0="+num2str(a)
			Note dest, "smthX="+num2str(sX)
			Note dest, "smthY="+num2str(sY)
			Note dest, "plane="+plane
		elseif(WaveDims(w) == 3)
//			NewDataFolder/O GetWavesDataFolderDFR(w):Curvature2D
//			DFREF destFolder = GetWavesDataFolderDFR(w):Curvature2D
			if(dim ==2)
				Make/D/O/N=(DimSize(w, 0), DimSize(w, 1)) slice
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), slice
				SetScale/P y, DimOffset(w, 1), DimDelta(w, 1), slice
				for(j = 0; j < DimSize(w, dim); j += 1)
					slice = w[p][q][j]
					Curvature2D(slice, I0=a, smthX=sX, smthY=sY)
					Wave M_curvature2D
					if(j == 0)
						Make/D/O/N=(DimSize(M_curvature2D, 0), DimSize(M_curvature2D, 1), DimSize(w, dim)) destFolder:$NameOfWave(w)
						Wave dest = destFolder:$NameOfWave(w)
						SetScale/P x, DimOffset(M_curvature2D, 0), DimDelta(M_curvature2D, 0), WaveUnits(w, 0), dest
						SetScale/P y, DimOffset(M_curvature2D, 1), DimDelta(M_curvature2D, 1), WaveUnits(w, 1), dest
						SetScale/P z, DimOffset(w, 2), DimDelta(w, 2), WaveUnits(w, 2), dest
					endif
					Wave dest = destFolder:$NameOfWave(w)
					dest[][][j] = M_curvature2D[p][q]
				endfor
			elseif(dim == 1)
				Make/D/O/N=(DimSize(w, 0), DimSize(w, 2)) slice
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), slice
				SetScale/P y, DimOffset(w, 2), DimDelta(w, 2), slice
				for(j = 0; j < DimSize(w, dim); j += 1)
					slice = w[p][j][q]
					Curvature2D(slice, I0=a, smthX=sX, smthY=sY)
					Wave M_curvature2D
					if(j == 0)
						Make/D/O/N=(DimSize(M_curvature2D, 0), DimSize(w, dim), DimSize(M_curvature2D, 1)) destFolder:$NameOfWave(w)
						Wave dest = destFolder:$NameOfWave(w)
						SetScale/P x, DimOffset(M_curvature2D, 0), DimDelta(M_curvature2D, 0), WaveUnits(w, 0), dest
						SetScale/P y, DimOffset(w, dim), DimDelta(w, dim), WaveUnits(w, dim), dest
						SetScale/P z, DimOffset(M_curvature2D, 1), DimDelta(M_curvature2D, 1), WaveUnits(w, 2), dest
					endif
					Wave dest = destFolder:$NameOfWave(w)
					dest[][j][] = M_curvature2D[p][r]
				endfor
			elseif(dim == 0)
				Make/D/O/N=(DimSize(w, 1), DimSize(w, 2)) slice
				SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), slice
				SetScale/P y, DimOffset(w, 2), DimDelta(w, 2), slice
				for(j = 0; j < DimSize(w, dim); j += 1)
					slice = w[j][p][q]
					Curvature2D(slice, I0=a, smthX=sX, smthY=sY)
					Wave M_curvature2D
					if(j == 0)
						Make/D/O/N=(DimSize(w, dim), DimSize(M_curvature2D, 0), DimSize(M_curvature2D, 1)) destFolder:$NameOfWave(w)
						Wave dest = destFolder:$NameOfWave(w)
						SetScale/P x, DimOffset(w, dim), DimDelta(w, dim), WaveUnits(w, dim), dest
						SetScale/P y, DimOffset(M_curvature2D, 0), DimDelta(M_curvature2D, 0), WaveUnits(w, 1), dest
						SetScale/P z, DimOffset(M_curvature2D, 1), DimDelta(M_curvature2D, 1), WaveUnits(w, 2), dest
					endif
					Wave dest = destFolder:$NameOfWave(w)
					dest[j][][] = M_curvature2D[q][r]
				endfor
			endif
			Note/K dest, note(w)
			Note dest, "[Curvature2D]"
			Note dest, "I0="+num2str(a)
			Note dest, "smthX="+num2str(sX)
			Note dest, "smthY="+num2str(sY)
			Note dest, "plane="+plane
		else
			print "2D Curvature: Skipping "+StringFromList(i, wList)+". Only 2D or 3D waves are supported. Selected plane must be valid for the dimensionality."
		endif
	endfor

	SetDataFolder initialFolder
End

Function ARPESMenu_1DIntegrate()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	String axis = "x"		// axis to differentiate
	Variable order = 1		// derivative order
	Prompt axis, "Axis", popup, "x;y;z;t;"
	Prompt order, "Integration order"
	DoPrompt "1D Integration: "+wList, axis, order //, ds, dsMethod
	if(V_flag)
		abort
	endif

	Variable dim = WhichListItem(axis, "x;y;z;t;")
	Variable i, j
	for(i = 0; i < ItemsInList(wList); i += 1)
		WAVE w = $StringFromList(i, wList)
		NewDataFolder/O GetWavesDataFolderDFR(w):Integrate_1D
		DFREF destFolder = GetWavesDataFolderDFR(w):Integrate_1D
		Duplicate/O w, destFolder:$NameOfWave(w)
		WAVE result = destFolder:$NameOfWave(w)
		for(j = 0; j < order; j += 1)
			Integrate/DIM=(dim) result
		endfor
		Note/K result
		Note result, note(w)
		Note result, "[1D Integrate]"
		Note result, "axis="+axis
		Note result, "order="+num2str(order)
	endfor
End

Function ARPESMenu_ImageTool()	// display 2D/3D wave in the ImageTool developed by LBNL
	String wList = GetBrowserSelectionList(1)
	if(ItemsInList(wList) == 0)
		abort
	endif

	DFREF initialFolder = GetDataFolderDFR()

	String df
	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		if(WaveDims(w) == 2 || WaveDims(w) == 3)
			SetDataFolder root:
			NewImageTool("")
			DFREF wdf = GetWavesDataFolderDFR(w)
			SetDataFolder wdf
			df = ImageTool#getdf()
			SVAR imgfldr = $(df+"imgfldr")
			SVAR imgnam = $(df+"imgnam")
			SVAR datnam = $(df+"datnam")
			imgnam = NameOfWave(w)
			datnam = imgfldr+imgnam
			SetupImg()
//			NewImageTool(NameOfWave(w))
		endif
	endfor

	SetDataFolder initialFolder
End

Function ARPESMenu_SumAlongAxis()
	String wList = GetBrowserSelectionList(1)
	if(ItemsInList(wList) == 0)
		abort
	endif

	Variable lim1=-inf, lim2=inf
	String axisPopList = "x;y;z;t;"
	String axis = "x"
	String methodPopList = "Sum;Average;Area;"
	String method = "Sum"
	Prompt method, "Perform", popup, methodPopList
	Prompt axis, "Along axis", popup, axisPopList
	Prompt lim1, "From"
	Prompt lim2, "To"
	DoPrompt "Sum/Avg/Area along axis: "+wList, method, axis, lim1, lim2
	if(V_flag)
		abort
	endif

	Variable i, j, k, m
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		NewDataFolder/O GetWavesDataFolderDFR(w):SumAxis
		DFREF destFolder =  GetWavesDataFolderDFR(w):SumAxis

		if(WaveDims(w) == 1)
			Variable/G destFolder:$NameOfWave(w)
			NVAR destV = destFolder:$NameOfWave(w)
			if(stringmatch(axis,"x"))
				if(stringmatch(method, "Sum"))
					destV = sum(w, lim1, lim2)
				elseif(stringmatch(method, "Average"))
					destV = mean(w, lim1, lim2)
				elseif(stringmatch(method, "Area"))
					destV = area(w, lim1, lim2)
				endif
			else
				print "Sum/Avg/Area Along Axis: Skipping "+StringFromList(i, wList)+". Axis is incompatible with dimensions."
			endif

		elseif(WaveDims(w) == 2)
			if(stringmatch(axis, "x"))
				Make/D/FREE/N=(DimSize(w, 0)) temp
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), temp
				Make/D/O/N=(DimSize(w, 1)) destFolder:$NameOfWave(w)
				Wave dest = destFolder:$NameOfWave(w)
				SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), dest
				for(j = 0; j < numpnts(dest); j += 1)
					temp = w[p][j]
					if(stringmatch(method, "Sum"))
						dest[j] = sum(temp, lim1, lim2)
					elseif(stringmatch(method, "Average"))
						dest[j] = mean(temp, lim1, lim2)
					elseif(stringmatch(method, "Area"))
						dest[j] = area(temp, lim1, lim2)
					endif
				endfor
				KillWaves temp
			elseif(stringmatch(axis, "y"))
				Make/D/FREE/N=(DimSize(w, 1)) temp
				SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), temp
				Make/D/O/N=(DimSize(w, 0)) destFolder:$NameOfWave(w)
				Wave dest = destFolder:$NameOfWave(w)
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), WaveUnits(w, 0), dest
				for(j = 0; j < numpnts(dest); j += 1)
					temp = w[j][p]
					if(stringmatch(method, "Sum"))
						dest[j] = sum(temp, lim1, lim2)
					elseif(stringmatch(method, "Average"))
						dest[j] = mean(temp, lim1, lim2)
					elseif(stringmatch(method, "Area"))
						dest[j] = area(temp, lim1, lim2)
					endif
				endfor
				KillWaves temp
			else
				print "Sum/Avg/Area Along Axis: Skipping "+StringFromList(i, wList)+". Axis is incompatible with dimensions."
			endif
		elseif(WaveDims(w) == 3)
			if(stringmatch(axis, "x"))
				Make/D/FREE/N=(DimSize(w, 0)) temp
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), temp
				Make/D/O/N=(DimSize(w, 1), DimSize(w, 2)) destFolder:$NameOfWave(w)
				Wave dest = destFolder:$NameOfWave(w)
				SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), dest
				SetScale/P y, DimOffset(w, 2), DimDelta(w, 2), WaveUnits(w, 2), dest
				for(j = 0; j < DimSize(dest, 0); j += 1)
					for(k = 0; k < DimSize(dest, 1); k += 1)
						temp = w[p][j][k]
						if(stringmatch(method, "Sum"))
							dest[j][k] = sum(temp, lim1, lim2)
						elseif(stringmatch(method, "Average"))
							dest[j][k] = mean(temp, lim1, lim2)
						elseif(stringmatch(method, "Area"))
							dest[j][k] = area(temp, lim1, lim2)
						endif
					endfor
				endfor
				KillWaves temp
			elseif(stringmatch(axis, "y"))
				Make/D/FREE/N=(DimSize(w, 1)) temp
				SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), temp
				Make/D/O/N=(DimSize(w, 0), DimSize(w, 2)) destFolder:$NameOfWave(w)
				Wave dest = destFolder:$NameOfWave(w)
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), WaveUnits(w, 0), dest
				SetScale/P y, DimOffset(w, 2), DimDelta(w, 2), WaveUnits(w, 2), dest
				for(j = 0; j < DimSize(dest, 0); j += 1)
					for(k = 0; k < DimSize(dest, 1); k += 1)
						temp = w[j][p][k]
						if(stringmatch(method, "Sum"))
							dest[j][k] = sum(temp, lim1, lim2)
						elseif(stringmatch(method, "Average"))
							dest[j][k] = mean(temp, lim1, lim2)
						elseif(stringmatch(method, "Area"))
							dest[j][k] = area(temp, lim1, lim2)
						endif
					endfor
				endfor
				KillWaves temp
			elseif(stringmatch(axis, "z"))
				Make/D/FREE/N=(DimSize(w, 2)) temp
				SetScale/P x, DimOffset(w, 2), DimDelta(w, 2), temp
				Make/D/O/N=(DimSize(w, 0), DimSize(w, 1)) destFolder:$NameOfWave(w)
				Wave dest = destFolder:$NameOfWave(w)
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), WaveUnits(w, 0), dest
				SetScale/P y, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), dest
				for(j = 0; j < DimSize(dest, 0); j += 1)
					for(k = 0; k < DimSize(dest, 1); k += 1)
						temp = w[j][k][p]
						if(stringmatch(method, "Sum"))
							dest[j][k] = sum(temp, lim1, lim2)
						elseif(stringmatch(method, "Average"))
							dest[j][k] = mean(temp, lim1, lim2)
						elseif(stringmatch(method, "Area"))
							dest[j][k] = area(temp, lim1, lim2)
						endif
					endfor
				endfor
				KillWaves temp
			else
				print "Sum/Avg/Area Along Axis: Skipping "+StringFromList(i, wList)+". Axis is incompatible with dimensions."
			endif
		elseif(WaveDims(w) == 4)
			if(stringmatch(axis, "x"))
				Make/D/FREE/N=(DimSize(w, 0)) temp
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), temp
				Make/D/O/N=(DimSize(w, 1), DimSize(w, 2), DimSize(w, 3)) destFolder:$NameOfWave(w)
				Wave dest = destFolder:$NameOfWave(w)
				SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), dest
				SetScale/P y, DimOffset(w, 2), DimDelta(w, 2), WaveUnits(w, 2), dest
				SetScale/P z, DimOffset(w, 3), DimDelta(w, 3), WaveUnits(w, 3), dest
				for(j = 0; j < DimSize(dest, 0); j += 1)
					for(k = 0; k < DimSize(dest, 1); k += 1)
						for(m = 0; m < DimSize(dest, 2); m += 1)
							temp = w[p][j][k][m]
							if(stringmatch(method, "Sum"))
								dest[j][k][m] = sum(temp, lim1, lim2)
							elseif(stringmatch(method, "Average"))
								dest[j][k][m] = mean(temp, lim1, lim2)
							elseif(stringmatch(method, "Area"))
								dest[j][k][m] = area(temp, lim1, lim2)
							endif
						endfor
					endfor
				endfor
				KillWaves temp
			elseif(stringmatch(axis, "y"))
				Make/D/FREE/N=(DimSize(w, 1)) temp
				SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), temp
				Make/D/O/N=(DimSize(w, 0), DimSize(w, 2), DimSize(w, 3)) destFolder:$NameOfWave(w)
				Wave dest = destFolder:$NameOfWave(w)
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), WaveUnits(w, 0), dest
				SetScale/P y, DimOffset(w, 2), DimDelta(w, 2), WaveUnits(w, 2), dest
				SetScale/P z, DimOffset(w, 3), DimDelta(w, 3), WaveUnits(w, 3), dest
				for(j = 0; j < DimSize(dest, 0); j += 1)
					for(k = 0; k < DimSize(dest, 1); k += 1)
						for(m = 0; m < DimSize(dest, 2); m += 1)
							temp = w[j][p][k][m]
							if(stringmatch(method, "Sum"))
								dest[j][k][m] = sum(temp, lim1, lim2)
							elseif(stringmatch(method, "Average"))
								dest[j][k][m] = mean(temp, lim1, lim2)
							elseif(stringmatch(method, "Area"))
								dest[j][k][m] = area(temp, lim1, lim2)
							endif
						endfor
					endfor
				endfor
				KillWaves temp
			elseif(stringmatch(axis, "z"))
				Make/D/FREE/N=(DimSize(w, 2)) temp
				SetScale/P x, DimOffset(w, 2), DimDelta(w, 2), temp
				Make/D/O/N=(DimSize(w, 0), DimSize(w, 1), DimSize(w, 3)) destFolder:$NameOfWave(w)
				Wave dest = destFolder:$NameOfWave(w)
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), WaveUnits(w, 0), dest
				SetScale/P y, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), dest
				SetScale/P z, DimOffset(w, 3), DimDelta(w, 3), WaveUnits(w, 3), dest
				for(j = 0; j < DimSize(dest, 0); j += 1)
					for(k = 0; k < DimSize(dest, 1); k += 1)
						for(m = 0; m < DimSize(dest, 2); m += 1)
							temp = w[j][k][p][m]
							if(stringmatch(method, "Sum"))
								dest[j][k][m] = sum(temp, lim1, lim2)
							elseif(stringmatch(method, "Average"))
								dest[j][k][m] = mean(temp, lim1, lim2)
							elseif(stringmatch(method, "Area"))
								dest[j][k][m] = area(temp, lim1, lim2)
							endif
						endfor
					endfor
				endfor
				KillWaves temp
			elseif(stringmatch(axis, "t"))
				Make/D/FREE/N=(DimSize(w, 3)) temp
				SetScale/P x, DimOffset(w, 3), DimDelta(w, 3), temp
				Make/D/O/N=(DimSize(w, 0), DimSize(w, 1), DimSize(w, 2)) destFolder:$NameOfWave(w)
				Wave dest = destFolder:$NameOfWave(w)
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), WaveUnits(w, 0), dest
				SetScale/P y, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), dest
				SetScale/P z, DimOffset(w, 2), DimDelta(w, 2), WaveUnits(w, 2), dest
				for(j = 0; j < DimSize(dest, 0); j += 1)
					for(k = 0; k < DimSize(dest, 1); k += 1)
						for(m = 0; m < DimSize(dest, 2); m += 1)
							temp = w[j][k][m][p]
							if(stringmatch(method, "Sum"))
								dest[j][k][m] = sum(temp, lim1, lim2)
							elseif(stringmatch(method, "Average"))
								dest[j][k][m] = mean(temp, lim1, lim2)
							elseif(stringmatch(method, "Area"))
								dest[j][k][m] = area(temp, lim1, lim2)
							endif
						endfor
					endfor
				endfor
				KillWaves temp
			else
				print "Sum/Avg/Area Along Axis: Skipping "+StringFromList(i, wList)+". Axis is incompatible with dimensions."
			endif
//			print "Sum/Avg/Area along axis: Skipping "+StringFromList(i, wList)+". 4D waves are not yet supported."
		endif

		// If output is wave format (i.e., not a variable), then append info to note
		if(WaveDims(w) >= 2)
			Wave dest = destFolder:$NameOfWave(w)
			if(WaveExists(dest))
				Note dest, note(w)
				Note dest, "[Sum Along Axis]"
				Note dest, "axis="+axis
				Note dest, "method="+method
				Note dest, "lim1="+num2str(lim1)
				Note dest, "lim2="+num2str(lim2)
			endif
		endif
	endfor
End

Function ARPESMenu_Crop()
	String wList = GetBrowserSelectionList(1)
	if(ItemsInList(wList) == 0)
		abort
	endif

	DFREF initialFolder = GetDataFolderDFR()

	Variable x1=-inf, x2=inf
	Variable y1=-inf, y2=inf
	Variable z1=-inf, z2=inf
	Variable t1=-inf, t2=inf

	Prompt x1, "Low x"
	Prompt x2, "High x"
	Prompt y1, "Low y"
	Prompt y2, "High y"
	Prompt z1, "Low z"
	Prompt z2, "High z"
	Prompt t1, "Low t"
	Prompt t2, "High t"
	DoPrompt "Choose cropping window: "+wList, x1, x2, y1, y2, z1, z2, t1, t2
	if(V_flag)
		abort
	endif

	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		NewDataFolder/O GetWavesDataFolderDFR(w):Crop
		DFREF destFolder = GetWavesDataFolderDFR(w):Crop
		if(WaveDims(w)==1)
			Duplicate/O/R=(x1,x2) w, destFolder:$NameOfWave(w)
		elseif(WaveDims(w) == 2)
			Duplicate/O/R=(x1,x2)(y1,y2) w, destFolder:$NameOfWave(w)
		elseif(WaveDims(w) == 3)
			Duplicate/O/R=(x1,x2)(y1,y2)(z1,z2) w, destFolder:$NameOfWave(w)
		elseif(WaveDims(w) == 4)
			Duplicate/O/R=(x1,x2)(y1,y2)(z1,z2)(t1,t2) w, destFolder:$NameOfWave(w)
		endif
		Wave dest = destFolder:$NameOfWave(w)
		Note dest, "[Crop]"
		Note dest, "x1="+num2str(x1)
		Note dest, "x2="+num2str(x2)
		Note dest, "y1="+num2str(y1)
		Note dest, "y2="+num2str(y2)
		Note dest, "z1="+num2str(z1)
		Note dest, "z2="+num2str(z2)
		Note dest, "t1="+num2str(t1)
		Note dest, "t2="+num2str(t2)
	endfor
End

//Function ARPESMenu_OpenInARPESViewer()
//	String wList = GetBrowserSelectionList(1)
//	if(ItemsInList(wList) == 0)
//		abort
//	endif
//
//	Variable i
//	for(i = 0; i < ItemsInList(wList); i += 1)
//		OpenARPESviewer(StringFromList(i, wList))
//	endfor
//End

Function ARPESMenu_AutoNorm2D()
	String wList = GetBrowserSelectionList(1)
	if(ItemsInList(wList) == 0)
		abort
	endif

	Variable deg = 2
	Prompt deg, "Polynomial degree"
	DoPrompt "Auto normalize 2D: "+wList, deg
	if(V_flag)
		abort
	endif

	DFREF initialFolder = GetDataFolderDFR()
	String tempFolderStr
	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		if(WaveDims(w) == 2)
			NewDataFolder/O GetWavesDataFolderDFR(w):AutoNorm2D
			DFREF procFolder = GetWavesDataFolderDFR(w):AutoNorm2D
	//		DFREF dest = destFolder:$NameOfWave(w)
	//		SetDataFolder NewFreeDataFolder()
//			tempFolderStr = UniqueName("temp", 11, 0)
			NewDataFolder/O/S procFolder:$NameOfWave(w)	//$tempFolderStr
			AutoNormalize2D(w, deg)
			Wave nrm = M_AutoNorm
			Wave fit = $"fit_"+NameOfWave(w)
			KillWaves/Z M_fit
			Rename fit, M_fit
//			Duplicate/O fit, destFolder:M_fit
//			Duplicate/O nrm, destFolder:$NameOfWave(w)
//			Wave dest = destFolder:$NameOfWave(w)
			Note nrm, "[Auto Normalize 2D]"
			Note nrm, "Polynomial degree = "+num2str(deg)
//			SetDataFolder ::
//			KillDataFolder $tempFolderStr
		else
			print "Auto Normalize 2D: Skipping "+StringFromList(i, wList)+". Input wave must be 2D (kx vs. ky)."
		endif
	endfor

	SetDataFolder initialFolder
End

Function ARPESMenu_AutoNorm3D()
	String wList = GetBrowserSelectionList(1)
	if(ItemsInList(wList) == 0)
		abort
	endif

	Variable deg = 2
	String methodList = "Average over range;At Specific Energy;Energy by energy;"
	String method = StringFromList(0, methodList)
	Variable lim1 = -inf, lim2 = inf
	Prompt deg, "Polynomial degree"
	Prompt method, "Method", popup, methodList
	Prompt lim1, "Start energy (for avg. method only)"
	Prompt lim2, "Stop energy (for avg. method only)"
	DoPrompt "Auto normalize 3D: "+wList, deg, method, lim1, lim2
	if(V_flag)
		abort
	endif

	String tempFolderStr
	Variable i, j
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		if(WaveDims(w) == 3)
			NewDataFolder/O GetWavesDataFolderDFR(w):AutoNorm3D
			DFREF destFolder = GetWavesDataFolderDFR(w):AutoNorm3D
			tempFolderStr = UniqueName("temp", 11, 0)
			NewDataFolder/S $tempFolderStr
			Make/D/N=(DimSize(w, 1), DimSize(w, 2)) temp
			SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), temp
			SetScale/P y, DimOffset(w, 2), DimDelta(w, 2), temp
			if(stringmatch(method, StringFromList(0, methodList)))

			elseif(stringmatch(method, StringFromList(1, methodList)))

			elseif(stringmatch(method, StringFromList(2, methodList)))
				for(j = 0; j < DimSize(w, 0); j += 1)
					temp = w[i][p][q]
					AutoNormalize2D(temp, deg)
					Wave nrm = M_AutoNorm
					Wave fit = $"fit_"+NameOfWave(w)
					if(j == 0)
						Duplicate/O w, destFolder:$NameOfWave(w), destFolder:$NameOfWave(fit)
					endif
					Wave dest = destFolder:$NameOfWave(w)
					Wave fitDest = destFolder:$NameOfWave(fit)
					dest[j][][] = nrm(y)(z)
					fitDest[j][][] = fit(y)(z)
				endfor
			endif
			Note dest, "[Auto Normalize 3D]"
			Note dest, "Polynomial degree = "+num2str(deg)
			Note dest, "Method = "+method
			Note dest, "lim1 = "+num2str(lim1)
			Note dest, "lim2 = "+num2str(lim2)
			KillDataFolder $tempFolderStr
		else
			print "Auto Normalize 3D: Skipping "+StringFromList(i, wList)+". Input wave must be 3D (E vs. kx vs ky)."
		endif
	endfor
End

Function ARPESMenu_Downsample()
	String wList = GetBrowserSelectionList(1)
	if(ItemsInList(wList) == 0)
		abort
	endif

	Variable dsx=1, dsy=1, dsz=1
	String popList = "Normal (interpolate values);Image (sum pixels);"
	String method = StringFromList(1, popList)
	Prompt dsx, "x downsampling factor (1 = no downsampling)"
	Prompt dsy, "y downsampling factor (1 = no downsampling)"
	Prompt dsz, "z downsampling factor (1 = no downsampling)"
	Prompt method, "Method", popup, popList
	DoPrompt "Downsample: "+wList, dsx, dsy, dsz, method
	if(V_flag)
		abort
	endif

	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		WAVE w = $StringFromList(i, wList)
		NewDataFolder/O GetWavesDataFolderDFR(w):Downsample
		DFREF destFolder = GetWavesDataFolderDFR(w):Downsample
		Duplicate/O Downsample(w, {dsx, dsy, dsz, 1}, WhichListItem(method, popList)), destFolder:$NameOfWave(w)
		Note w, "[Downsample]"
		Note w, "x downsampling factor="+num2str(dsx)
		Note w, "y downsampling factor="+num2str(dsy)
		Note w, "z downsampling factor="+num2str(dsz)
		Note w, "Method=\""+method+"\""
	endfor
End

Function ARPESMenu_Concatenate()
	String wList = GetBrowserSelectionList(1)
	if(ItemsInList(wList) < 2)
		abort
	endif

	// give user the option to rearrange the order of the waves to concatenate
	wList = MultiItemReorder(wList, title="Drag to Reorder")
	if(strlen(wList) == 0)
		abort	// user cancelled
	endif

	String promote
	String yn = "Yes;No;"
	Prompt promote, "Promote to higher dimension?", popup, yn
	DoPrompt "Concatenate: "+wList, promote
	if(V_flag)
		abort
	endif

	Variable i, pro = StringMatch(promote, "Yes")
//	promote = SelectString(pro, "/NP", "")
	if(pro)
		Concatenate/O wList, M_concatenated
	else
		Concatenate/O/NP wList, M_concatenated
	endif
//	DFREF initialFolder = GetDataFolderDFR()
//	SetDataFolder GetWavesDataFolderDFR($StringFromList(0, wList))
//	KillWaves/Z M_concatenated
//	Execute/Q "Concatenate/O"+promote+" \""+StringFromList(0, wList)+";"+StringFromList(1, wList)+";\", M_concatenated"
//	for(i = 2; i < ItemsInList(wList); i += 1)
//		Execute/Q "Concatenate"+promote+" \""+StringFromList(i, wList)+";\", M_concatenated"
//	endfor

	Note M_concatenated, "[Concatenate]"
	Note M_concatenated, "waves="+wList
	Note M_concatenated, "promote dimension="+num2str(pro)
//	SetDataFolder initialFolder
End

Function ARPESMenu_GapFromEDC()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable k1 = -inf, k2 = inf, e1 = -inf, e2 = 0, smth = 0, sym
	String symStr
	Prompt k1, "Search start k (or angle) value"
	Prompt k2, "Search end k (or angle) value"
	Prompt e1, "Search start energy"
	Prompt e2, "Search end energy"
	Prompt smth, "Smoothing factor (>1 for smoothing)"
	Prompt symStr, "Symmetrize EDCs?", popup, "Yes;No;"
	DoPrompt "Gap from EDCs: "+wList, k1, k2, e1, e2, smth, symStr
	if(V_flag)
		abort
	endif
	sym = !cmpstr(symStr, "Yes")	// cmpstr returns 0 when strings match

	Variable i, j, k
//	Variable p1, p2 // points corresponding to k1 and k2

	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		NewDataFolder/O GetWavesDataFolderDFR(w):EDC_Gap
		DFREF destFolder = GetWavesDataFolderDFR(w):EDC_Gap

		if(WaveDims(w) == 1)
			if(smth > 1)
				Duplicate/FREE w, temp1
				Smooth smth, temp1
			endif
			WaveStats/Q/R=(e1, e2) temp1
			Variable/G destFolder:$NameOfWave(w) = V_maxLoc
		elseif(WaveDims(w) == 2)
			Duplicate/FREE/R=(e1, e2)(k1, k2) w, crop2
			Make/FREE/D/N=(DimSize(crop2, 1)) temp2
			SetScale/P x, DimOffset(crop2, 1), DimDelta(crop2, 1), temp2
			Make/FREE/D/N=(DimSize(crop2, 0)) edc
			SetScale/P x, DimOffset(crop2, 0), DimDelta(crop2, 0), edc
			for(j = 0; j < DimSize(crop2, 1); j += 1)
				if(sym)
					edc = crop2(x) + crop2(-x)
				else
					edc = crop2
				endif
				WaveStats/Q/R=(e1,e2) edc
				temp2[j] = V_maxLoc
			endfor
			if(smth > 1)
				Smooth smth, temp2
			endif
			WaveStats/Q temp2
			Variable/G destFolder:$NameOfWave(w) = V_maxLoc
		elseif(WaveDims(w) == 3)
			Duplicate/FREE/R=(,)(k1, k2)(,) w, crop2
			Make/FREE/D/N=(DimSize(crop2, 1)) temp2
			SetScale/P x, DimOffset(crop2, 1), DimDelta(crop2, 1), temp2
			Make/FREE/D/N=(DimSize(crop2, 0)) edc
			SetScale/P x, DimOffset(crop2, 0), DimDelta(crop2, 0), edc
			Make/D/O/N=(DimSize(crop2, 2)) destFolder:$NameOfWave(w)
			Wave result = destFolder:$NameOfWave(w)
			SetScale/P x, DimOffset(crop2, 2), DimDelta(crop2, 2), WaveUnits(crop2, 2), result
			for(k = 0; k < DimSize(crop2, 2); k += 1)
				for(j = 0; j < DimSize(crop2, 1); j += 1)
					if(sym)
						edc = crop2(x)[j][k]
						edc += crop2(-x)[j][k]
					else
						edc = crop2[p][j][k]
					endif
					WaveStats/Q/R=(e1,e2) edc
					temp2[j] = V_maxLoc
				endfor
				if(smth > 1)
					Smooth smth, temp2
				endif
				WaveStats/Q temp2
				result[k] = V_max
			endfor
		endif
	endfor
End


//Function ARPESMenu_ATS()
//	String wList = GetBrowserSelectionList(1)
//	if(strlen(wList) == 0)
//		abort
//	endif
//
//	DoWindow/K Win_ATS
//	Execute/Q "Win_ATS()"
//	DoWindow/T Win_ATS, "ARPES tunneling: "+wList
//	MakeListIntoWaveSelector("Win_ATS", "list_bgWave", content=WMWS_Waves, selectionMode=WMWS_SelectionSingle)
//	MakeListIntoWaveSelector("Win_ATS", "list_fermiWave", content=WMWS_Waves, selectionMode=WMWS_SelectionSingle)
////	PauseForUser Win_ATS
//End
//
//Window Win_ATS() : Panel
//	PauseUpdate; Silent 1		// building window...
//	NewPanel /W=(150,77,514,389) as "ARPES tunneling: root:'#13-1':'scan3 7eV k':M_3D;"
//	Button button_continue,pos={158,283},size={50,20},proc=BtnProc_ATS_Continue,title="Continue"
//	Button button_cancel,pos={6,282},size={50,20},proc=BtnProc_ATS_Cancel,title="Cancel"
//	Button button_help,pos={304,283},size={50,20},title="Help"
//	SetVariable setvar_fitStart,pos={17,193},size={146,16},bodyWidth=85,title="Start energy"
//	SetVariable setvar_fitStart,value= _NUM:-0.05
//	SetVariable setvar_fitEnd,pos={188,193},size={143,16},bodyWidth=85,title="End energy"
//	SetVariable setvar_fitEnd,value= _NUM:0.01
//	ListBox list_bgWave,pos={7,21},size={166,140}
//	ListBox list_fermiWave,pos={187,21},size={166,140}
//	TitleBox title0,pos={6,6},size={87,13},title="Background wave",frame=0
//	TitleBox title1,pos={186,6},size={54,13},title="Fermi wave",frame=0
//	GroupBox group0,pos={6,172},size={348,49},title="Fit range"
//	SetVariable setvar_sumStart,pos={43,245},size={120,16},bodyWidth=85,title="Start k"
//	SetVariable setvar_sumStart,value= _NUM:-inf
//	SetVariable setvar_sumEnd,pos={214,245},size={117,16},bodyWidth=85,title="End k"
//	SetVariable setvar_sumEnd,value= _NUM:inf
//	GroupBox group1,pos={6,224},size={348,49},title="Sum range"
//	SetWindow kwTopWin,hook(WaveSelectorWidgetHook)=WMWS_WinHook
//EndMacro
//
//Function BtnProc_ATS_Continue(ba) : ButtonControl
//	STRUCT WMButtonAction &ba
//
//	switch( ba.eventCode )
//		case 2: // mouse up
//			// click code here
//			DFREF initialFolder = GetDataFolderDFR()
//			String wList = GetBrowserSelectionList(1)
//			WAVE bg = $StringFromList(0, WS_SelectedObjectsList("Win_ATS", "list_bgWave"))
//			WAVE frmi = $StringFromList(0, WS_SelectedObjectsList("Win_ATS", "list_fermiWave"))
//			if(WaveDims(bg) != 1 || WaveDims(bg) != 2)
//				DoAlert 0, "Background wave must be either 1D or 2D."
//				abort
//			endif
//			if(WaveDims(frmi) != 1)
//				DoAlert 0, "Fermi wave must be 1D."
//				abort
//			endif
//			ControlInfo setvar_fitStart
//			Variable e1 = V_Value
//			ControlInfo setvar_fitEnd
//			Variable e2 = V_Value
//			ControlInfo setvar_sumStart
//			Variable k1 = V_Value
//			ControlInfo setvar_sumEnd
//			Variable k2 = V_Value
//			Variable i, j
//			for(i = 0; i < strlen(wList); i += 1)
//				WAVE w = $StringFromList(i, wList)
//				NewDataFolder/O GetWavesDataFolderDFR(w):ATS
//				DFREF routineFolder = GetWavesDataFolderDFR(w):ATS
//				NewDataFolder/O routineFolder:$NameOfWave(w)
//				DFREF waveFolder = routineFolder:$NameOfWave(w)
//				if(WaveDims(w) == 2)
//					DFREF destFolder = waveFolder
//					SetDataFolder destFolder
////					ATSanalysis(w, bg, frmi, {e1, e2}, {k1, k2}, scaleMode=0, EFmode=0)
//				elseif(WaveDims(w) == 3)
//					for(j = 0; j < DimSize(w, 2); j += 1)
//						NewDataFolder/O waveFolder:$("z="+num2str(DimOffset(w, 2)+DimDelta(w, 2)*j))
//						DFREF destFolder = waveFolder:$("z="+num2str(DimOffset(w, 2)+DimDelta(w, 2)*j))
//						SetDataFolder destFolder
//						ImageTransform/PTYP=0/P=(j) getPlane, w
//						WAVE M_ImagePlane
////						ATSanalysis(M_ImagePlane, bg, frmi, {e1, e2}, {k1, k2}, scaleMode=0, EFmode=0)
//					endfor
//				endif
//			endfor
//			WS_FindAndKillWaveSelector("Win_ATS", "list_bgWave")
//			WS_FindAndKillWaveSelector("Win_ATS", "list_fermiWave")
//			DoWindow/K Win_ATS
//			SetDataFolder initialFolder
//			break
//	endswitch
//
//	return 0
//End
//
//Function BtnProc_ATS_Cancel(ba) : ButtonControl
//	STRUCT WMButtonAction &ba
//
//	switch( ba.eventCode )
//		case 2: // mouse up
//			// click code here
//			WS_FindAndKillWaveSelector("Win_ATS", "list_bgWave")
//			WS_FindAndKillWaveSelector("Win_ATS", "list_fermiWave")
//			DoWindow/K Win_ATS
//			break
//	endswitch
//
//	return 0
//End

Function ARPESMenu_Smooth()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	String dimList = "x;y;z;t;"
	String dim = StringFromList(0, dimList)
	String methodList = "Binomial (Gaussian);Boxcar (sliding average);2nd-order Savitzky-Golay (polynomial);4th-order Savitzky-Golay (polynomial); FFT Hann (x axis only)"
	String method = StringFromList(0, methodList)
	Variable num = 1
	Prompt dim, "Axis", popup, dimList
	Prompt num, "Smoothing factor"
	Prompt method, "Method", popup, methodList
	DoPrompt "Smooth: "+wList, dim, num, method
	if(V_flag)
		abort
	endif

	Variable i, j, k, methodIndex = WhichListItem(method, methodList), dimNum = WhichListItem(dim, dimList)
	Variable oddLen, x0, dx	// used for FFT-based routine
	for(i = 0; i < ItemsInList(wList); i += 1)
		WAVE w = $StringFromList(i, wList)
		NewDataFolder/O GetWavesDataFolderDFR(w):'Smooth'
		DFREF destFolder = GetWavesDataFolderDFR(w):'Smooth'
		Duplicate/O w, destFolder:$NameOfWave(w)
		WAVE destW = destFolder:$NameOfWave(w)
		switch(methodIndex)
			case 0:	// binomial
				Smooth/DIM=(dimNum) num, destW
				break
			case 1:	// boxcar
				Smooth/DIM=(dimNum)/B num, destW
				break
			case 2:	// 2nd-order SG
				Smooth/DIM=(dimNum)/S=2 num, destW
				break
			case 3:	// 4th-order SG
				Smooth/DIM=(dimNum)/S=4 num, destW
				break
			case 4:
				if(WaveDims(w) == 1)
					if(mod(numpnts(destW), 2))
						oddLen = 1
						InsertPoints numpnts(destW), 1, destW
						destW[numpnts(destW)-1] = destW[numpnts(destW)-2]
					else
						oddLen = 0
					endif
					FFT destW
					Rotate numpnts(destW)/2, destW
					for(k = 0; k < num; k += 1)
						WindowFunction Hanning, destW
					endfor
					Rotate -numpnts(destW)/2, destW
					IFFT destW
					if(oddLen)
						DeletePoints numpnts(destW)-1, 1, destW
					endif
					CopyScales/P w, destW
				elseif(WaveDims(w) == 2)
					Make/D/N=(DimSize(w, dimNum)) temp
					if(mod(numpnts(temp), 2))
						oddLen = 1
						InsertPoints numpnts(temp), 1, temp
						temp[numpnts(temp)-1] = temp[numpnts(temp)-2]
					endif
					for(j = 0; j < DimSize(w, !dimNum); j += 1)
						temp = w[p][j]
						FFT temp
						Rotate numpnts(temp)/2, temp
						for(k = 0; k < num; k += 1)		// number of applications of Hann window
							WindowFunction Hanning, temp
						endfor
						Rotate -numpnts(temp)/2, temp
						IFFT temp
						if(oddLen)
							DeletePoints numpnts(temp)-1, 1, temp
						endif
						destW[][j] = temp[p]
					endfor
					KillWaves temp
				endif
				break
		endswitch
		Note destW, "[Smooth]"
		Note destW, "dim="+dim
		Note destW, "smoothing factor="+num2str(num)
		Note destW, "method="+method
	endfor
End

Function ARPESMenu_Normalize()
	String wList = GetBrowserSelectionList(1)
	if(ItemsInList(wList) == 0)
		abort
	endif

	DFREF initialFolder = GetDataFolderDFR()
	DFREF tempFolder = NewFreeDataFolder()
	SetDataFolder tempFolder

	String dimList = "x;y;z;", methodList = "Sum;Max Height;"
	String dimStr = StringFromList(0, dimList)
	String methodStr = StringFromList(0, methodList)
	Prompt dimStr, "Normalize slices along:", popup, dimList
	Prompt methodStr, "Normalize to:", popup, methodList
	DoPrompt "Normalize: "+wList, dimStr, methodStr
	if(V_flag)
		abort
	endif

	Variable i, j, k, dim = WhichListItem(dimStr, dimList), useHeight = WhichListItem(methodStr, methodList), a
	for(i = 0; i < ItemsInList(wList); i += 1)
		WAVE w = $StringFromList(i, wList)
		NewDataFolder/O GetWavesDataFolderDFR(w):Normalize
		DFREF destFolder = GetWavesDataFolderDFR(w):Normalize
		Duplicate/O w, destFolder:$NameOfWave(w)
		WAVE dest = destFolder:$NameOfWave(w)
		dest = numtype(dest) == 0 ? dest : 0
		if(WaveDims(w) == 1)
			if(useHeight)
				a = wavemax(dest)
			else
				a = sum(dest)
			endif
			dest /= a
		elseif(WaveDims(w) == 2)
			if(dim == 0)
				if(useHeight)
					for(j = 0; j < DimSize(w, 1); j += 1)
						ImageTransform/G=(j) getCol, dest
						WAVE W_ExtractedCol
						a = wavemax(W_ExtractedCol)
						dest[][j] /= a
					endfor
				else
					ImageTransform sumAllCols, dest
					WAVE W_sumCols
					dest /= W_sumCols[q]
				endif
			elseif(dim == 1)
				if(useHeight)
					for(j = 0; j < DimSize(w, 0); j += 1)
						ImageTransform/G=(j) getRow, dest
						WAVE W_ExtractedRow
						a = wavemax(W_ExtractedRow)
						dest[j][] /= a
					endfor
				else
					ImageTransform sumAllRows, dest
					WAVE W_sumRows
					dest /= W_sumRows[p]
				endif
			endif
		elseif(WaveDims(w) == 3)
			if(dim == 0)
				for(j = 0; j < DimSize(dest, 0); j += 1)
					for(k = 0; k < DimSize(dest, 2); k += 1)
						ImageTransform/G=(j)/P=(k) getRow, dest
						WAVE W_ExtractedRow
						if(useHeight == 0)
							a = sum(W_ExtractedRow)
						elseif(useHeight == 1)
							a = wavemax(W_ExtractedRow)
						endif
						dest[][j][k] /= a
					endfor
				endfor
			elseif(dim == 1)
				for(j = 0; j < DimSize(dest, 1); j += 1)
					for(k = 0; k < DimSize(dest, 2); k += 1)
						ImageTransform/G=(j)/P=(k) getCol, dest
						WAVE W_ExtractedCol
						if(useHeight == 0)
							a = sum(W_ExtractedCol)
						elseif(useHeight == 1)
							a = wavemax(W_ExtractedCol)
						endif
						dest[j][][k] /= a
					endfor
				endfor
			elseif(dim == 2)
				for(j = 0; j < DimSize(dest, 0); j += 1)
					for(k = 0; k < DimSize(dest, 1); k += 1)
						ImageTransform/Beam={(j),(k)} getBeam, dest
						WAVE W_beam
						if(useHeight == 0)
							a = sum(W_beam)
						elseif(useHeight == 1)
							a = wavemax(W_beam)
						endif
						dest[j][k][] /= a
					endfor
				endfor
			endif
		endif

		Note dest, "[Normalize]"
		Note dest, "axis="+dimStr
		Note dest, "method="+methodStr
	endfor

	SetDataFolder initialFolder
End

//Function ARPESMenu_NormalizeSlices2D()
//	String wList = GetBrowserSelectionList(1)
//	if(strlen(wList) == 0)
//		abort
//	endif
//
//	DFREF initialFolder = GetDataFolderDFR()
//	DFREF tempFolder = NewFreeDataFolder()
//	SetDataFolder tempFolder
//
//	String dimList = "x;y;"
//	String dimStr = StringFromList(0, dimList)
//	Prompt dimStr, "Normalize the slices along:", popup, dimList
//	DoPrompt "Normalize image slices: "+wList, dimStr
//	if(V_flag)
//		abort
//	endif
//
//	Variable i, j, dim = WhichListItem(dimStr, dimList)
//	for(i = 0; i < ItemsInList(wList); i += 1)
//		WAVE w = $StringFromList(i, wList)
//		if(WaveDims(w) == 2)
//			NewDataFolder/O GetWavesDataFolderDFR(w):NormImageSlices
//			DFREF destFolder = GetWavesDataFolderDFR(w):NormImageSlices
//			Duplicate/O w, destFolder:$NameOfWave(w)
//			WAVE dest = destFolder:$NameOfWave(w)
//			dest = numtype(dest) == 0 ? dest : 0
//			if(dim == 0)
//				ImageTransform sumAllCols, dest
//				WAVE W_sumCols
//				dest /= W_sumCols[q]
//			elseif(dim == 1)
//				ImageTransform sumAllRows, dest
//				WAVE W_sumRows
//				dest /= W_sumRows[p]
//			endif
//		else
//			// skip
//			print NameOfWave(w) + " is not 2D. Skipping."
//		endif
//	endfor
//
//	SetDataFolder initialFolder
//End


Function ARPESMenu_symEDC()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable k1 = -inf, k2 = inf, eRange = 0.045, res = 0.01
	String stateList = "Supconducting state;Pseudogap state;"
	String noYes = "No;Yes;"
	String includeRes = StringFromList(0, noyes)
	String state = StringFromList(0, stateList)
	Prompt k1, "kF search range start"
	Prompt k2, "kF search range end"
	Prompt eRange, "Symmetrized EDC fitting +/- energy range"
	Prompt state, "Model state", popup, stateList
	Prompt includeRes, "Include resolution?", popup, noYes
	Prompt res, "Energy resolution"
	DoPrompt "Analyze symmetrized EDCs: "+wList, k1, k2, eRange, state, includeRes, res
	if(V_flag)
		abort
	endif

	DFREF initialFolder = GetDataFolderDFR()

	Variable i, j, inclG0 = WhichListItem(state, stateList), inclRes = WhichListItem(includeRes, noYes)
	for(i = 0; i < ItemsInList(wList); i += 1)
		WAVE w = $StringFromList(i, wList)
		NewDataFolder/O/S GetWavesDataFolderDFR(w):symEDC
		NewDataFolder/O/S $NameOfWave(w)
		if(WaveDims(w) == 2)
			if(inclRes)
				SymKfEdcAnalysis(w, eRange, includeG0=inclG0, k1=k1, k2=k2, eRes=res)
			else
				SymKfEdcAnalysis(w, eRange, includeG0=inclG0, k1=k1, k2=k2)
			endif
		elseif(WaveDims(w) == 3)
			Make/D/O/N=(DimSize(w, 2)) W_delta, W_gamma0, W_gamma1, W_kF
			SetScale/P x, DimOffset(w, 2), DimDelta(w, 2), WaveUnits(w, 2), W_delta, W_gamma0, W_gamma1, W_kF
			for(j = 0; j < DimSize(w, 2); j += 1)
				NewDataFolder/O/S $("z="+num2str(DimOffset(w, 2)+DimDelta(w, 2)*j))
				ImageTransform/PTYP=0/P=(j) getPlane, w
				WAVE M_ImagePlane
				if(inclRes)
					SymKfEdcAnalysis(M_ImagePlane, eRange, includeG0=inclG0, k1=k1, k2=k2, eRes=res)
				else
					SymKfEdcAnalysis(M_ImagePlane, eRange, includeG0=inclG0, k1=k1, k2=k2)
				endif
				NVAR V_delta, V_gamma0, V_gamma1, V_kF
				W_delta[j] = V_delta
				W_gamma0[j] = V_gamma0
				W_gamma1[j] = V_gamma1
				W_kF[j] = V_kF
				SetDataFolder ::
			endfor
		endif
	endfor

	SetDataFolder initialFolder
End

Function ARPESMenu_EDCcom()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable i, j, k, a
	for(i = 0; i < ItemsInList(wList); i += 1)
		WAVE w = $StringFromList(i, wList)
		NewDataFolder/O GetWavesDataFolderDFR(w):EDC_CenterOfMass
		DFREF destFolder = GetWavesDataFolderDFR(w):EDC_CenterOfMass
		if(WaveDims(w) == 1)
			Variable/G destFolder:$NameOfWave(w)
			NVAR com = destFolder:$NameOfWave(w)
			com = CenterOfMass(w)
		elseif(WaveDims(w) == 2)
			Make/O/N=(DimSize(w, 1)) destFolder:$NameOfWave(w)
			WAVE comW = destFolder:$NameOfWave(w)
			SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), comW
			SetScale/P d, 0, 1, WaveUnits(w, 0), comW
			for(j = 0; j < DimSize(w, 1); j += 1)
				ImageTransform/G=(j) getCol, w
				WAVE W_ExtractedCol
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), WaveUnits(w, 0), W_ExtractedCol
				comW[j] = CenterOfMass(W_ExtractedCol)
			endfor
			Note comW, note(w)
		elseif(WaveDims(w) == 3)
			Make/O/N=(DimSize(w, 1), DimSize(w, 2)) destFolder:$NameOfWave(w)
			WAVE comW = destFolder:$NameOfWave(w)
			SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), comW
			SetScale/P y, DimOffset(w, 2), DimDelta(w, 2), WaveUnits(w, 2), comW
			SetScale/P d, 0, 1, WaveUnits(w, 0), comW
			for(k = 0; k < DimSize(w, 2); k += 1)
				ImageTransform/PTYP=0/P=(k) getPlane, w	// get an x-y plane
				WAVE M_ImagePlane
				for(j = 0; j < DimSize(w, 1); j += 1)
					ImageTransform/G=(j) getCol, M_ImagePlane
					WAVE W_ExtractedCol
					SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), WaveUnits(w, 0), W_ExtractedCol
					comW[j][k] = CenterOfMass(W_ExtractedCol)
				endfor
			endfor
			Note comW, note(w)
		endif
		KillWaves comCalc
	endfor
End

Function ARPESMenu_1DDifferentiate()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

//	Variable ds = 1		// downsampling factor
	String axis = "x"		// axis to differentiate
	Variable order = 1		// derivative order
//	String dsMethodList = "Intepolate;Sum counts;"
//	String dsMethod = StringFromList(1, dsMethodList)
//	Prompt ds, "Downsampling factor"
	Prompt axis, "Axis", popup, "x;y;z;t;"
	Prompt order, "Derivative order"
//	Prompt dsMethod, "Downsampling method", popup, dsMethodList
	DoPrompt "1D Differentiation: "+wList, axis, order //, ds, dsMethod
	if(V_flag)
		abort
	endif

//	Make/D/FREE/N=1 dsf	// downsampling factors
	Variable dim = WhichListItem(axis, "x;y;z;t;")
	Variable i, j
	for(i = 0; i < ItemsInList(wList); i += 1)
		WAVE w = $StringFromList(i, wList)
		NewDataFolder/O GetWavesDataFolderDFR(w):Differentiate1D
		DFREF destFolder = GetWavesDataFolderDFR(w):Differentiate1D
//		Redimension/N=(WaveDims(w)) dsf
//		dsf = 1
//		dsf[dim] = ds
//		WAVE dsw = Downsample(w, dsf, WhichListItem(dsMethod, dsMethodList))
//		Duplicate/O dsw, destFolder:$NameOfWave(w)
		Duplicate/O w, destFolder:$NameOfWave(w)
		WAVE result = destFolder:$NameOfWave(w)
		for(j = 0; j < order; j += 1)
			Differentiate/DIM=(dim) result
		endfor
		Note/K result
		Note result, note(w)
		Note result, "[1D Differentiate]"
		Note result, "axis="+axis
		Note result, "order="+num2str(order)
//		Note result, "downsample factor="+num2str(ds)
	endfor
End

Function ARPESMenu_3DLaplacian()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

//	Variable dsx = 1, dsy = 1, dsz = 1 	// downsampling factors
//	Prompt dsx, "x downsampling factor"
//	Prompt dsy, "y downsampling factor"
//	Prompt dsz, "z downsampling factor"
//	DoPrompt "3D Laplacian: "+wList, dsx, dsy, dsz
//	if(V_flag)
//		abort
//	endif

	DFREF tempFolder = NewFreeDataFolder()
	SetDataFolder tempFolder

	Variable i
	for(i = 0; i < strlen(wList); i += 1)
		WAVE w = $StringFromList(i, wList)
		if(WaveDims(w) == 3)
			NewDataFolder/O GetWavesDataFolderDFR(w):Laplacian3D
			DFREF destFolder = GetWavesDataFolderDFR(w):Laplacian3D
//			WAVE ds = Downsample(w, {dsx, dsy, dsz}, 1)
//			WAVE lap = Laplacian(ds)
			WAVE lap = Laplacian(w)
			Duplicate/O lap, destFolder:$NameOfWave(w)
			WAVE result = destFolder:$NameOfWave(w)
			Note/K result
			Note result, note(w)
//			Note result, "[3D Laplacian]"
//			Note result, "x downsample factor="+num2str(dsx)
//			Note result, "y downsample factor="+num2str(dsy)
//			Note result, "z downsample factor="+num2str(dsz)
		else
			print "3D Laplacian: Skipping "+StringFromList(i, wList)+". Input wave must be 3D."
		endif
	endfor

	SetDataFolder initialFolder
End

Function ARPESMenu_2DLaplacian()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable dsx = 1, dsy = 1, dsz = 1	// downsampling factors
	String plane = "x-y"
//	Prompt dsx, "x downsampling factor"
//	Prompt dsy, "y downsampling factor"
//	Prompt dsz, "z downsampling factor (3D wave only)"
	Prompt plane, "Choose plane (for 2D Laplacian of 3D wave only)", popup, "x-y;x-z;y-z;"
	DoPrompt "2D Laplacian: "+wList, plane //, dsx, dsy, dsz
	if(V_flag)
		abort	// cancelled
	endif

	String tempFolderStr = UniqueName("temp", 11, 0)
	Variable i, j, axis, ptype
	for(i = 0; i < ItemsInList(wList); i += 1)
		WAVE w = $StringFromList(i, wList)
		NewDataFolder/O GetWavesDataFolderDFR(w):Laplacian2D
		DFREF destFolder = GetWavesDataFolderDFR(w):Laplacian2D

		if(WaveDims(w) == 2)
//			WAVE ds = Downsample(w, {dsx, dsy}, 1)
//			WAVE lap = Laplacian(ds)
			WAVE lap = Laplacian(w)
			Duplicate/O lap, destFolder:$NameOfWave(w)
		elseif(WaveDims(w) == 3)
			strswitch(plane)
				case "x-y":
					axis = 2
					ptype = 0
					break
				case "x-z":
					axis = 1
					ptype = 1
					break
				case "y-z":
					axis = 0
					ptype = 2
					break
			endswitch

//			WAVE ds = Downsample(w, {dsx, dsy, dsz}, 1)
//			Duplicate/O ds, destFolder:$NameOfWave(w)
			Duplicate/O w, destFolder:$NameOfWave(w)
			WAVE destWave = destFolder:$NameOfWave(w)
			DFREF tempFolder = NewFreeDataFolder()
			SetDataFolder tempFolder
			for(j = 0; j < DimSize(ds, axis); j += 1)
//				ImageTransform/PTYP=(ptype)/P=(j) getPlane, ds
				ImageTransform/PTYP=(ptype)/P=(j) getPlane, w
				WAVE M_ImagePlane
				WAVE lap = Laplacian(M_ImagePlane)
				switch(axis)
					case 0:
						destWave[j][][] = lap[q][r]
						break
					case 1:
						destWave[][j][] = lap[p][r]
						break
					case 2:
						destWave[][][j] = lap[p][q]
						break
				endswitch
			endfor
			SetDataFolder initialFolder
			KillDataFolder tempFolder
		else
			print "2D Laplacian: Skipping "+StringFromList(i, wList)+". Input wave must be either 2D or 3D. 4D not yet supported."
		endif

		WAVE destWave = destFolder:$NameOfWave(w)
		Note destWave, note(w)
		Note destWave, "[2D Laplacian]"
//		Note destWave, "x downsample factor="+num2str(dsx)
//		Note destWave, "y downsample factor="+num2str(dsy)
//		Note destWave, "z downsample factor="+num2str(dsz)
		Note destWave, "plane="+plane
	endfor

	SetDataFolder initialFolder
End

Function ARPESMenu_FitSurface()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable x1=-inf, x2=inf, y1=-inf, y2=inf, startPos=0
	String func = "Lorentzian", fitAxis = "x"
	Prompt x1, "Fit range start x"
	Prompt x2, "Fit range end x"
	Prompt y1, "Fit range start y"
	Prompt y2, "Fit range end y"
	Prompt startPos, "Starting fitting from"
	Prompt func, "Fit function", popup, "Lorentzian;Gaussian;"
	Prompt fitAxis, "Fit along:", popup, "x;y;"
	DoPrompt "Track Surface: "+wList, func, fitAxis, x1, x2, y1, y2, startPos
	if(V_flag)
		abort	// cancelled
	endif

	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		WAVE w = $StringFromList(i, wList)
		if(WaveDims(w) == 2)
			SetDataFolder GetWavesDataFolderDFR(w)
			NewDataFolder/O/S FitSurface
			NewDataFolder/O/S $NameOfWave(w)
			EasyBatchFit(w, startPos, func, {x1,y1,x2,y2}, StringMatch(fitAxis, "y"))
		endif
	endfor

	SetDataFolder initialFolder
End

Function ARPESMenu_GetVelocity()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable e1, e2
	Prompt e1, "Linear fit start energy"
	Prompt e2, "Linear fit end energy"
	DoPrompt "Get Velocity: "+wList, e1, e2
	if(V_flag)
		abort	// cancelled
	endif

	Variable i, j, skip
	for(i = 0; i < ItemsInList(wList); i += 1)
		skip = 0
		WAVE w = $StringFromList(i, wList)
		if(WaveDims(w) == 1)
			SetDataFolder GetWavesDataFolderDFR(w)
			if(WaveExists($("sigma_"+NameOfWave(w))))
				WAVE sigmaW = $("sigma_"+NameOfWave(w))
				NewDataFolder/O/S Velocity
				CurveFit/N/Q line, w(e1,e2) /D/I=1/W=sigmaW
				WAVE W_coef, W_sigma
				Variable/G V_velocity = 1/W_coef[1]
				Variable/G V_sigma_velocity = abs(W_sigma[1]/(W_coef[1]^2))
			else
				print "Corresponding uncertainty wave sigma_"+NameOfWave(w)+" not found. Skipping."
			endif
		elseif(WaveDims(w) == 2 || WaveDims(w) == 3)
			DFREF fitFolder = $(GetWavesDataFolder(w, 1)+"MDC_Fitting:"+PossiblyQuoteName(NameOfWave(w)))
			if(!DataFolderRefStatus(fitFolder))
				DoAlert 1, "MDC fits were not found for "+NameOfWave(w)+" (:MDC_Fitting:"+NameOfWave(w)+"). Do MDC fitting now? (Otherwise this wave will be skipped.)"
				if(V_flag == 1)
					ARPESMenu_MDCSinglePeakBatchFit()
				else
					skip = 1
				endif
			endif
			if(!skip)
				SetDataFolder fitFolder
				if(WaveDims(w) == 2)
					if(WaveExists(peak0_Location) && WaveExists(sigma_peak0_Location))
						NewDataFolder/O/S Velocity
						CurveFit/N/Q line, peak0_Location(e1,e2) /D/I=1/W=sigma_peak0_Location
						WAVE W_coef, W_sigma
						Variable/G V_velocity = 1/W_coef[1]
						Variable/G V_sigma_velocity = abs(W_sigma[1]/(W_coef[1]^2))
					else
						print "Wave(s) "+GetDataFolder(1)+":peak0_Location and/or :sigma_peak0_Location not found. Skipping."
					endif
				endif
				if(WaveDims(w) == 3)
					Make/D/O/N=(DimSize(w, 2)) W_velocity = NaN
					SetScale/P x, DimOffset(w, 2), DimDelta(w, 2), WaveUnits(w, 2), W_velocity
					Duplicate/O W_velocity, W_sigma_velocity
					for(j = 0; j < DimSize(w, 2); j += 1)
						DFREF sliceFolder = fitFolder:$("z="+num2str(DimOffset(w, 2)+DimDelta(w, 2)*j))
						if(DataFolderRefStatus(sliceFolder))
							SetDataFolder sliceFolder
							if(WaveExists(peak0_FWHM) && WaveExists(sigma_peak0_FWHM))
								NewDataFolder/O/S Velocity
								CurveFit/N/Q line, ::peak0_Location(e1,e2) /D/I=1/W=::sigma_peak0_Location
								WAVE W_coef, W_sigma
								Variable/G V_velocity = 1/W_coef[1]
								Variable/G V_sigma_velocity = abs(W_sigma[1]/(V_velocity^2))
								W_velocity[j] = V_velocity
								W_sigma_velocity[j] = V_sigma_velocity
							else
								print "Wave(s) "+GetDataFolder(1)+":peak0_Location and/or :sigma_peak0_Location not found. Skipping."
							endif
						else
							print "Fit folder "+GetDataFolder(1)+"z="+num2str(DimOffset(w, 2)+DimDelta(w, 2)*j)+" not found. Skipping."
						endif
					endfor
				endif
				Note W_velocity, note(w)+"\r[Velocity]\r"+"energy1="+num2str(e1)+"\renergy2="+num2str(e2)
				Note W_sigma_velocity, note(W_velocity)
			endif
		endif
	endfor

	SetDataFolder initialFolder
End

Function ARPESMenu_EDCmaxima()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable k1 = -inf, k2 = inf, e1 = -inf, e2 = inf
	Prompt e1, "Search start energy"
	Prompt e2, "Search end energy"
//	Prompt k1, "Search start k (or angle)"
//	Prompt k2, "Search end k (or angle)"
	DoPrompt "Analyze EDC maxima: "+wList, e1, e2
	if(V_flag)
		abort
	endif

	Variable i, j, k, zval
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		SetDataFolder GetWavesDataFolderDFR(w)
		NewDataFolder/O/S EDC_max
		NewDataFolder/O/S $NameOfWave(w)
		if(WaveDims(w) == 2)
			Make/D/O/N=(DimSize(w, 1)) W_maxima, W_maxLocs
			WAVE maxima = W_maxima
			WAVE maxLocs = W_maxLocs
			SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), maxima, maxLocs
			for(j = 0; j < DimSize(w, 1); j += 1)
				ImageTransform/G=(j) getCol, w
				WAVE W_ExtractedCol
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), W_ExtractedCol
				WaveStats/Q/R=(e1,e2) W_ExtractedCol
				maxima[j] = V_max
				maxLocs[j] = V_maxLoc
			endfor
		elseif(WaveDims(w) == 3)
			for(j = 0; j < DimSize(w, 2); j += 1)
				zval = DimOffset(w, 2)+DimDelta(w, 2)*j
				NewDataFolder/O $("z="+num2str(zval))
				DFREF destFolder = $("z="+num2str(zval))
				Make/D/O/N=(DimSize(w, 1)) destFolder:W_maxima, destFolder:W_maxLocs
				Wave maxima = destFolder:W_maxima, maxLocs = destFolder:W_maxLocs
				SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), maxima, maxLocs
				for(k = 0; k < DimSize(w, 1); k 	+= 1)
					ImageTransform/G=(k)/P=(j)/PTYP=0 getCol, w
					Wave W_ExtractedCol
					SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), W_ExtractedCol
					WaveStats/Q/R=(e1,e2) W_ExtractedCol
					maxima[k] = V_max
					maxLocs[k] = V_maxLoc
				endfor
			endfor
		endif
		KillWaves W_ExtractedCol
	endfor

	SetDataFolder initialFolder
End

Function ARPESMenu_MDCmaxima()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable i, j, k, zval, k1 = -inf, k2 = inf
	Prompt k1, "Search start k"
	Prompt k2, "Search end k"
	DoPrompt "Analyze MDC maxima " + wList, k1, k2
	if(V_flag)
		abort
	endif

	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		SetDataFolder GetWavesDataFolderDFR(w)
		NewDataFolder/O/S MDC_max
		NewDataFolder/O/S $NameOfWave(w)
		if(WaveDims(w) == 2)
			Make/D/O/N=(DimSize(w, 0)) W_maxima, W_maxLocs
			WAVE maxima = W_maxima
			WAVE maxLocs = W_maxLocs
			SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), WaveUnits(w, 0), maxima, maxLocs
			for(j = 0; j < DimSize(w, 0); j += 1)
				ImageTransform/G=(j) getRow, w
				WAVE W_ExtractedRow
				SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), W_ExtractedRow
				WaveStats/Q/R=(k1,k2) W_ExtractedRow
				maxima[j] = V_max
				maxLocs[j] = V_maxLoc
			endfor
		elseif(WaveDims(w) == 3)
			for(j = 0; j < DimSize(w, 2); j += 1)
				zval = DimOffset(w, 2)+DimDelta(w, 2)*j
				NewDataFolder/O $("z="+num2str(zval))
				DFREF destFolder = $("z="+num2str(zval))
				Make/D/O/N=(DimSize(w, 0)) destFolder:W_maxima, destFolder:W_maxLocs
				Wave maxima = destFolder:W_maxima, maxLocs = destFolder:W_maxLocs
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), WaveUnits(w, 0), maxima, maxLocs
				for(k = 0; k < DimSize(w, 0); k += 1)
					ImageTransform/G=(k)/P=(j)/PTYP=0 getRow, w
					Wave W_ExtractedRow
					SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), W_ExtractedRow
					WaveStats/Q/R=(k1,k2) W_ExtractedRow
					maxima[k] = V_max
					maxLocs[k] = V_maxLoc
				endfor
			endfor
		endif
		KillWaves W_ExtractedRow
	endfor

	SetDataFolder initialFolder
End

Function ARPESMenu_MDCSinglePeakBatchFit()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	String tempFolderStr = UniqueName("temp", 11, 0)

	Variable startPos = 0, e1 = -inf, e2 = inf, k1 = -inf, k2 = inf	//, bgTerms = 2
	String func = "Lorentzian"
	Prompt func, "Fitting function", popup, "Lorentzian;Gaussian;"
	Prompt startPos, "Starting energy (eV)"
	Prompt e1, "Fit range energy start"
	Prompt e2, "Fit range energy end"
	Prompt k1, "Fit range k (or angle) start"
	Prompt k2, "Fit range k (or angle) end"
//	Prompt bgTerms, "Background terms"
	DoPrompt "MDC Single-peak Batch Fit: "+wList, func, startPos, e1, e2, k1, k2
	if(V_flag)
		abort
	endif

	Variable i, j
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $(StringFromList(i, wList))
		NewDataFolder/O GetWavesDataFolderDFR(w):MDC_Fitting
		DFREF mdcFitFolder = GetWavesDataFolderDFR(w):MDC_Fitting
		NewDataFolder/O mdcFitFolder:$NameOfWave(w)
		DFREF destFolder = mdcFitFolder:$NameOfWave(w)
		if(WaveDims(w) == 2)
			NewDataFolder $tempFolderStr
			DFREF tempFolder = $tempFolderStr
			SetDataFolder tempFolder
			EasyBatchFit(w, startPos, func, {e1,k1,e2,k2}, 1)
			CopyDataFolderContents(tempFolder, destFolder)
			KillDataFolder tempFolder
		elseif(WaveDims(w) == 3)
			for(j = 0; j < DimSize(w, 2); j += 1)
				NewDataFolder/O destFolder:$("z="+num2str(DimOffset(w, 2)+DimDelta(w, 2)*j))
				DFREF sliceDestFolder = destFolder:$("z="+num2str(DimOffset(w, 2)+DimDelta(w, 2)*j))
				NewDataFolder $tempFolderStr
				DFREF tempFolder = $tempFolderStr
				SetDataFolder tempFolder
				ImageTransform/P=(j)/PTYP=0 getPlane, w
				Wave M_ImagePlane
				SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), M_ImagePlane
				SetScale/P y, DimOffset(w, 1), DimDelta(w, 1), M_ImagePlane
				EasyBatchFit(M_ImagePlane, startPos, func, {e1,k1,e2,k2}, 1)
				CopyDataFolderContents(tempFolder, sliceDestFolder)
				KillDataFolder tempFolder
			endfor
		endif
	endfor

	SetDataFolder initialFolder
End

Static Function EasyBatchFit(w, startPos, func, range, axis)
	Wave w
	Variable startPos
	String func
	Wave range
	Variable axis		// either 0 (x) or 1 (y)

	if(axis == 0)
		ImageTransform/G=((startPos-DimOffset(w, 1))/DimDelta(w, 1)) getCol, w
		Wave slice = W_ExtractedCol
	elseif(axis == 1)
		ImageTransform/G=((startPos-DimOffset(w, 0))/DimDelta(w, 0)) getRow, w
		Wave slice = W_ExtractedRow
	endif
	SetScale/P x, DimOffset(w, axis), DimDelta(w, axis), slice

	// make initial guesses
	strswitch(func)
		case "Lorentzian":
			if(axis == 0)
				CurveFit/N/O/Q lor, slice(range[0],range[2])
			elseif(axis == 1)
				CurveFit/N/O/Q lor, slice(range[1],range[3])
			endif
			break
		case "Gaussian":
			if(axis == 0)
				CurveFit/N/O/Q gauss, slice(range[0],range[2])
			elseif(axis == 1)
				CurveFit/N/O/Q gauss, slice(range[1],range[3])
			endif
			break
	endswitch
	Wave W_coef
	Make/D/N=5 initGuess = 0
	initGuess[0] = W_coef[0]
	initGuess[2, 4] = W_coef[p-1]

	// do fitting and collect results
	BatchFit1D(w, axis, func, startPos, initGuess, range=range)
	KillWaves slice, W_coef, W_sigma, initGuess
	Wave W_coef0, W_coef1, W_coef2, W_coef3, W_coef4
	Wave W_sigma0, W_sigma1, W_sigma2, W_sigma3, W_sigma4
	Wave M_fit, M_residual
	Duplicate/O W_coef0, baseline_a
	Duplicate/O W_coef1, baseline_b
	Duplicate/O W_coef2, peak0_Area
	Duplicate/O W_coef3, peak0_Location
	Duplicate/O W_sigma0, sigma_baseline_a
	Duplicate/O W_sigma1, sigma_baseline_b
	Duplicate/O W_sigma2, sigma_peak0_Area
	Duplicate/O W_sigma3, sigma_peak0_Location
//	Rename W_coef0, baseline_a
//	Rename W_coef1, baseline_b
//	Rename W_coef2, peak0_Area
//	Rename W_coef3, peak0_Location
	strswitch(func)
		case "Lorentzian":
			Duplicate/O W_coef4, peak0_FWHM
			Duplicate/O W_sigma4, sigma_peak0_FWHM
//			Rename W_coef4, peak0_FWHM
			break
		case "Gaussian":
			Duplicate/O W_coef4, peak0_stdDev
			Duplicate/O W_sigma4, sigma_peak0_stdDev
//			Rename W_coef4, peak0_stdDev
			break
	endswitch
//	Rename W_sigma0, sigma_baseline_a
//	Rename W_sigma1, sigma_baseline_b
//	Rename W_sigma2, sigma_peak0_Area
//	Rename W_sigma3, sigma_peak0_Location
//	Rename W_sigma4, sigma_peak0_FWHM
//	Rename M_fit, fits_sum
	Duplicate/O M_fit, fits_sum
	Duplicate/O fits_sum, fits_peak0
	Wave baseline_a, baseline_b
	fits_peak0 -= baseline_a(x) + baseline_b(x)*y
	KillWaves/Z W_coef0, W_coef1, W_coef2, W_coef3, W_coef4
	KillWaves/Z W_sigma0, W_sigma1, W_sigma2, W_sigma3, W_sigma4
	KillWaves/Z M_fit
End

Function ARPESMenu_FindSymmetryAngle()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable angleGuess = 0, angleWin = 5
	Prompt angleGuess, "Symmetry angle guess (deg)"
	Prompt angleWin, "Angle search window (+/- deg)"
	DoPrompt "Find surface symmetry angle: "+wList, angleGuess, angleWin
	if(V_flag)
		abort
	endif

	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		if(WaveDims(w) == 2)
			SetDataFolder GetWavesDataFolderDFR(w)
			FS_FindSymmetryAngle(w, angleGuess, angleWin)
		else
			print "Find Symmetry Angle: Skipping "+StringFromList(i, wList)+". Input wave must be 2D (kx vs. ky)."
		endif
	endfor
End

Function ARPESMenu_FindOrigin()
	DFREF initialFolder = GetDataFolderDFR()
	String wList = GetBrowserSelectionList(1)
	if(strlen(wList) == 0)
		abort
	endif

	Variable t0 = 0, p0 = 0
	Prompt t0, "Theta (y axis) origin guess"
	Prompt p0, "Phi (x axis) origin guess"
	DoPrompt "Find surface origin: "+wList, p0, t0
	if(V_flag)
		abort
	endif

	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		if(WaveDims(w) == 2)
			SetDataFolder GetWavesDataFolderDFR(w)
			FS_FindOrigin(w, {p0,t0})
		else
			print "Find Origin: Skipping "+StringFromList(i, wList)+". Input wave must be 2D (kx vs. ky)."
		endif
	endfor
	SetDataFolder initialFolder
End

Function ARPESMenu_GraphEvsK()

	DFREF initialFolder = GetDataFolderDFR()

	String wList = GetBrowserSelectionList(1)
	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		if(WaveDims(w) == 2)
			ARPESGraph_EvsK(w)
		endif
	endfor

	SetDataFolder initialFolder
End

Function ARPESMenu_MarqueeBatchMPFit()

	String initialFolder = GetDataFolder(1)
	GetMarquee/K left, bottom
	Wave w = WaveRefIndexed("", 0, 4)
	String tempW = UniqueName("temp", 1, 0)
	Duplicate/O/R=(V_left, V_right)(V_bottom, V_top) w, $tempW
	Wave temp = $tempW

	Variable startPos
	String fitDim, peakType, blType, mode

	String peakTypeList = FunctionList("*_PeakFuncInfo", ";", "NPARAMS:1")
	peakTypeList = ReplaceString("_PeakFuncInfo", peakTypeList, "")
	String blTypeList = FunctionList("*_BLFuncInfo", ";", "NPARAMS:1")
	blTypeList = ReplaceString("_BLFuncInfo", blTypeList, "")
	String modeList = "Auto-detect peaks, then use constant initial guess;Auto-detect peaks, then propogate results;Auto-detect peaks always;"

	// defaults
	peakType = "Lorentzian"
	blType = "Linear"
	startPos = 0
	mode = StringFromList(1, modeList)

	Prompt fitDim, "Fit Along", popup, "x;y;"
	Prompt peakType, "Peak Type", popup, peakTypeList
	Prompt blType, "Baseline Type", popup, blTypeList
	Prompt mode, "Mode", popup, modeList
	Prompt startPos, "Starting Position"
	DoPrompt "MDC Batch Fit: "+NameOfWave(w), fitDim, peakType, blType, mode, startPos
	if(V_flag)
		abort
	endif

	SetDataFolder $GetWavesDataFolder(w, 1)
	BatchMultiPeakFit(temp, WhichListItem(fitDim, "x;y;"), peakType, blType, WhichListItem(mode, modeList)+3, startPos=startPos)
	SetDataFolder $initialFolder
	KillWaves temp
End

Function/S GetBrowserSelectionList(type)
	Variable type		// bitwise type:
					// bit 0 (dec=1): waves
					// bit 1 (dec=2): variables
					// bit 2 (dec=4): strings
					// bit 3 (dec=8): folders

	String objList = ""
	String objName
	Variable i = 0, stop = 0
	do
		objName = GetBrowserSelection(i)
		if(strlen(objName) > 0)
			if(TestBit(type, 0) && WaveExists($objName))
				objList = AddListItem(objName, objList, ";", INF)
			endif
			NVAR/Z var = $objName
			if(TestBit(type, 1) && NVAR_Exists(var))
				objList = AddListItem(objName, objList, ";", INF)
			endif
			SVAR/Z str = $objName
			if(TestBit(type, 2) && SVAR_Exists(str))
				objList = AddListItem(objName, objList, ";", INF)
			endif
			if(TestBit(type, 3) && DataFolderExists(objName))
				objList = AddListItem(objName, objList, ";", INF)
			endif
		else
			stop = 1
		endif
		i += 1
	while(!stop)

	return objList
End

Function ARPESMenu_GraphMap()

	String wList = GetBrowserSelectionList(1)
	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		if(WaveDims(w) == 2)
			ARPESGraph_EnergySurface(w)
		endif
	endfor
End

Function ARPESMenu_Rotate()

	String initialFolder = GetDataFolder(1)
	String wList = GetBrowserSelectionList(1)
	Variable angle = 45
	String doInterp = "Yes"
	Prompt angle, "Rotate By (deg)"
	Prompt doInterp, "Interpolate Values", popup, "Yes;No"
	DoPrompt "Rotate 2D//3D k Map: "+wList, angle, doInterp
	if(V_flag)
		abort	// cancelled
	endif
	Variable i, dims, skip = 0
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		SetDataFolder $GetWavesDataFolder(w, 1)
		dims = WaveDims(w)
		if(dims == 2)
			NewDataFolder/O/S RotateMap
			Rotate2D(w, angle, useInterp=StringMatch(doInterp, "Yes"))
			Wave M_rotated2D
			SetScale/P x, DimOffset(M_rotated2D, 0), DimDelta(M_rotated2D, 0), WaveUnits(w, 0), M_rotated2D
			SetScale/P y, DimOffset(M_rotated2D, 1), DimDelta(M_rotated2D, 1), WaveUnits(w, 1), M_rotated2D
			Note M_rotated2D, note(w)
			Note M_rotated2D, "[Rotate]\rangle="+num2str(angle)+"\rinterpolate="+num2str(StringMatch(doInterp, "Yes"))
			Duplicate/O M_rotated2D, $NameOfWave(w)
			KillWaves M_rotated2D
		elseif(dims == 3)
			NewDataFolder/O/S RotateMap
			Rotate3D(w, angle, useInterp=StringMatch(doInterp, "Yes"))
			Wave M_rotated3D
			SetScale/P x, DimOffset(M_rotated3D, 0), DimDelta(M_rotated3D, 0), WaveUnits(w, 0), M_rotated3D
			SetScale/P y, DimOffset(M_rotated3D, 1), DimDelta(M_rotated3D, 1), WaveUnits(w, 1), M_rotated3D
			SetScale/P z, DimOffset(M_rotated3D, 2), DimDelta(M_rotated3D, 2), WaveUnits(w, 2), M_rotated3D
			Note M_rotated3D, note(w)
			Note M_rotated3D, "[Rotate]\rangle="+num2str(angle)+"\rinterpolate="+num2str(StringMatch(doInterp, "Yes"))
			Duplicate/O M_rotated3D, $NameOfWave(w)
			KillWaves M_rotated3D
		else
			print "Rotate 2D/3D: Skipping "+StringFromList(i, wList)+". Input wave must be 2D (kx vs. ky) or 3D (E vs. kx vs. ky)."
		endif
	endfor
	SetDataFolder $initialFolder
End

Function ARPESMenu_ExtractSurface()

	String initialFolder = GetDataFolder(1)
	String wList = GetBrowserSelectionList(1)
	Variable energy = 0, width = 0
	Prompt energy, "Energy"
	Prompt width, "Integration Width"
	String showGraph = "Yes"
	Prompt showGraph, "Plot Energy Surface?", popup, "Yes;No"
	String helpStr = "Extracts the 2D/3D energy surface, centered at the specified energy and integrated over the specified energy width."
	DoPrompt/HELP=helpStr "Extract Energy Surface: "+wList, energy, width, showGraph
	if(V_flag)
		abort	// cancelled
	endif

	Variable i, j, k, p1, p2
	for(i = 0; i < ItemsInList(wList); i += 1)
		WAVE w = $StringFromList(i, wList)
		p1 = round((energy-(width/2)-DimOffset(w, 0))/DimDelta(w, 0))	// 1st plane to sum
		p2 = round((energy+(width/2)-DimOffset(w, 0))/DimDelta(w, 0))	// last plane to sum
		p1 = Coerce(p1, 0, DimSize(w, 0)-1)	// force these to be in range
		p2 = Coerce(p2, 0, DimSize(w, 0)-2)
		if(WaveDims(w) == 3)
			NewDataFolder/O/S GetWavesDataFolderDFR(w):EnergySurface
			DFREF destFolder = GetWavesDataFolderDFR(w):EnergySurface
			Make/O/D/N=(DimSize(w, 1), DimSize(w, 2)) destFolder:$NameOfWave(w) = 0
			WAVE output = destFolder:$NameOfWave(w)
			SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), output
			SetScale/P y, DimOffset(w, 2), DimDelta(w, 2), WaveUnits(w, 2), output
			DFREF tempFolder = NewFreeDataFolder()
			SetDataFolder tempFolder
			for(j = min(p1,p2); j <= max(p1,p2); j += 1)
				ImageTransform/PTYP=2/P=(j) getPlane, w
				WAVE M_ImagePlane
				output += M_ImagePlane
			endfor
			KillWaves M_ImagePlane
			Note output, note(w)
			Note output, "[Extract Energy Surface]"
			Note output, "Energy="+num2str(energy)
			Note output, "Integration Width="+num2str(width)
			if(StringMatch(showGraph, "Yes"))
				ARPESGraph_EnergySurface(output)
			endif
		elseif(WaveDims(w) == 4)
			NewDataFolder/O/S GetWavesDataFolderDFR(w):EnergySurface
			DFREF destFolder = GetWavesDataFolderDFR(w):EnergySurface
			Make/O/D/N=(DimSize(w, 1), DimSize(w, 2), DimSize(w, 3)) destFolder:$NameOfWave(w) = 0
			WAVE output = destFolder:$NameOfWave(w)
			SetScale/P x, DimOffset(w, 1), DimDelta(w, 1), WaveUnits(w, 1), output
			SetScale/P y, DimOffset(w, 2), DimDelta(w, 2), WaveUnits(w, 2), output
			SetScale/P z, DimOffset(w, 3), DimDelta(w, 3), WaveUnits(w, 3), output
			DFREF tempFolder = NewFreeDataFolder()
			SetDataFolder tempFolder
			for(j = min(p1,p2); j<=max(p1,p2); j += 1)
				output += w[j][p][q][r]
			endfor
			Note output, note(w)
			Note output, "[Extract Energy Surface]"
			Note output, "Energy="+num2str(energy)
			Note output, "Integration Width="+num2str(width)
			if(StringMatch(showGraph, "Yes"))
				print "Sorry, this routine can't yet plot 3D output data."
			endif
		else
			print "Extract Energy Surface: Skipping "+StringFromList(i, wList)+". Input wave must be 3D (E, kx, ky) or 4D (E, kx, ky, kz)."
		endif
	endfor
	SetDataFolder $initialFolder
End

Function ARPESMenu_FitPolyBareBand()

	String initialFolder = GetDataFolder(1)
	String wList = GetBrowserSelectionList(1)
	Variable i, j
	for(i = ItemsInList(wList)-1; i >= 0; i -= 1)
		if(!WaveExists($StringFromList(i, wList)))
			wList = RemoveListItem(i, wList)
		endif
	endfor

//	Variable peakIndex = 0
	Variable polyTerms = 3, fitRangeStart = -inf, fitRangeEnd = inf, matchAtX = 0
	String doPlot = "Yes"
	Prompt polyTerms, "Polynomial Terms"
	Prompt fitRangeStart, "Fit Range Start"
	Prompt fitRangeEnd, "Fit Range End"
	Prompt matchAtX, "Constrain to match data at x="
//	Prompt doPlot, "Plot Result?", popup, "Yes;No;"
	//Prompt fitRange2Start, "2nd Fit Range Start"
	//Prompt fitRange2End, "2nd Fit Range End"
	DoPrompt "Fit Polynomial Bare Band: "+wList, polyTerms, fitRangeStart, fitRangeEnd, matchAtX//, doPlot
	if(V_flag)
		abort	// cancelled
	endif

	if(!ItemsInList(wList))
		DoAlert 0, "No waves selected."
		abort
	endif

	Variable useSigma
	String tempFolder = UniqueName("temp", 11, 0)
	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		if(WaveDims(w) == 2)
			DFREF mdcFolder = GetWavesDataFolderDFR(w):MDC_Fitting
			DFREF wFolder = mdcFolder:$NameOfWave(w)
			for(j = 0; j < DimSize(w, 2); j += 1)
				DFREF fitFolder = wFolder:$("z="+num2str(DimOffset(w, 2)+DimDelta(w, 2)*j))
				if(DataFolderRefStatus(fitFolder))
					useSigma = WaveExists($"sigma_peak0_Location")
					NewDataFolder/O/S fitFolder:PolyBareBand
					NewDataFolder/O/S $NameOfWave(w)
					if(useSigma)
						Wave sigmaW = $"sigma_peak0_Location"
						FitPolyMatchedAtPosition(w, {fitRangeStart, fitRangeEnd}, polyTerms, matchAtX, sigma=sigmaW)
					else
						FitPolyMatchedAtPosition(w, {fitRangeStart, fitRangeEnd}, polyTerms, matchAtX)
					endif
					Wave fit = $("fit_"+NameOfWave(w))
					Duplicate/O w, $("res_"+NameOfWave(w))
					Wave res = $("res_"+NameOfWave(w))
					res -= fit(x)
					Variable/G V_fitRangeStart = fitRangeStart
					Variable/G V_fitRangeEnd = fitRangeEnd
					Variable/G V_polyTerms = polyTerms
					Variable/G V_matchAtX = matchAtX
					Variable/G V_useSigma = useSigma
				else
					// skip
					print "Fit folder "+GetDataFolder(1, fitFolder)+"z="+num2str(DimOffset(w, 2)+DimDelta(w, 2)*j)+" not found. Skipping."
				endif
			endfor
		elseif(WaveDims(w) == 1)
			SetDataFolder GetWavesDataFolderDFR(w)
			useSigma = WaveExists($("sigma_"+NameOfWave(w)))
			NewDataFolder/O/S PolyBareBand
			NewDataFolder/O/S $NameOfWave(w)
			if(useSigma)
				Wave sigmaW = $(GetWavesDataFolder(w, 1)+"sigma_"+NameOfWave(w))
				FitPolyMatchedAtPosition(w, {fitRangeStart, fitRangeEnd}, polyTerms, matchAtX, sigma=sigmaW)
			else
				FitPolyMatchedAtPosition(w, {fitRangeStart, fitRangeEnd}, polyTerms, matchAtX)
			endif
			Wave fit = $("fit_"+NameOfWave(w))
			Duplicate/O w, $("res_"+NameOfWave(w))
			Wave res = $("res_"+NameOfWave(w))
			res -= fit(x)
			Variable/G V_fitRangeStart = fitRangeStart
			Variable/G V_fitRangeEnd = fitRangeEnd
			Variable/G V_polyTerms = polyTerms
			Variable/G V_matchAtX = matchAtX
			Variable/G V_useSigma = useSigma
		endif
//		Note fit, note(w)+"[FitPolyBareBand]"
//		Note fit, "Fit Range Start="+num2str(fitRangeStart)
//		Note fit, "Fit Range End="+num2str(fitRangeEnd)
//		Note fit, "Poly Terms="+num2str(polyTerms)
//		Note fit, "Match at X="+num2str(matchAtX)
//		Note fit, "Use Sigma="+num2str(useSigma)
//		Duplicate/O fit, $NameOfWave(w)
//		Duplicate/O res, $("res_"+NameOfWave(w))
//		KillWaves/Z fit, res
//		if(StringMatch(doPlot, "Yes"))
//			Display w, $NameOfWave(w)//, $("res_"+NameOfWave(w))
//		endif
	endfor

	SetDataFolder $initialFolder
End

Function ARPESMenu_ARPESDataLoader()

	ADL#Initialize(0)
	ADL#OpenGUI()
End

Function ARPESMenu_MDCMultipeakBatchFit()

	String wList = GetBrowserSelectionList(1)
	String wName
	Variable i
	for(i = ItemsInList(wList)-1; i >= 0; i -= 1)
		wName = StringFromList(i, wList)
		if(!WaveExists($wName) || (WaveDims($wName) != 2 && WaveDims($wName) != 3))
			wList = RemoveListItem(i, wList)
		endif
	endfor
	if(strlen(wList) == 0)
		DoAlert 0, "No 2D or 3D waves selected for MDC batch fitting."
		abort
	endif

	String peakType
	String blType
	Variable startPos
	String mode

	String peakTypeList = FunctionList("*_PeakFuncInfo", ";", "NPARAMS:1")
	peakTypeList = ReplaceString("_PeakFuncInfo", peakTypeList, "")
	String blTypeList = FunctionList("*_BLFuncInfo", ";", "NPARAMS:1")
	blTypeList = ReplaceString("_BLFuncInfo", blTypeList, "")
	String modeList = "Auto-detect single peak, then propogate results;Auto-detect multiple peaks, then use constant initial guess;Auto-detect multiple peaks, then propogate results;Auto-detect multiple peaks always;"

	// defaults
	peakType = "Lorentzian"
	blType = "Linear"
	startPos = 0
	mode = StringFromList(2, modeList)

	Prompt peakType, "Peak Type", popup, peakTypeList
	Prompt blType, "Baseline Type", popup, blTypeList
	Prompt mode, "Mode", popup, modeList
	Prompt startPos, "Starting Energy"
	DoPrompt "MDC Batch Fit: "+wList, peakType, blType, mode, startPos
	if(V_flag)
		abort
	endif

	Variable initialGuessOptions
	Variable modeIndex = WhichListItem(mode, modeList)
	switch(modeIndex)
//		case 0:
//			initialGuessOptions = 1
//			break
		case 1:
			initialGuessOptions = 3
			break
		case 2:
			initialGuessOptions = 4
			break
		case 3:
			initialGuessOptions = 5
			break
		default:
			DoAlert 0, "Invalid fitting mode. Not supported."
			abort
	endswitch

	Variable j, pos
	DFREF initialFolder = GetDataFolderDFR()
	String tempFolderName = UniqueName("temp", 11, 0)
	NewDataFolder initialFolder:$tempFolderName
	DFREF tempFolder = initialFolder:$tempFolderName

	for(i = 0; i < ItemsInList(wList); i += 1)
		Wave w = $StringFromList(i, wList)
		DFREF currentWaveFolder = GetWavesDataFolderDFR(w)
		SetDataFolder currentWaveFolder
		//SetDataFolder GetWavesDataFolderDFR(w)
		NewDataFolder/O MDC_Fitting
		DFREF fitProcFolder = :MDC_Fitting
		if(WaveDims(w) == 2)
			NewDataFolder/O fitProcFolder:$NameOfWave(w)
			DFREF destFolder = fitProcFolder:$NameOfWave(w)
			SetDataFolder tempFolder
			BatchMultiPeakFit(w, 1, peakType, blType, initialGuessOptions, startPos=startPos)		// results will be in :BatchMultiPeakFit:
			CopyDataFolderContents(BatchMultiPeakFit, destFolder)
			KillDataFolder BatchMultiPeakFit
			SetDataFolder currentWaveFolder
		elseif(WaveDims(w) == 3)
			for(j = 0; j < DimSize(w, 2); j += 1)
				pos = DimOffset(w, 2)+DimDelta(w, 2)*j
				NewDataFolder/O fitProcFolder:$NameOfWave(w)
				DFREF waveResultFolder = fitProcFolder:$NameOfWave(w)
				NewDataFolder/O waveResultFolder:$("z="+num2str(pos))
				DFREF destFolder = waveResultFolder:$("z="+num2str(pos))
				SetDataFolder tempFolder
				ImageTransform/P=(j)/PTYP=0 getPlane, w
				Wave M_ImagePlane
				BatchMultiPeakFit(M_ImagePlane, 1, peakType, blType, initialGuessOptions, startPos=startPos)		// results will be in :BatchMultiPeakFit:
				CopyDataFolderContents(BatchMultiPeakFit, destFolder)
				Duplicate/O M_ImagePlane, destFolder:M_ImagePlane
				KillDataFolder BatchMultiPeakFit
				SetDataFolder currentWaveFolder
			endfor
		endif
	endfor
	KillDataFolder tempFolder
	SetDataFolder initialFolder
End

Static Function CopyDataFolderContents(source, dest)	// essentially an overwrite-capable version of DuplicateDataFolder
	DFREF source, dest	// source and destination folders

	DFREF initialFolder = GetDataFolderDFR()
	SetDataFolder source
	String wList = WaveList("*", ";", "")
	String vList = VariableList("*", ";", 4)
	String cvList = VariableList("*", ";", 5)
	String sList = StringList("*", ";")
	String fList = ReplaceString(",", StringByKey("FOLDERS", DataFolderDir(1)), ";")

	String objName
	Variable i
	for(i = 0; i < ItemsInList(wList); i += 1)
		objName = StringFromList(i, wList)
		Duplicate/O $objName, dest:$objName
	endfor

	// variables
	for(i = 0; i < ItemsInList(vList); i += 1)
		objName = StringFromList(i, vList)
		NVAR v = $objName
		Variable/G dest:$objName = v
	endfor

	// complex variables
	for(i = 0; i < ItemsInList(cvList); i += 1)
		objName = StringFromList(i, cvList)
		NVAR/C cv = $objName
		Variable/C/G dest:$objName = cv
	endfor

	// strings
	for(i = 0; i < ItemsInList(sList); i += 1)
		objName = StringFromList(i, sList)
		SVAR s = $objName
		String/G dest:$objName = s
	endfor

	// folders (uses recursion to get all subfolders)
	for(i = 0; i < ItemsInList(fList); i += 1)
		objName = StringFromList(i, fList)
		DFREF sourceSubFolder = $objName
		NewDataFolder/O dest:$objName
		DFREF destSubFolder = dest:$objName
		CopyDataFolderContents(sourceSubFolder, destSubFolder)
	endfor

	SetDataFolder initialFolder
End
