// ***********************************************************************************************************************************
// * SIStem Lab Notebook -	Utility for summarizing/organizing sets of ARPES data acquired by the SIStem data	*
// *						acquisition software at SIS beamline (Swiss Light Source, Paul Scherrer Institut).		*
// *																								*
// * 	Software by N. C. Plumb | nicholas.plumb@psi.ch													*
// * 	Surface/Interface Spectroscopy Beamline (SIS, X09LA)												*
// *	Swiss Light Source																			*
// * 	Paul Scherrer Insitut																			*
// * 	CH-5232 Villigen PSI																			*
// * 	Switzerland																					*
// *----------------------------------------------------------------------------												*
// *																								*
// * 08.11.14:		Coding is approaching "done" state. More or less first functional version.					*
// * 13.07.15:		Added feature to load files from the "Action" button. Keithley10 is now read into the "I_RMU (A)"	*
// *				column representing RMU mirror current. Fixed (re-)initialization error.						*
// * 28.10.15:		New "Scan Name" column (new file attribute since v1.3.1).								*
// *				"Comments" is loaded according to version number. After 1.3.1, attribute is in "/". Prior to that	*
// *				it was recorded in "/Electron Analyzer/Image Data". The version numbers are compared using	*
// *				new static function CompareFileVersions().											*
// ***********************************************************************************************************************************

#pragma rtGlobals=3			// Use modern global access method and strict wave access.
#pragma version=0.1
#pragma ModuleName = SLN	// moniker of the SIStem Lab Notebook module
#include <HDF5 Browser>		// HDF5 Browser.ipf must be installed.
#include "BitwiseOperations"
#include "NumericUtilities"
#include <Resize Controls Panel>	// included with Igor


Static StrConstant PACKAGES_FOLDER = 						"root:Packages"											// standard Packages folder
Static StrConstant SLN_FOLDER = 							"root:Packages:SISLabNotebook"							// top folder
Static StrConstant SLN_UI_FOLDER =						"root:Packages:SISLabNotebook:ui"						// user interface folder
Static StrConstant SLN_DATA_FOLDER = 					"root:Packages:SISLabNotebook:data"						// database folder containing waves that hold data for the corresponding tabs
Static StrConstant SLN_LISTBOX = 							"root:Packages:SISLabNotebook:ui:M_listbox"			// just the data displayed in the current tab view
Static StrConstant SLN_LISTBOX_SELECTION = 				"root:Packages:SISLabNotebook:ui:M_selection"			// the data selection in the current tab view
Static StrConstant SLN_TAB_LABELS = 						"root:Packages:SISLabNotebook:ui:W_tabLabels"			// list of tabs
Static StrConstant SLN_TAB_SELECTION = 					"root:Packages:SISLabNotebook:ui:V_tabSel"				// global for passing the index of the selected tab between functions
Static StrConstant SLN_TAB_LINKS =						"root:Packages:SISLabNotebook:ui:W_dataLink"			// contains the paths to the database waves that correspond with the tabs
Static StrConstant SLN_LISTBOX_COLUMN_TITLES = 		"root:Packages:SISLabNotebook:ui:W_columnTitles"		// titles of the columns to display (different from Igor column "labels")
Static StrConstant SLN_LISTBOX_COLUMN_EDIT_MODES =	"root:Packages:SISLabNotebook:ui:W_columnEditModes"	// editing modes of the columns


Static Function Init(overwrite)
	Variable overwrite

	if(DataFolderExists(SLN_FOLDER) && overwrite)
		KillDataFolder $SLN_FOLDER
	endif

	WAVE/T W_settings = DatabaseSettings()
	Variable numCols = DimSize(W_settings, 0)
	Variable i

	// Make sure the necessary folders exist
	NewDataFolder/O $PACKAGES_FOLDER
	NewDataFolder/O $SLN_FOLDER
	NewDataFolder/O $SLN_DATA_FOLDER
	NewDataFolder/O $SLN_UI_FOLDER


	// Set up from scratch
//	if(overwrite)

	// Initialize the listbox
//	Make/T/O/N=(0, numCols) $SLN_LISTBOX							// listbox (empty)
	if(!WaveExists($SLN_LISTBOX))
		Make/T/N=(0, numCols) $SLN_LISTBOX							// listbox (empty)
		Make/O/N=(0, numCols) $SLN_LISTBOX_SELECTION				// listbox selection (empty)
		Make/T/O/N=(numCols) $SLN_LISTBOX_COLUMN_TITLES			// column titles
		Make/O/N=(numCols) $SLN_LISTBOX_COLUMN_EDIT_MODES 		// column editing modes
	endif
	WAVE/T W_listbox = $SLN_LISTBOX
	WAVE W_selection = $SLN_LISTBOX_SELECTION
	WAVE/T W_colTitles = $SLN_LISTBOX_COLUMN_TITLES
	W_colTitles = W_settings[p][%Title]
	WAVE W_editModes = $SLN_LISTBOX_COLUMN_EDIT_MODES
	W_editModes = str2num(W_settings[p][%EditMode])
	for(i = 0; i < numCols; i += 1)										// apply dim labels
		SetDimLabel 1, i, $W_settings[i][%DimLabel], W_listbox, W_selection
		SetDimLabel 0, i, $W_settings[i][%DimLabel], W_editModes
	endfor

	// Initialize the tabs
	String dataName

	DFREF initialFolder = GetDataFolderDFR()
	SetDataFolder $SLN_DATA_FOLDER

	if(!WaveExists($SLN_TAB_LABELS))
		Make/T $SLN_TAB_LABELS = {"Book 0", "+"}
		WAVE/T W_tabLabels = $SLN_TAB_LABELS
		Make/T/O/N=(DimSize(W_tabLabels, 0)-1) $SLN_TAB_LINKS
		WAVE/T W_links = $SLN_TAB_LINKS

		// Create a database corresponding with the first tab
		dataName = UniqueName("M_", 1, 0)
		Make/T/O/N=(0, numCols) $dataName

		Variable/G $SLN_TAB_SELECTION = 0
		NVAR V_tab = $SLN_TAB_SELECTION
	else
		WAVE/T W_links = $SLN_TAB_LINKS
		NVAR V_tab = $SLN_TAB_SELECTION
		dataName = W_links[V_tab]
	endif

	WAVE/T W_database = $dataName
	SetDataFolder initialFolder
	for(i = 0; i < numCols; i += 1)
		SetDimLabel 1, i, $W_settings[i][%DimLabel], W_database
	endfor

	// Link the tab to the database
	W_links[V_tab] = GetWavesDataFolder(W_database, 2)		// kind = 2: full path plus wave name (i.e., "root:Packages:SISLabNotebook:data:M_0")
