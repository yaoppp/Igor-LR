#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <HDF5 Browser>	// HDF5 Browser.ipf must be installed.

Function loadHDF5() //load single ADRESS HDF5 file
	Variable refNum
	String fileName

	HDF5OpenFile/R refNum as ""
	If (V_Flag==0)
		fileName = S_filename[0,strlen(S_filename)-4];
		HDF5LoadData/IGOR=-1/N=$filename refNum,"Matrix"
        HDF5CloseFile refNum
	EndIf
End

Function loadHDF5_multi(pathStr) //load multi ADRESS HDF5 file
	String pathStr
	Variable refNum
	String fileName

	HDF5OpenFile/R refNum as pathStr
	If (V_Flag==0)
		//fileName = S_filename[0,strlen(S_filename)-4];
		fileName = ParseFilePath(3, S_path+S_filename, ":", 0, 0)
		HDF5LoadData/IGOR=-1/N=$filename refNum,"Matrix"
		HDF5CloseFile refNum
	EndIf
End

// **********************************************************************************
// LoadSIStemHDF5_EasyMulti - Multiple-file-enabled version of 		*
// 								LoadSIStemHDF5_Easy below.	*
//																*
// 08.07.14:	First coding.											*
// **********************************************************************************

Function LoadHDF5_EasyMulti_oldstyle([files])
	String files	// optional semicolon-delimited list of file paths to load

	Variable useDialog
	if(ParamIsDefault(files))
		useDialog = 1
	else
		useDialog = 0
	endif

	Variable refnum
	String fileFilters = "Hierarchical data format HDF5 (*.h5):.h5;"
	fileFilters += "All (*.*):.*;"

	if(useDialog)
		Open/D/R/M="Import HDF5 data"/MULT=1/F=fileFilters refnum
		Close refnum
		files = S_fileName
		files = ReplaceString("\r", files, ";")
	endif

	if(strlen(files) == 0)
		abort
	else
		Variable i
		String file
		print "Loading HDF5 files..."
		for(i = 0; i < ItemsInList(files); i += 1)
			file = StringFromList(i, files)
			//LoadHDF5_Easy_oldstyle(file, mode=0, showTime=0)
			loadHDF5_multi(file)
			print "  "+file
		endfor
//		Import(files)
//		UpdateDatabaseListbox()
	endif
	KillVariables/Z S_fileName
End