//	endif
End

Static Function/WAVE DatabaseSettings()	// matrix containing default settings of the database

	Make/FREE/T/N=(1,6) w
	SetDimLabel 1, 0, DimLabel, w		// Dimension label string
	SetDimLabel 1, 1, Title, w			// Column title (displayed at top of listbox)
	SetDimLabel 1, 2, Width, w			// Column width in pixels. No longer used. Listbox now uses autosizing mode.
	SetDimLabel 1, 3, EditMode, w		// Numeric code for editing mode. See "selwave=sw" in Igor Help for ListBox. Overridden if IsPopup = "1".
	SetDimLabel 1, 4, IsPopup, w		// Uses PopupContexualMenu to select from finite choices?
	SetDimLabel 1, 5, PopupProc, w		// List string function for popup menu

	w[0][%DimLabel] = {"Filename", "Scan Name", "Scan Type","Comments", "Temperature B"}
	w[5][%DimLabel] = {"hv", "hv Mode", "Tilt", "Theta", "Phi"}
	w[10][%DimLabel] = {"X", "Y", "Z", "Pass Energy", "Lens Mode"}
	w[15][%DimLabel] = {"Acquisition Mode", "Energy Scale", "Energy Range", "Sweeps", "Dwell Time"}
	w[20][%DimLabel] = {"Detector Window", "Detector Slices", "Exit Slit", "FE Horiz. Width", "FE Vert. Width"}
	w[25][%DimLabel] = {"Keithley10", "Pressure AC1", "Pressure PC1", "Temperature A", "Directory"}
	w[30][%DimLabel] = {"Size", "Date", "Time"}

	w[0][%Title] = {"Filename", "Scan Name", "Scan Type", "Comments", "T\BB\M (K)"}
	w[5][%Title] = {"hv (eV)", "Mode", "Tilt (deg)", "Theta (deg)", "Phi (deg)"}
	w[10][%Title] = {"X (mm)", "Y (mm)", "Z (mm)", "Pass (eV)", "Lens Mode"}
	w[15][%Title] = {"Acq. Mode", "Energy Scale", "En. Range (eV)", "Sweeps", "Dwell (ms)"}
	w[20][%Title] = {"Det. Window", "Det. Slices", "Exit Slit (um)", "FE-H (mm)", "FE-V (mm)"}
	w[25][%Title] = {"I\BRMU\M (A)", "AC1 (mbar)", "PC1 (mbar)", "T\BA\M (K)", "Directory"}
	w[30][%Title] = {"Size", "Date", "Time"}

	w[][%EditMode] = "0x00"	// most columns are uneditable
	w[3][%EditMode] = "0x02"		// only comments [3] are editable
	w[][%IsPopup] = "0"		// none currently use popups
	w[][%PopupProc] = ""		//

	return w
End

Window Win_SIStemLabNotebook() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(478,68,866,253) as "SIStem Lab Notebook"
	SetDrawLayer UserBack
	TabControl tab0,pos={4,3},size={379,149},proc=SLN#TabProc
	TabControl tab0,userdata(ResizeControlsInfo)= A"!!,?8!!#8L!!#C\"J,hqOz!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	TabControl tab0,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	TabControl tab0,userdata(ResizeControlsInfo) += A"zzz!!#?(FEDG<zzzzzzzzzzzzzz!!!"
	TabControl tab0,font="Geneva",tabLabel(0)="Book 0",tabLabel(1)="+",value= 0
	ListBox list0,pos={7,27},size={372,122},proc=SLN#ListBoxProc
	ListBox list0,userdata(MouseDownRow)=  "7",userdata(MouseDownCol)=  "7"
	ListBox list0,userdata(ResizeControlsInfo)= A"!!,@C!!#=;!!#Bt!!#@Xz!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	ListBox list0,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	ListBox list0,userdata(ResizeControlsInfo) += A"zzz!!#?(FEDG<zzzzzzzzzzzzzz!!!"
	ListBox list0,font="Geneva",fSize=11
	ListBox list0,listWave=root:Packages:SISLabNotebook:ui:M_listbox
	ListBox list0,selWave=root:Packages:SISLabNotebook:ui:M_selection
	ListBox list0,titleWave=root:Packages:SISLabNotebook:ui:W_columnTitles,mode= 9
	ListBox list0,special= {0,0,1},userColumnResize= 1
	PopupMenu popup_add,pos={5,160},size={39,20},proc=SLN#PopMenuProc_Add,title="+"
	PopupMenu popup_add,help={"Add items"}
	PopupMenu popup_add,userdata(ResizeControlsInfo)= A"!!,?X!!#A/!!#>*!!#<Xz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	PopupMenu popup_add,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#?(FEDG<zzzzzzzzzzz"
	PopupMenu popup_add,userdata(ResizeControlsInfo) += A"zzz!!#?(FEDG<zzzzzzzzzzzzzz!!!"
	PopupMenu popup_add,font="Geneva",mode=0,value= #"\"Files...;From folders...\""
	Button button_delete,pos={51,160},size={25,20},proc=SLN#ButtonProc_Delete,title="-"
	Button button_delete,help={"Delete selected items"}
	Button button_delete,userdata(ResizeControlsInfo)= A"!!,D[!!#A/!!#=+!!#<Xz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	Button button_delete,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#?(FEDG<zzzzzzzzzzz"
	Button button_delete,userdata(ResizeControlsInfo) += A"zzz!!#?(FEDG<zzzzzzzzzzzzzz!!!"
	Button button_delete,font="Geneva"
	PopupMenu popup_action,pos={106,160},size={66,20},proc=SLN#PopMenuProc_Action,title="Action"
	PopupMenu popup_action,userdata(ResizeControlsInfo)= A"!!,F9!!#A/!!#?=!!#<Xz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	PopupMenu popup_action,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#?(FEDG<zzzzzzzzzzz"
	PopupMenu popup_action,userdata(ResizeControlsInfo) += A"zzz!!#?(FEDG<zzzzzzzzzzzzzz!!!"
	PopupMenu popup_action,mode=0,value= #"\"Select all;Load selected files;Sort data...;Export notebook...\""
	SetWindow kwTopWin,hook(ResizeControls)=ResizeControls#ResizeControlsHook
	SetWindow kwTopWin,userdata(ResizeControlsInfo)= A"!!*'\"z!!#C'!!#AHzzzzzzzzzzzzzzzzzzzzz"
	SetWindow kwTopWin,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzzzzzzzzzzzzzzz"
	SetWindow kwTopWin,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzzzzzzzzz!!!"
EndMacro

Static Function OpenGUI()

	DoWindow/K Win_SIStemLabNotebook		// only one notebook allowed (with multiple tabs)
	Execute/Q "Win_SIStemLabNotebook()"
	RefreshTabLabels()
	NVAR V_tab = $SLN_TAB_SELECTION
	TabControl tab0,value=V_tab
	MoveWindow 350,100,900,500	// comfortable starting size/position
End

Static Function ListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	Variable eventMod = lba.eventMod
	WAVE/T W_listbox = lba.listWave
	WAVE W_selection = lba.selWave
	WAVE/T W_links = $SLN_TAB_LINKS
	WAVE/T W_colTitles = $SLN_LISTBOX_COLUMN_TITLES
	WAVE/T W_database = GetSelectedTabDatabase()

	Variable mouseDownRow, mouseDownCol
	Variable i
	String colLabel

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			ListBox list0, userdata(MouseDownRow)=num2str(row)
			ListBox list0, userdata(MouseDownCol)=num2str(col)
			break
		case 2: // mouse up
			mouseDownRow = str2num(GetUserData("", "list0", "MouseDownRow"))
			mouseDownCol = str2num(GetUserData("", "list0", "MouseDownCol"))
			if(mouseDownRow == -1 && row == -1 && col != mouseDownCol)		// valid column drag (Must begin & end in the column label row [-1].)

				// move the dimension labels, column titles, and selection/editing settings of the listbox
				colLabel = GetDimLabel(W_listbox, 1, mouseDownCol)
				Duplicate/FREE/T/O W_colTitles, W_copyColTitles
				Duplicate/FREE/O W_selection, W_copySelection
				DeletePoints/M=1 mouseDownCol, 1, W_listbox, W_selection
				DeletePoints mouseDownCol, 1, W_colTitles
				InsertPoints/M=1 col, 1, W_listbox, W_selection
				SetDimLabel 1, col, $colLabel, W_listbox, W_selection
				InsertPoints col, 1, W_colTitles
				W_colTitles[col] = W_copyColTitles[mouseDownCol]

				RefreshListbox()	// should handle all the remaining stuff

			elseif((row != mouseDownRow) && (mouseDownRow >= 0) && (row >= 0) && (!TestBit(eventMod, 1)))	// valid row drag (Must begin & end in allowed range. Excludes multi-selection using the shift key event mod.)

				// move the row
				Make/FREE/T/O/N=(DimSize(W_database, 1)) W_rowCopy = W_database[mouseDownRow][p]
				DeletePoints/M=0 mouseDownRow, 1, W_database
				InsertPoints/M=0 row, 1, W_database
				W_database[row][] = W_rowCopy[q]

				RefreshListbox()
			endif
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			W_database[row][%$GetDimLabel(W_listbox, 1, col)] = W_listbox[row][col]
			break
	endswitch

	return 0
End

Static Function PopMenuProc_Add(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			strswitch(popStr)
				case "Files...":
					AddFilesToCurrentTab()
					break
				case "From folders...":
					AddFilesFromFolderToCurrentTab()
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ButtonProc_Delete(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			NVAR V_tab = $SLN_TAB_SELECTION
			WAVE/T W_links = $SLN_TAB_LINKS
			WAVE/T W_database = $W_links[V_tab]
			WAVE W_selection = $SLN_LISTBOX_SELECTION
			WAVE/T W_listbox = $SLN_LISTBOX
			Variable i
			Variable origNumRows = DimSize(W_selection, 0)
			for(i = origNumRows-1; i >= 0 ; i -= 1)
				if(TestBit(W_selection[i][0], 0) || TestBit(W_selection[i][0], 3))	// row selected? bit 0 = normal selection; bit 1 = shift selection (i.e., multiple items)
					if(DimSize(W_database, 0) > 1)
						DeletePoints/M=0 i, 1, W_database, W_listbox, W_selection							// normally just delete
					else
						Redimension/N=(0, DimSize(W_database, 1)) W_database, W_listbox, W_selection		// use redimension if the last row is being removed (preserves column DimLabels)
					endif
				endif
			endfor
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Static Function SelectAllRows()		// select all rows in the current notebook

	Wave W_sel = $SLN_LISTBOX_SELECTION
	W_sel[][0] = SetBit(W_sel, 0)
End

Static Function/WAVE GetSelectedRows()		// returns a wave containing the indices of the selected rows in the current tab

	Wave W_sel = $SLN_LISTBOX_SELECTION
	Make/FREE/N=0 rows
	Variable i
	for(i = 0; i  < DimSize(W_sel, 0); i += 1)
		if(TestBit(W_sel[i][0], 0) || TestBit(W_sel[i][0], 3))	// bit 0 indicates "normal" selection; bit 3 indicates shift-selection (i.e., multiple additional rows)
			InsertPoints inf, 1, rows
			rows[DimSize(rows, 0)-1] = i
		endif
	endfor

	return rows
End

Static Function/T GetPathsOfSelectedScans()	// returns a semicolon-delimeted list of the full file paths of the scans which the user has selected in the current notebook

	Wave/T db = $SLN_LISTBOX
	Wave rows = GetSelectedRows()
	String paths = ""
	Variable i
	for(i = 0; i < DimSize(rows, 0); i += 1)
		paths = AddListItem(db[rows[i]][%Directory] + ":" + db[rows[i]][%Filename], paths)
	endfor

	return paths
End

Static Function PopMenuProc_Action(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	NVAR V_tab = $SLN_TAB_SELECTION
	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			strswitch(popStr)
				case "Select all":
					SelectAllRows()
					break
				case "Load selected files":
					LoadSIStemHDF5_EasyMulti(files=GetPathsOfSelectedScans())
					break
				case "Sort data...":
					SortDatabase()
					break
				case "Export notebook...":
					String exportTabs
					Prompt exportTabs, "Which tabs do you want to export?", popup, "Current;All;"
					DoPrompt "Export notebook", exportTabs
					strswitch(exportTabs)
						case "All":
							ExportAsTXT(-1)	// save all tabs
							break
						case "Current":
							ExportAsTXT(V_tab)	// save current tab
							break
					endswitch
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Static Function ExportAsTXT(tab)
	Variable tab		// tab index; -1: save all tabs

	Variable i, j
	WAVE/T W_links = $SLN_TAB_LINKS
	WAVE/T W_tabLabels = $SLN_TAB_LABELS
	WAVE/T W_colTitles = $SLN_LISTBOX_COLUMN_TITLES

	if(tab < 0)	// save all tabs
		NewPath/Q/M="Select folder" folderPath
		if(V_flag)
			abort	// operation canceled by user
		endif

		for(i = 0; i < numpnts(W_links); i += 1)
			WAVE/T W_database = $W_links[i]
			Make/FREE/T/O/N=(DimSize(W_database, 0), DimSize(W_database, 1)) W_reformatted = W_database	// Make a copy. We will reformat the column labels.
			for(j = 0; j < DimSize(W_reformatted, 1); j += 1)
				SetDimLabel 1, j, $RemoveFormattingCharacters(W_colTitles[j]), W_reformatted
			endfor
			Save/J/U={0,0,1,0}/P=folderPath W_reformatted as W_tabLabels[i]+".txt"
		endfor
		KillPath/Z folderPath
	else
		WAVE/T W_database = $W_links[tab]
		Make/FREE/T/O/N=(DimSize(W_database, 0), DimSize(W_database, 1)) W_reformatted = W_database	// Make a copy. We will reformat the column labels.
		for(i = 0; i < DimSize(W_reformatted, 1); i += 1)
			SetDimLabel 1, i, $RemoveFormattingCharacters(W_colTitles[i]), W_reformatted
		endfor
		Save/J/U={0,0,1,0} W_reformatted as W_tabLabels[tab]+".txt"
	endif
End

Static Function/S RemoveFormattingCharacters(strIn)	// gets rid of most - but not all - formatting characters that could be encountered (eg., "\f01" or "\B")
	String strIn

	String strOut = strIn
	strOut = ReplaceString("\B", strOut, "")	// subscript
	strOut = ReplaceString("\M", strOut, "")	// remove sub/superscript
	strOut = ReplaceString("\S", strOut, "")	// superscript
	strOut = ReplaceString("\f00", strOut, "")	// remove style formatting
	strOut = ReplaceString("\f01", strOut, "")	// bold
	strOut = ReplaceString("\f02", strOut, "")	// italics
	strOut = ReplaceString("\f03", strOut, "")	// bold + italics
	strOut = ReplaceString("\f04", strOut, "")	// underline
	strOut = ReplaceString("\f05", strOut, "")	// bold + underline
	strOut = ReplaceString("\f06", strOut, "")	// italics + underline
	strOut = ReplaceString("\f07", strOut, "")	// bold + italics + underline

	return strOut
end

Static Function SortDatabase()
	WAVE/T W_links = $SLN_TAB_LINKS
	WAVE/T W_listbox = $SLN_LISTBOX
	WAVE/T W_colTitles = $SLN_LISTBOX_COLUMN_TITLES
	NVAR V_tab = $SLN_TAB_SELECTION

	String titleList = ""
	Variable i, j, dbCol, ascending
	for(i = 0; i < DimSize(W_colTitles, 0); i += 1)
		titleList = AddListItem(W_colTitles[i], titleList, ";", inf)
	endfor
	String titleStr, order, tabs
	Prompt titleStr, "Column", popup, titleList
	Prompt order, "Order", popup, "Ascending;Descending;"
	Prompt tabs, "Apply to", popup, "Current tab;All tabs;"
	DoPrompt/HELP="Sorts the entire database according to the values in the specified column." "Sort Database", titleStr, order, tabs
	if(!V_flag)

		strswitch(order)
			default:
			case "Ascending":
				ascending = 1
				break
			case "Descending":
				ascending = 0
				break
		endswitch

		strswitch(tabs)
			default:
			case "All tabs":
				Make/T/O/FREE W_tabs = W_links
				break
			case "Current tab":
				Make/T/O/FREE/N=1 W_tabs = W_links[V_tab]
				break
		endswitch

		for(i = 0; i < DimSize(W_tabs, 0); i += 1)		// for each tab...
			// sort the database
			WAVE/T W_database = $W_tabs[i]
			dbCol = FindDimLabel(W_database, 1, GetDimLabel(W_listbox, 1, WhichListItem(titleStr, titleList)))
			Make/FREE/O/T/N=(DimSize(W_database, 0)) W_sortCol
			Make/FREE/O/I/N=(DimSize(W_database, 0)) W_sortIndex
			W_sortCol = W_database[p][dbCol]//[FindDimLabel(db, 1, dimLabelStr)]
			W_sortIndex = p

			if(ascending)
				Sort/A W_sortCol, W_sortIndex			// alphanumeric
			else
				Sort/A/R W_sortCol, W_sortIndex		// reverse (descending) alphanumeric
			endif
			Duplicate/FREE/O/T W_database, W_dbCopy
			for(j = 0; j < DimSize(W_database, 0); j += 1)
				W_database[j][] = W_dbCopy[W_sortIndex[j]][q]
			endfor
		endfor
	endif

	// update the listbox
	RefreshListbox()
End

Static Function TabProc(tca) : TabControl
	STRUCT WMTabControlAction &tca

	WAVE/T W_tabLabels = $SLN_TAB_LABELS
	NVAR V_tab = $SLN_TAB_SELECTION
	V_tab = tca.tab

	switch( tca.eventCode )
		case 2: // mouse up - this should handle selection of the "+" tab
			Variable rClick = TestBit(tca.eventMod, 4)	// is it a right-click?
			if(rClick)
				if(V_tab != DimSize(W_tabLabels, 0)-1)	// not the "+" tab?
					PopupContextualMenu/N "SLN Tab Menu"
				else											// Right click on the "+" tab. Does nothing except set the selection back to the last valid tab.
					V_tab -= 1
					TabControl tab0,value = V_tab
				endif
			elseif(V_tab == (DimSize(W_tabLabels, 0)-1))	// last tab, which corresponds to "+"
				NewTab()
			endif
			break
		case -1: // control being killed
			break
	endswitch

	// update the listbox
	RefreshListbox()

	return 0
End

Menu "SLN Tab Menu", ContextualMenu
	"Rename...", /Q, SLN#RenameTab()
	"Close", /Q, SLN#CloseTab()
End

Static Function NewTab()
	WAVE/T W_tabLabels = $SLN_TAB_LABELS
	WAVE/T W_listbox = $SLN_LISTBOX
	WAVE/T W_links = $SLN_TAB_LINKS
	NVAR V_tab = $SLN_TAB_SELECTION

	// Create the new tab
	Variable initialNumTabs = DimSize(W_tabLabels, 0)-1			// W_tabLabels includes "+", so at any given time its size is 1 more than the number of "real" tabs
	InsertPoints DimSize(W_tabLabels, 0), 1, W_tabLabels		// add the new tab
	W_tabLabels[initialNumTabs] = UniqueTabLabel("Book ")		// give it a unique label
	W_tabLabels[initialNumTabs+1] = "+"							// move the "+" tab to the end
	Variable i
	for(i = 0; i < DimSize(W_tabLabels, 0); i += 1)				// attach the labels
		TabControl tab0, tabLabel(i)=W_tabLabels[i]
	endfor

	// Make the corresponding database
	WAVE/T W_settings = DatabaseSettings()
	Variable numCols = DimSize(W_settings, 0)
	DFREF initialFolder = GetDataFolderDFR()
	SetDataFolder $SLN_DATA_FOLDER
	String dataName = UniqueName("M_", 1, 0)
	Make/T/O/N=(0, numCols) $dataName
	WAVE/T W_database = $dataName
	for(i = 0; i < numCols; i += 1)
		SetDimLabel 1, i, $W_settings[i][%DimLabel], W_database
	endfor
	SetDataFolder initialFolder

	// Link the database to the tab
	InsertPoints DimSize(W_links, 0), 1, W_links
	W_links[initialNumTabs] = GetWavesDataFolder(W_database, 2)		// kind = 2: full path plus wave name (i.e., "root:Packages:SISLabNotebook:data:M_0")
End

Static Function/S UniqueTabLabel(baseLabel)
	String baseLabel

	String name
	Variable i = 0
	do
		name = baseLabel+num2str(i)
		FindValue/TEXT=name $SLN_TAB_LABELS
		i += 1
	while(V_value >= 0)

	return name
End

Static Function RenameTab()

	NVAR V_tab = $(SLN_TAB_SELECTION)		// tab index
	WAVE/T W_tabLabels = $SLN_TAB_LABELS
	String newName = W_tabLabels[V_tab]
	Prompt newName, "New Name"
	DoPrompt "Rename Tab", newName

	if(!V_flag)
		W_tabLabels[V_tab] = newName
		RefreshTabLabels()
	endif
End


Static Function CloseTab()

	NVAR V_tab	 = $SLN_TAB_SELECTION		// tab index
	WAVE/T W_tabLabels = $SLN_TAB_LABELS
	WAVE/T W_links = $SLN_TAB_LINKS
	WAVE/T W_data = $(W_links[V_tab])

	// close the tab and clean up the corresponding database plus link
	TabControl tab0, tabLabel(DimSize(W_tabLabels, 0)-1)=""		// decrement the number of tabs shown
	DeletePoints V_tab, 1, W_tabLabels, W_links					// remove the tab label from the list
	KillWaves/Z W_data											// kill the corresponding database wave

	if(numpnts(W_links) == 0)
		NewTab()		// Never let the tabs completely vanish. Instead, create a new blank one.
	endif

	// land on an a suitable tab value (tabOutcome)
	Variable tabOutcome = Coerce(V_tab, 0, DimSize(W_tabLabels, 0)-2)
	TabControl tab0, value=tabOutcome
	V_tab = tabOutcome

	// update the GUI
	RefreshTabLabels()
End


Static Function RefreshTabLabels()

	WAVE/T W_tabLabels = $SLN_TAB_LABELS
	Variable i
	for(i = 0; i < DimSize(W_tabLabels, 0); i += 1)
		TabControl tab0, tabLabel(i)=W_tabLabels[i]//, value = 0
	endfor
End


Static Function RefreshListbox()

	WAVE/T W_database = GetSelectedTabDatabase()
	WAVE/T W_listbox = $SLN_LISTBOX
	WAVE W_selection = $SLN_LISTBOX_SELECTION
	WAVE W_editModes = $SLN_LISTBOX_COLUMN_EDIT_MODES
	WAVE/T W_colTitles = $SLN_LISTBOX_COLUMN_TITLES
//	WAVE W_settings = DatabaseSettings()
	Redimension/N=(DimSize(W_database, 0), DimSize(W_database, 1)) W_listbox, W_selection
	W_selection = W_editModes[%$GetDimLabel(W_selection, 1, q)]
	W_listbox = W_database[p][%$GetDimLabel(W_listbox, 1, q)]
//	W_editModes
End

Static Function/WAVE GetSelectedTabDatabase()		// returns the text wave for the database linked to the currently selected tab

	NVAR V_tab = $SLN_TAB_SELECTION
	WAVE/T W_links = $SLN_TAB_LINKS
	WAVE/T W_database = $W_links[V_tab]

	return W_database
End


Static Function AddFilesToCurrentTab()//tab)
//	Variable tab		// tab index

	String fileFilters = "SIStem HDF5 (*.h5):.h5;"
	fileFilters += "All (*.*):.*;"
	Open/D/R/M="Select files"/MULT=1/F=fileFilters refnum
	String files = S_fileName
	files = ReplaceString("\r", files, ";")
	if(strlen(files) == 0)
		abort
	else
		ImportToCurrentTab(files)
	endif
	KillVariables/Z S_fileName
End



Static Function AddFilesFromFolderToCurrentTab()		// not at all done

	NewPath/Q/M="Select folder" folderPath
	if(V_flag)
		KillPath/Z folderPath
		abort	// operation canceled by user
	endif
	PathInfo folderPath		// returns S_path, which will contain the top-level directory

	Variable includeSubDirs
	String dirs = IndexedDir(folderPath, -1, 1)
	String files, filePaths		// filePaths = the complete list of full paths that should be passed to ImportToCurrentTab()
	Variable i, j, numFiles

	if(ItemsInList(dirs) > 0)
		Prompt includeSubDirs, "Include sub-directory heirarchy?", popup, "No;Yes;"
		DoPrompt "Directory search mode", includeSubDirs
		if(includeSubDirs)
			WAVE/T W_dirs = FindAllSubdirectories(S_path)
		endif
		InsertPoints 0, 1, W_dirs
		W_dirs[0] = S_path
	else
		Make/FREE/O/T W_dirs = {S_path}
	endif

	filePaths = ""
	for(i = 0; i < numpnts(W_dirs); i += 1)
		NewPath/Q/O folderPath, W_dirs[i]
		files = IndexedFile(folderPath, -1, ".h5")
		numFiles = ItemsInList(files)
		for(j = 0; j < numFiles; j += 1)
			filePaths = AddListItem(ParseFilePath(2, W_dirs[i], ":", 0, 0)+StringFromList(j, files), filePaths)
		endfor
	endfor
//	endif

	if(ItemsInList(filePaths) > 0)
		ImportToCurrentTab(filePaths)
	endif

	KillPath/Z folderPath
End


Static Function ImportToCurrentTab(files)
	String files		// semicolon-delimited list of file paths

	NVAR V_tab = $SLN_TAB_SELECTION
	WAVE/T W_links = $SLN_TAB_LINKS
	WAVE/T W_database = $W_links[V_tab]

	Variable i, j, stop, entryExists, row, refnum, rank, offset, delta, final, isSingleValue, isUnwritten
	String val, filename, fullPath, dirPath
	String imageDataPath = "/Electron Analyzer/Image Data" 	// in the HDF5 structure
	String auxDataPath = "/Other Instruments"					// ... ditto
	String auxGroup											// e.g., "hv"
	String auxGroupPath										// will be, e.g., auxDataPath + "/hv"

	STRUCT HDF5DataInfo di

	Make/FREE/T/O/N=0 W_scannedDims					// names of scanned dimensions

	Variable numFiles = ItemsInList(files)
	for(i = 0; i < numFiles; i += 1)

		// !! neeed code here to search for an existing entry !!

		fullPath = StringFromList(i, files)
		fullPath = ParseFilePath(5, fullPath, ":", 0, 0)		// mode 5 = convert path to Mac/Igor style
//		print fullPath	// debugging
		dirPath = ParseFilePath(1, fullPath, ":", 1, 0)		// mode 1 = just directory -- target file is dropped.
		if( stringmatch(":", dirPath[strlen(dirPath)-1]) )
			dirPath = dirPath[0, strlen(dirPath)-2] 			// trim any trailing ":"
		endif
		filename = ParseFilePath(0, fullPath, ":", 1, 0)		// mode 0 = just the file with extension

		if(entryExists)		// update existing entry

		else					// insert new entry
			row = DimSize(W_database, 0)
			InsertPoints/M=0 DimSize(W_database, 0), 1, W_database
		endif

		W_database[row][%Filename] = filename
		W_database[row][%Directory] = dirPath

		NewPath/Q/O currentPath, dirPath
		Open/R/P=currentPath refnum as filename
		FStatus refnum		// returns V_logEOF
		sprintf val, "%f MB", V_logEOF/10^6
		W_database[row][%Size] = val
		Close refnum
		KillPath/Z currentPath

		HDF5OpenFile/R refnum as fullPath
		InitHDF5DataInfo(di)
		HDF5DatasetInfo(refnum, imageDataPath, 0, di)
		rank = di.ndims

		// figure out the scan type
		Redimension/N=0 W_scannedDims	// empty this list
		if(rank == 2)
			W_database[row][%'Scan Type'] = "Slice"
		else
			val = ""
			for(j = 2; j < rank; j += 1)
				InsertPoints numpnts(W_scannedDims), 1, W_scannedDims
				W_scannedDims[numpnts(W_scannedDims)-1] = H5_GetStrAttData(refnum, imageDataPath, "Axis"+num2str(j)+".Description", 0)
				val = val + W_scannedDims[numpnts(W_scannedDims)-1]+", "
			endfor
			W_database[row][%'Scan Type'] = RemoveEnding(val, ", ") 	// trim off the last terminator
		endif

		// figure out the scan ranges of the various dimensions
		for(j = 0; j < rank; j += 1)
			if(j == 0)
				offset = H5_GetNumAttData(refnum, imageDataPath, "Axis"+num2str(j)+".Scale", 0)
				delta = H5_GetNumAttData(refnum, imageDataPath, "Axis"+num2str(j)+".Scale", 1)
				final= offset + delta*(di.dims[j]-1)
				W_database[row][%'Energy Range'] = num2str(offset) + " --> " + num2str(final)
			elseif(j != 1)	// ignore 1, which is just the detector angle window
				offset = H5_GetNumAttData(refnum, imageDataPath, "Axis"+num2str(j)+".Scale", 0)
				delta = H5_GetNumAttData(refnum, imageDataPath, "Axis"+num2str(j)+".Scale", 1)
				final= offset + delta*(di.dims[j]-1)
				W_database[row][%$H5_GetStrAttData(refnum, imageDataPath, "Axis"+num2str(j)+".Description", 0)] = num2str(offset) + " --> " + num2str(final)
			endif
		endfor

		// fill out the rest of the table
		W_database[row][%'Scan Name'] = H5_GetStrAttData(refnum, "/", "Scan Name", 0)
		W_database[row][%'Energy Scale'] = H5_GetStrAttData(refnum, imageDataPath, "Energy Scale", 0)
		W_database[row][%'Acquisition Mode'] = H5_GetStrAttData(refnum, imageDataPath, "Acquisition Mode", 0)
//		W_database[row][%Comments] = H5_GetStrAttData(refnum, imageDataPath, "Comments", 0)
		W_database[row][%'Pass Energy'] = num2str(H5_GetNumAttData(refnum, imageDataPath, "Pass Energy (eV)", 0))
		W_database[row][%'Lens Mode'] = H5_GetStrAttData(refnum, imageDataPath, "Lens Mode", 0)
		W_database[row][%'Date'] = H5_GetStrAttData(refnum, imageDataPath, "Date Created", 0)
		W_database[row][%'Time'] = H5_GetStrAttData(refnum, imageDataPath, "Time Created", 0)
		W_database[row][%'Detector Window'] = "X: " + num2str(H5_GetNumAttData(refnum, imageDataPath, "Detector First X-Channel", 0)) + "-" + num2str(H5_GetNumAttData(refnum, imageDataPath, "Detector Last X-Channel", 0 )) + "; Y: " + num2str(H5_GetNumAttData(refnum, imageDataPath, "Detector First Y-Channel", 0)) + "-" + num2str(H5_GetNumAttData(refnum, imageDataPath, "Detector Last Y-Channel", 0))
		W_database[row][%'Detector Slices'] = num2str(H5_GetNumAttData(refnum, imageDataPath, "Detector Slices", 0))
		W_database[row][%'Dwell Time'] = num2str(H5_GetNumAttData(refnum, imageDataPath, "Dwell Time (ms)", 0))
		W_database[row][%Sweeps] = num2str(H5_GetNumAttData(refnum, imageDataPath, "Sweeps on Last Image", 0))
		W_database[row][%'hv Mode'] = H5_GetStrAttData(refnum, auxDataPath+"/hv", "Mode", 0)
//		W_database[row][%'Work Function'] = num2str(H5_GetNumAttData(refnum, imageDataPath, "Work Function (eV)", 0))

		// the storage location of comments attribute changed after file version 1.3.1
		String fileVer = H5_GetStrAttData(refnum, "/", "File Version", 0)
		if(CompareFileVersions(fileVer, "1.3.1") == 0)
			// fileVer is newer than 1.3.1. Comments are an attribute of "/".
			W_database[row][%Comments] = H5_GetStrAttData(refnum, "/", "Comments", 0)
		else
			// fileVer is equal to or older than 1.3.1. Comments are an attribute of "/Electron Analyzer/Image Data".
			W_database[row][%Comments] = H5_GetStrAttData(refnum, imageDataPath, "Comments", 0)
		endif

		// Get data from the other instruments. The for-loop will handle most cases.
		// A couple are special and need to be handled separately afterwards.
		HDF5ListGroup refnum, auxDataPath
		if(!V_flag)
			for(j = 0; j < ItemsInList(S_HDF5ListGroup); j += 1)
				auxGroup = StringFromList(j, S_HDF5ListGroup)
				if(FindDimLabel($SLN_LISTBOX, 1, auxGroup) >= 0)
					auxGroupPath = auxDataPath+"/"+auxGroup
					HDF5DatasetInfo(refnum, auxGroupPath, 0, di)
					isSingleValue = !((di.ndims > 1) || (di.dims[0] > 1))
					FindValue/TEXT=(auxGroup) W_scannedDims
					isUnwritten = V_value < 0
					if(isSingleValue && isUnwritten)
						W_database[row][%$auxGroup] = num2str(H5_GetNumAttData(refnum, auxGroupPath, "", 0))
					elseif(!isSingleValue && isUnwritten)
						W_database[row][%$auxGroup] = num2str(H5_GetNumAttData(refnum, auxGroupPath, "", 0)) + " [+]"		// "[+]" indicates that a readback array exists in the dataset
					elseif(!isSingleValue && !isUnwritten)
						W_database[row][%$auxGroup] = W_database[row][%$auxGroup] + " [+]"
					endif
				endif
			endfor
		endif

		HDF5CloseFile/Z refnum
	endfor

	RefreshListbox()
End

Static Function H5_GetNumAttData(refnum, objPath, att, index)
	Variable refnum
	String objPath		// path to the object (data)
	String att			// attribute
	Variable index	// if att is a wave with size > 1, then index will choose which value to take

	Variable val = NaN
	DFREF initialFolder = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()

	Variable objType =	 2	// by default, the object is assumed to be a dataset
	strswitch(objPath)
		case ".":			// IMPORTANT! Use ".", not "/" when refering to the top level of the file. See Igor HDF5 function docs.
			objType = 1	// this is a group
			break
		case "/":
			objPath = "."	// Automatically replace "/" with "." in case of easy programmer error.
			objType = 1	// this is a group
			break
		case "/Electron Analyzer":
			objType = 1	// this is a group
			break
		case "/Electron Analyzer/Image Data":
			objType = 2	// this is a dataset
			break
		case "/Other Instruments":
			objType = 1	// this is a group
			break
	endswitch

	HDF5LoadData/A=att/N=W_temp/O/Q/Z/TYPE=(objType) refnum, objPath

	if(!V_flag)
		WAVE W_temp
		val = W_temp[index]
	endif

	SetDataFolder initialFolder
	return val
End

Static Function/S H5_GetStrAttData(refnum, objPath, att, index)
	Variable refnum
	String objPath	// path to the object (data)
	String att		// attribute
	Variable index	// If att is a wave with size > 1, then index will choose which value to take

	String val = ""
	DFREF initialFolder = GetDataFolderDFR()
	SetDataFolder NewFreeDataFolder()

	Variable objType =	 2	// by default, the object is assumed to be a dataset
	strswitch(objPath)
		case ".":			// IMPORTANT! Use ".", not "/" when refering to the top level of the file. See Igor HDF5 function docs.
			objType = 1	// this is a group
			break
		case "/":			// Automatically replace "/" with "." in case of easy programmer error.
			objPath = "."	// this is a group
			objType = 1
			break
		case "/Electron Analyzer":
			objType = 1	// this is a group
			break
		case "/Electron Analyzer/Image Data":
			objType = 2	// this is a dataset
			break
		case "/Other Instruments":
			objType = 1	// this is a group
			break
	endswitch

	HDF5LoadData/A=att/N=W_temp/O/Q/Z/TYPE=(objType) refnum, objPath

	if(!V_flag)
		WAVE/T W_temp
		val = W_temp[index]
	endif

	SetDataFolder initialFolder
	return val
End


Static Function/WAVE FindAllSubdirectories(dirPath)		// recursively finds all directories in the entire heirarchy of dirPath
	String dirPath

	Make/T/FREE W_parentDirs = {dirPath}
	Make/T/FREE/N=0 W_subDirs, W_subSubDirs	// W_subDirs = immediate level down. W_subSubDirs = the next level.
	String dirList = ""
	Variable i, numFound, origSize, stop = 0

	do
		stop = DimSize(W_parentDirs, 0) == 0
		Redimension/N=0 W_subSubDirs			// empty this list and start fresh
		for(i = 0; i < DimSize(W_parentDirs, 0); i += 1)
			NewPath/O/Q/Z P_subDir, W_parentDirs[i]
			dirList = IndexedDir(P_subDir, -1, 1)
			KillPath/Z P_subDir
			numFound = ItemsInList(dirList)
			if(numFound > 0)		// append new directories to W_subSubDirs
				origSize = DimSize(W_subSubDirs, 0)
				InsertPoints origSize, numFound, W_subSubDirs
				W_subSubDirs[origSize, ] = StringFromList(p-origSize, dirList)
			endif
		endfor
		origSize = DimSize(W_subDirs, 0)
		numFound = DimSize(W_subSubDirs, 0)
		if(numFound > 0)		// append W_subSubDirs to W_subDirs
			InsertPoints origSize, numFound, W_subDirs
			W_subDirs[origSize, ] = W_subSubDirs[p-origSize]
		endif
		Redimension/N=(numFound) W_parentDirs
		W_parentDirs = W_subSubDirs			// Replace values in W_parentDirs with those from W_subSubDirs
	while(!stop)

	KillPath/Z P_subDir	// just to be sure

	return W_subDirs
End

// Version string format "x.y.z". Returns: 0 for "x1.y1.z1" > "x2.y2.z2"; 1 for "x1.y1.z1" < "x2.y2.z2"; -1 if they're equal.
Static Function CompareFileVersions(vStr1, vStr2)
	String vStr1
	String vStr2

	String s1, s2
	Variable v1, v2, len1, len2, i

	len1 = ItemsInList(vStr1, ".")
	len2 = ItemsInList(vStr2, ".")

	for(i = 0; i < (len1 > len2 ? len1 : len2); i += 1)
		s1 = StringFromList(i, vStr1, ".")
		if(strlen(s1) == 0)
			v1 = 0
		else
			v1 = str2num(s1)
		endif

		s2 = StringFromList(i, vStr2, ".")
		if(strlen(s2) == 0)
			v2 = 0
		else
			v2 = str2num(s2)
		endif

		if(v1 > v2)
			return 0	// vStr1 is the higher version
		elseif(v1 < v2)
			return 1	// vStr2 is the higher version
		endif
	endfor

	return -1	// they're equal
End
