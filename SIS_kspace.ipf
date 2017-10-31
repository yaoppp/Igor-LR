#pragma rtGlobals=3			// Use modern global access method and strict wave access.
#pragma IgorVersion = 6.2		// uses multithreading and free waves, as well as rtGlobals=3
#pragma ModuleName = k
#include "NumericUtilities"

//*** Physical constants ***//
Static Constant m = 5.68562958e-32  	// Electron mass in eV*(Angstroms^(-2))*s^2
Static Constant hbar = 6.58211814e-16    	// hbar in eV*s

//*** Structure definitions ***//
Structure kTransformSettings
	WAVE rawData					// Reference to the "raw" data to be transformed. It is "raw", because any angle and energy offsets should already be applied before running the transform.
	Variable energyDim				// Typically 0. Units must be eV. Set to -1 if nonexistent, in which case fixedEnergy must be specified.
	Variable thetaDim					// Polar angle. Typically 1. Units must be deg. Set to -1 if nonexistent, in which case fixedTheta must be specified.
	Variable tiltDim					// Tilt angle. Very often 2. Units must be deg. Set to -1 if nonexistent, in which case fixedTilt must be specified.
	Variable hvDim					// Photon energy. Most often either 2 or 3. Units must be eV. Set to -1 if nonexistent, in which case fixedHv must be specified.
	Variable angularMode				// 0: false; 1: true. Typically will be true.
	Variable slitAlongTheta				// 0: false; 1: true. Currently always TRUE.
	Variable fixedEnergy				// Fixed binding energy value in eV if energyDim < 0. Offset to apply in eV. If numpnts(energyOffset) > 0, the values are treated as polynomial coefficients for applying the offset as a function of the angle across the detector (useful for straight slits or high-precision Fermi edge calibration).
	Variable fixedTheta				// Fixed theta value in deg used if thetaDim < 0
	Variable fixedTilt					// Fixed tilt value in deg used if tiltDim < 0
	Variable fixedHv					// Fixed photon energy in eV used if hvDim < 0
	Variable invertDetectorScale		// 0: does nothing; 1: reverses the sign of the angle scale on the detector
	Variable rotateAzimuth				// Rotates the azimuthal (i.e., polar-vs-tilt) kx-ky plane by the specified degrees.
	Variable includePhotonMomentum	// 0: don't include; 1: include. NOT CONSIDERED AT THE MOMENT
	Variable beamTheta, beamTilt		// Theta and tilt angles of the incoming beam in deg. Defined as the rotation angles where the beam would be normal to the sample. Only used if includePhotonMomentum = 1.
	Variable workFunction				// Sample work function in eV.
	Variable innerPotential				// Inner potential in eV. Should be positive.
	WAVE outputSize					// Specifies the number of points for each dimension in the output (i.e., {size0,size1,size2,size3}). If nonexistent, or whenever an element is <= 0, default is to use the same size of the corresponding dimension in the raw data.
	String destination					// Desired path of the output
	Variable useInterpolation			// 0: No interpolation will be used. 1: Uses interpolation (recommended, possibly a bit slower). Applies to 2D-4D data. For 1D data, Igor uses interpolation by default.
EndStructure

// Does everything to set up the **empty** k-space output wave for the data. Must be performed before Transform().
Static Function/WAVE Init(s, [planeType, planeIndex, planeTranspose])
	STRUCT kTransformSettings &s
	Variable planeType	// Optional. Follows definition of Igor ImageTransform PTYP flag. 0: x-y plane; 1: x-z plane; 2: y-z plane
	Variable planeIndex	// Optional. Must be used with planeType.
	Variable planeTranspose	// Optional. Must be used with planeType. 0: false; 1: true;
	
	WAVE w		// output wave reference
	Variable extractPlane
	if((!ParamIsDefault(planeType)) || (!ParamIsDefault(planeIndex)))
		if((!ParamIsDefault(planeType)) && (!ParamIsDefault(planeIndex)) && (!ParamIsDefault(planeTranspose)))
			extractPlane = 1
		else
			print "Error during k-space transform: For a plane-only transform, both the planeType, planeIndex, planeTranspose must be specified."
			return w
		endif
	else
		extractPlane = 0
	endif
	
	// Establish the boundaries of the output in k-space (before any azimuthal rotation)
	Variable kx1 = kxEndpnt(s, 0)
	Variable kx2 = kxEndpnt(s, 1)
	Variable ky1 = kyEndpnt(s, 0)
	Variable ky2 = kyEndpnt(s, 1)
	Variable kz1 = kzEndpnt(s, 0)
	Variable kz2 = kzEndpnt(s, 1)
	
	// Handle azimuthal rotation, if applicable...
	if(s.rotateAzimuth != 0)
		// Do azimuthal rotation. Variables kxc1, kyc1, kxc2, kyc2,... are the {x,y} coordinates 
		// of the *corners* of the map in the *rotated* frame.
		Variable phi = s.rotateAzimuth*pi/180
		Variable kxc1 = kx1*cos(phi) - ky1*sin(phi)
		Variable kyc1 = kx1*sin(phi) + ky1*cos(phi)
		Variable kxc2 = kx1*cos(phi) - ky2*sin(phi)
		Variable kyc2 = kx1*sin(phi) + ky2*cos(phi) 
		Variable kxc3 = kx2*cos(phi) - ky1*sin(phi)
		Variable kyc3 = kx2*sin(phi) + ky1*cos(phi)
		Variable kxc4 = kx2*cos(phi) - ky2*sin(phi)
		Variable kyc4 = kx2*sin(phi) + ky2*cos(phi)
		
		// Now redefine the boundaries of the output in k-space suitable for azimuthal rotation
		Variable kxLo = min(min(kxc1, kxc2), min(kxc3, kxc4))
		Variable kxHi = max(max(kxc1, kxc2), max(kxc3, kxc4))
		Variable kyLo = min(min(kyc1, kyc2), min(kyc3, kyc4))
		Variable kyHi = max(max(kyc1, kyc2), max(kyc3, kyc4))
		
		// Redfine the boundaries of the output in k-space according to extrema of the 
		// rotated map.
		kx1 = kxLo
		kx2 = kxHi
		ky1 = kyLo
		ky2 = kyHi
	endif

	// Make the output wave (with custom size, if specified)...
	Make/FREE/N=4 size
	if(extractPlane)
		if(planeType == 0)
			if(planeTranspose)
				size[0] = OutputDimSize(s, 1)
				size[1] = OutputDimSize(s, 0)	
			else
				size[0] = OutputDimSize(s, 0)
				size[1] = OutputDimSize(s, 1)
			endif
		elseif(planeType == 1)
			if(planeTranspose)
				size[0] = OutputDimSize(s, 2)
				size[1] = OutputDimSize(s, 0)
			else
				size[0] = OutputDimSize(s, 0)
				size[1] = OutputDimSize(s, 2)
			endif
		elseif(planeType == 2)
			if(planeTranspose)
				size[0] = OutputDimSize(s, 2)
				size[1] = OutputDimSize(s, 1)
			else
				size[0] = OutputDimSize(s, 1)
				size[1] = OutputDimSize(s, 2)
			endif
		else
			print "Error during k-space transform: Invalid planeType."
			return w
		endif
		size[2,3] = 0
	else
		size = OutputDimSize(s, p)
	endif
	Make/O/N=(size[0], size[1], size[2], size[3]) $(s.destination)
	WAVE w = $(s.destination)
	
	// OS-dependent momentum units string
	String kUnits = MomentumUnitsStr()
	
	// Strings used for applying the scales
	String cmd = ""
	String dimList = "x;y;z;t"
	
	// Do the scales...
	if(s.energyDim >= 0)
		SetDimLabel s.energyDim, -1, 'Binding Energy', w
		sprintf cmd, "SetScale/I %s, %f, %f, \"eV\", %s", StringFromList(s.energyDim, dimList), energyEndpnt(s, 0), energyEndpnt(s, 1), GetWavesDataFolder(w, 2)
		Execute/Q cmd
	endif
	
	if(s.thetaDim >= 0)
		SetDimLabel s.thetaDim, -1, kx, w
		sprintf cmd, "SetScale/I %s, %f, %f, " + kUnits + ", %s", StringFromList(s.thetaDim, dimList), kx1, kx2, GetWavesDataFolder(w, 2)
		Execute/Q cmd
	endif
	
	if(s.tiltDim >= 0)
		SetDimLabel s.tiltDim, -1, ky, w
		sprintf cmd, "SetScale/I %s, %f, %f, " + kUnits + ", %s", StringFromList(s.tiltDim, dimList), ky1, ky2, GetWavesDataFolder(w, 2)
		Execute/Q cmd
	endif
	
	if(s.hvDim >= 0)
		SetDimLabel s.hvDim, -1, kz, w
		sprintf cmd, "SetScale/I %s, %f, %f, " + kUnits + ", %s", StringFromList(s.hvDim, dimList), kz1, kz2, GetWavesDataFolder(w, 2)
		Execute/Q cmd
	endif

	Note w, note(s.rawData)	// Duplicate note from rawData
	
	// Append info about the transform settings...
	Note w, "[kTransform]"
	Note w, "rawData="+GetWavesDataFolder(s.rawData, 2)
	Note w, "energyDim="+num2str(s.energyDim)
	Note w, "thetaDim="+num2str(s.thetaDim)
	Note w, "tiltDim="+num2str(s.tiltDim)
	Note w, "hvDim="+num2str(s.hvDim)
	Note w, "angularMode="+num2str(s.angularMode)
	Note w, "slitAlongTheta="+num2str(s.slitAlongTheta)
	Note w, "fixedEnergy="+num2str(s.fixedEnergy)
	Note w, "fixedTheta="+num2str(s.fixedTheta)
	Note w, "fixedTilt="+num2str(s.fixedTilt)
	Note w, "fixedHv="+num2str(s.fixedHv)
	Note w, "invertDetectorScale="+num2str(s.invertDetectorScale)
	Note w, "workFunction="+num2str(s.workFunction)
	Note w, "innerPotential="+num2str(s.innerPotential)
	Note w, "useInterpolation="+num2str(s.useInterpolation)
	Note w, "includePhotonMomentum="+num2str(s.includePhotonMomentum)
	Note w, "beamTheta="+num2str(s.beamTheta)
	Note w, "beamTilt="+num2str(s.beamTilt)
	Note w, "destination="+s.destination
	
	return w
End

// ***********************************************************************
// * MomentumUnitsStr() :	Returns the OS-dependent string	*
// *						for units of inverse Angstroms.	*
// *						This will inherently be imperfect:	*
// *						currently assumes that standard	*
// *						'default' font is used.			* 
// *													*
// * 22.06.2016 :	First coding.							*
// ***********************************************************************
Static Function/S MomentumUnitsStr([superscript])
	Variable superscript	// Optional.  0: 1/A; 1 (default): A^-1
	
	if(ParamIsDefault(superscript))
		superscript = 1	// use superscript by default
	endif
	
	String kUnits
	String platform = lowerstr(IgorInfo(2))
	strswitch(platform)
		case "windows":
			if(superscript)
				kUnits = "\""+num2char(197)+"\\S-1\\M\""
			else
				kUnits = "1/"+num2char(197)
			endif
			break
		case "macintosh":
			if(superscript)
				kUnits = "\""+num2char(129)+"\\S-1\\M\""
			else
				kUnits = "1/"+num2char(129)
			endif
			break
	endswitch
	
	return kUnits
End

// ***********************************************************************
// * OutputDimSize() :	Returns the size of the output along 	*
// *					the specified dimension. The default,	*
// *					if no azimuthal rotation is applied, is	*
// *					to use the sizes of theta, tilt, hv for kx,	*
// *					ky, kz, respectively. If rotation is 		*
// * 					applied, the routine will try to preserve	*
// *					the number of points along the edge	*
// *					of the rotated image. These standard	*
// *					behaviors can be overridden by use	*
// *					of the "outputSize" field in the 		*
// *					kTransformSettings structure.		*
// *													*
// * 22.06.2016 :	Approaching satisfactory state.			*
// ***********************************************************************
Static Function OutputDimSize(s, dim)
	STRUCT kTransformSettings &s
	Variable dim	// dimension index (0 - 4)
	
	Variable size
	Variable phi = s.rotateAzimuth * pi/180

	if(WaveExists(s.outputSize))
		size = s.outputSize[dim]
	else
		if(s.thetaDim == dim)
			size = abs(DimSize(s.rawData, dim)*cos(phi))
			size += abs(s.tiltDim >= 0 ? DimSize(s.rawData, s.tiltDim) : 0)*sin(phi)
			size = round(size)
		elseif(s.tiltDim == dim)
			size = abs(DimSize(s.rawData, dim)*cos(phi))
			size += abs((s.thetaDim >= 0 ? DimSize(s.rawData, s.thetaDim) : 0)*sin(phi) )
			size = round(size)
		else
			size = DimSize(s.rawData, dim)
		endif
	endif
	
	return size
End

Static Function EnergyEndpnt(s, pnt)
	STRUCT kTransformSettings &s
	Variable pnt	// either 0 (start) or 1 (end)
	
	Variable endpnt
	
	if(s.energyDim >= 0)
		if(pnt == 0)
			endpnt = DimOffset(s.rawData, s.energyDim)
		elseif(pnt == 1)
			endpnt = DimOffset(s.rawData, s.energyDim) + (DimDelta(s.rawData, s.energyDim) * (DimSize(s.rawData, s.energyDim)-1))
		else
			return NaN
		endif
	else
		endpnt = s.fixedEnergy
	endif
	
	return endpnt
End

Static Function thetaEndpnt(s, pnt)
	STRUCT kTransformSettings &s
	Variable pnt	// either 0 (start) or 1 (end)
	
	Variable endpnt
	
	if(s.thetaDim >= 0)
		if(pnt == 0)
			endpnt = DimOffset(s.rawData, s.thetaDim)
		elseif(pnt == 1)
			endpnt = DimOffset(s.rawData, s.thetaDim) + (DimDelta(s.rawData, s.thetaDim) * (DimSize(s.rawData, s.thetaDim)-1))
		else
			return NaN
		endif
	else
		endpnt = s.fixedTheta
	endif
	
	return endpnt
End

Static Function tiltEndpnt(s, pnt)
	STRUCT kTransformSettings &s
	Variable pnt	// either 0 (start) or 1 (end)
	
	Variable endpnt
	
	if(s.tiltDim >= 0)
		if(pnt == 0)
			endpnt = DimOffset(s.rawData, s.tiltDim)
		elseif(pnt == 1)
			endpnt = DimOffset(s.rawData, s.tiltDim) + (DimDelta(s.rawData, s.tiltDim) * (DimSize(s.rawData, s.tiltDim)-1))
		else
			return NaN
		endif
	else
		endpnt = s.fixedTilt
	endif
	
	return endpnt
End

Static Function hvEndpnt(s, pnt)
	STRUCT kTransformSettings &s
	Variable pnt	// either 0 (start) or 1 (end)
	
	Variable endpnt
	
	if(s.hvDim >= 0)
		if(pnt == 0)
			endpnt = DimOffset(s.rawData, s.hvDim)
		elseif(pnt == 1)
			endpnt = DimOffset(s.rawData, s.hvDim) + (DimDelta(s.rawData, s.hvDim) * (DimSize(s.rawData, s.hvDim)-1))
		else
			return NaN
		endif
	else
		endpnt = s.fixedHv
	endif
	
	return endpnt
End

Static Function tiltDimSize(s)
	STRUCT kTransformSettings &s
	
	Variable size
	
	if(s.tiltDim >= 0)
		size = DimSize(s.rawData, s.tiltDim)
	else
		size = 0
	endif
	
	return size
End

Static Function kxEndpnt(s, pnt)
	STRUCT kTransformSettings &s
	Variable pnt	// either 0 (start) or 1 (end)
	
	Variable kxPnt
	Variable thisTheta = thetaEndpnt(s, pnt)
	Variable otherTheta = thetaEndpnt(s, !pnt)
	Variable energy0 = energyEndpnt(s, 0)
	Variable energy1 = energyEndpnt(s, 1)
	Variable hv0 = hvEndpnt(s, 0)
	Variable hv1 = hvEndpnt(s, 1)

	// test various strategic points for the kx extrema
	Make/FREE/N=4 test
	test[0] = kx(energy0, thisTheta, hv0, s.workFunction)
	test[1] = kx(energy0, thisTheta, hv0, s.workFunction)
	test[2] = kx(energy0, thisTheta, hv1, s.workFunction)
	test[3] = kx(energy1, thisTheta, hv1, s.workFunction)
	
	// determine the corresponding kx endpoint
	if(s.thetaDim >= 0)
		kxPnt = thisTheta < otherTheta ? wavemin(test) : wavemax(test)	// Theta range. Keep the same +/- endpoint ordering as the theta axis of the raw data.
	else
		kxPnt = pnt ? wavemin(test) : wavemax(test)	// Single theta point. Return either the low or high kx value, depending on whether pnt = 0 or 1.
	endif
	
	return kxPnt
End

Static Function kyEndpnt(s, pnt)
	STRUCT kTransformSettings &s
	Variable pnt	// either 0 (start) or 1 (end)
	
	Variable kyPnt
	Variable thisTilt = tiltEndpnt(s, pnt)
	Variable otherTilt = tiltEndpnt(s, !pnt)
	Variable theta0 = thetaEndpnt(s, 0)
	Variable theta1 = thetaEndpnt(s, 1)
	Variable energy0 = energyEndpnt(s, 0)
	Variable energy1 = energyEndpnt(s, 1)
	Variable hv0 = hvEndpnt(s, 0)
	Variable hv1 = hvEndpnt(s, 1)
	
	// test various strategic points for the ky extrema
	if((sign(theta0) != sign(theta1)) && (s.thetaDim >= 0))	// Theta range passes through zero. Extrema can occur here.
		Make/FREE/N=12 test
		test[0] = ky(energy0, theta0, thisTilt, hv0, s.workFunction)
		test[1] = ky(energy1, theta0, thisTilt, hv0, s.workFunction)
		test[2] = ky(energy0, theta1, thisTilt, hv0, s.workFunction)
		test[3] = ky(energy1, theta1, thisTilt, hv0, s.workFunction)
		test[4] = ky(energy0, theta0, thisTilt, hv1, s.workFunction)
		test[5] = ky(energy1, theta0, thisTilt, hv1, s.workFunction)
		test[6] = ky(energy0, theta1, thisTilt, hv1, s.workFunction)
		test[7] = ky(energy1, theta1, thisTilt, hv1, s.workFunction)
		test[8] = ky(energy0, 0, thisTilt, hv0, s.workFunction)
		test[9] = ky(energy1, 0, thisTilt, hv0, s.workFunction)
		test[10] = ky(energy0, 0, thisTilt, hv1, s.workFunction)
		test[11] = ky(energy1, 0, thisTilt, hv1, s.workFunction)
	else												// Theta is signle-valued or doesn't pass through zero. Extrema will occur on one of the theta endpoints.
		Make/FREE/N=8 test
		test[0] = ky(energy0, theta0, thisTilt, hv0, s.workFunction)
		test[1] = ky(energy1, theta0, thisTilt, hv0, s.workFunction)
		test[2] = ky(energy0, theta1, thisTilt, hv0, s.workFunction)
		test[3] = ky(energy1, theta1, thisTilt, hv0, s.workFunction)
		test[4] = ky(energy0, theta0, thisTilt, hv1, s.workFunction)
		test[5] = ky(energy1, theta0, thisTilt, hv1, s.workFunction)
		test[6] = ky(energy0, theta1, thisTilt, hv1, s.workFunction)
		test[7] = ky(energy1, theta1, thisTilt, hv1, s.workFunction)
	endif
	
	// determine the corresponding ky endpoint
	if(s.tiltDim >= 0)
		kyPnt = thisTilt < otherTilt ? wavemin(test) : wavemax(test)	// Tilt range. Keep the same +/- endpoint ordering as the tilt axis of the raw data.
	else
		kyPnt = pnt ? wavemin(test) : wavemax(test)	// Single tilt point. Return either the low or high ky value, depending on whether pnt = 0 or 1.
	endif
	
	return kyPnt
End

Static Function kzEndpnt(s, pnt)
	STRUCT kTransformSettings &s
	Variable pnt	// either 0 (start) or 1 (end)
	
	Variable kzPnt
	Variable thisHv = hvEndpnt(s, pnt)
	Variable otherHv = hvEndpnt(s, !pnt)
	Variable energy0 = energyEndpnt(s, 0)
	Variable energy1 = energyEndpnt(s, 1)
	Variable theta0 = thetaEndpnt(s, 0)
	Variable theta1 = thetaEndpnt(s, 1)
	Variable tilt0 = tiltEndpnt(s, 0)
	Variable tilt1 = tiltEndpnt(s, 1)
	
	// test various strategic points for the kz extrema
	if((sign(theta0) != sign(theta1)) && (s.thetaDim >= 0))	// Theta range passes through zero. Extrema can occur here.
		Make/FREE/N=12 test
		test[0] = kz(energy0, theta0, tilt0, thisHv, s.workFunction, s.innerPotential)
		test[1] = kz(energy1, theta0, tilt0, thisHv, s.workFunction, s.innerPotential)
		test[2] = kz(energy0, theta1, tilt0, thisHv, s.workFunction, s.innerPotential)
		test[3] = kz(energy1, theta1, tilt0, thisHv, s.workFunction, s.innerPotential)
		test[4] = kz(energy0, theta0, tilt1, thisHv, s.workFunction, s.innerPotential)
		test[5] = kz(energy1, theta0, tilt1, thisHv, s.workFunction, s.innerPotential)
		test[6] = kz(energy0, theta1, tilt1, thisHv, s.workFunction, s.innerPotential)
		test[7] = kz(energy1, theta1, tilt1, thisHv, s.workFunction, s.innerPotential)
		test[8] = kz(energy0, 0, tilt0, thisHv, s.workFunction, s.innerPotential)
		test[9] = kz(energy1, 0, tilt0, thisHv, s.workFunction, s.innerPotential)
		test[10] = kz(energy0, 0, tilt1, thisHv, s.workFunction, s.innerPotential)
		test[11] = kz(energy1, 0, tilt1, thisHv, s.workFunction, s.innerPotential)
	else												// Theta is signle-valued or doesn't pass through zero. Extrema will occur on one of the theta endpoints.
		Make/FREE/N=8 test
		test[0] = kz(energy0, theta0, tilt0, thisHv, s.workFunction, s.innerPotential)
		test[1] = kz(energy1, theta0, tilt0, thisHv, s.workFunction, s.innerPotential)
		test[2] = kz(energy0, theta1, tilt0, thisHv, s.workFunction, s.innerPotential)
		test[3] = kz(energy1, theta1, tilt0, thisHv, s.workFunction, s.innerPotential)
		test[4] = kz(energy0, theta0, tilt1, thisHv, s.workFunction, s.innerPotential)
		test[5] = kz(energy1, theta0, tilt1, thisHv, s.workFunction, s.innerPotential)
		test[6] = kz(energy0, theta1, tilt1, thisHv, s.workFunction, s.innerPotential)
		test[7] = kz(energy1, theta1, tilt1, thisHv, s.workFunction, s.innerPotential)
	endif
	
	// determine the corresponding kz endpoint
	if(s.hvDim >= 0)
		kzPnt = thisHv < otherHv ? wavemin(test) : wavemax(test)	// hv range. Keep the same +/- endpoint ordering as the hv axis of the raw data.
	else
		kzPnt = pnt ? wavemin(test) : wavemax(test)	// Single hv point. Return either the low or high kz value, depending on whether pnt = 0 or 1.
	endif
	
	return kzPnt
End

// ***********************************************************************
// * Transform() :	Performs a transform from angle to k-		*
// *				space. Acts on a suitably prepared empty 	*
// *				wave, such as created by Init(). The name	*
// *				of this wave needs to be specified in the	*
// *				"destination" field of the 				*
// *				kTransformSettings structure. Returns a 	*
// *				reference to this transformed output wave.	*
// *													*
// * 22.06.2016 :	Approaching first satisfactory state.		*
// ***********************************************************************
Static Function/WAVE Transform(s)
	STRUCT kTransformSettings &s
	
	WAVE w = $s.destination
	
	// Build the command string for the k-space transformation...
	String cmd, str0, str1, str2, str3 = ""
	
	// Begin by laying out the "skeleton" of commands. Values that will need to be
	// computed are indicated by flags such as <energy>, <theta>, etc. These
	// will be replaced in subsequent steps.
	//
	// Ultimately, you are building some command resembling something 
	// like the following (in the case of a typical tilt scan):
	// kSpaceWave = rawData(x)(k#theta(x,y,z,<hv>,<workFnc>,<azi>)(k#tilt(x,y,z,<hv>,<workFnc>,<azi>))
	
	// Skeleton for indexing the rows ("x" axis). Often this is energy.
	if(WaveDims(w) >= 1)
		if(s.thetaDim == 0)
			str0 = "(k#theta(<energy>,x,<ky>,<hv>,"+ num2str(s.workFunction) + "," + num2str(s.rotateAzimuth) +"))"
		elseif(s.tiltDim == 0)
			str0 = "(k#tilt(<energy>,<kx>,x,<hv>," + num2str(s.workFunction) + "," + num2str(s.rotateAzimuth) + "))"
		elseif(s.hvDim == 0)
			str0 = "(k#hv(<energy>,<theta>,<tilt>,x,"+ num2str(s.workFunction) + ","+ num2str(s.innerPotential) + "," + num2str(s.rotateAzimuth) + "))"
		else
			str0 = "(x)"
		endif
	else
		str0 = ""
	endif
	
	// Skeleton for indexing the columns ("y" axis). Often this is kx.
	if(WaveDims(w) >= 2)
		if(s.thetaDim == 1)
			str1 = "(k#theta(<energy>,y,<ky>,<hv>,"+ num2str(s.workFunction) + "," + num2str(s.rotateAzimuth) +"))"
		elseif(s.tiltDim == 1)
			str1 = "(k#tilt(<energy>,<kx>,y,<hv>," + num2str(s.workFunction) + "," + num2str(s.rotateAzimuth) + "))"
		elseif(s.hvDim == 1)
			str1 = "(k#hv(<energy>,<kx>,<ky>, y,"+ num2str(s.workFunction) + ","+ num2str(s.innerPotential) + "," + num2str(s.rotateAzimuth) + "))"
		else
			str1 = "(y)"
		endif
	else
		str1 = ""
	endif
	
	// Skeleton for indexing the layers ("z" axis).
	if(WaveDims(w) >= 3)
		if(s.thetaDim == 2)
			str2 = "(k#theta(<energy>,z,<ky>,<hv>,"+ num2str(s.workFunction) + "," + num2str(s.rotateAzimuth) +"))"
		elseif(s.tiltDim == 2)
			str2 = "(k#tilt(<energy>,<kx>,z,<hv>," + num2str(s.workFunction) + "," + num2str(s.rotateAzimuth) + "))"
		elseif(s.hvDim == 2)
			str2 = "(k#hv(<energy>,<kx>,<ky>,z,"+ num2str(s.workFunction) + ","+ num2str(s.innerPotential) + "," + num2str(s.rotateAzimuth) + "))"
		else
			str2 = "(z)"
		endif
	else
		str2 = ""
	endif
	
	// Skeleton for indexing the chunks ("t" axis).
	if(WaveDims(w) == 4)
		if(s.thetaDim == 3)
			str3 = "(k#theta(<energy>,t,<ky>,<hv>, "+ num2str(s.workFunction) + "," + num2str(s.rotateAzimuth) +"))"
		elseif(s.tiltDim == 3)
			str3 = "(k#tilt(<energy>,<kx>,t,<hv>," + num2str(s.workFunction) + "," + num2str(s.rotateAzimuth) + "))"
		elseif(s.hvDim == 3)
			str3 = "(k#hv(<energy>,<kx>,<ky>,t,"+ num2str(s.workFunction) + ","+ num2str(s.innerPotential) + "," + num2str(s.rotateAzimuth) + "))"
		else
			str3 = "(t)"
		endif
	else
		str3 = ""
	endif
	
	// Assemble the skeleton. Format depends on whether interpolation is specified.
	if(s.useInterpolation)
		if(WaveDims(w) == 2)
			cmd = GetWavesDataFolder(w, 2) + " = Interp2D(" + GetWavesDataFolder(s.rawData, 2) + "," + str0 + "," + str1 + ")"	// 2D interpolation
		elseif(WaveDims(w) == 3)
			cmd = GetWavesDataFolder(w, 2) + " = Interp3D(" + GetWavesDataFolder(s.rawData, 2) + "," + str0 + "," + str1 + "," + str2 + ")"	// 3D interpolation
		elseif(WaveDims(w) == 4)
			Variable stop
			Prompt stop, "4D interpolation is not supported. Proceed without interpolation or quit?", popup, "Proceed;Quit;"
			DoPrompt "k-space transformation", stop		// 4D not yet supported. Prompt user.
			if(stop)
				return w
			else
				cmd = GetWavesDataFolder(w, 2) + " = " + GetWavesDataFolder(s.rawData, 2) + str0 + str1 + str2 + str3		// non-interpolated.
			endif
		endif
	else
		cmd = GetWavesDataFolder(w, 2) + " = " + GetWavesDataFolder(s.rawData, 2) + str0 + str1 + str2 + str3		// non-interpolated.
	endif	
	
	// Igor names for accessing the various dimensions
	String dimList = "x;y;z;t"	
	
	// Now substitute in the last values/commands. These must be substituted in
	// order of tilt-theta-hv, due to the way they build on each other.
	
	// Replace any occurence of <tilt> with either a command or a single value
	if(s.tiltDim >= 0)
		cmd = ReplaceString("<tilt>", cmd, "k#tilt(<energy>,<kx>,<ky>,<hv>,"+num2str(s.workFunction)+","+num2str(s.rotateAzimuth)+")")
	else
		cmd = ReplaceString("<tilt>", cmd, num2str(s.fixedTilt))
	endif	
	
	// Replace any occurence of <theta> with either a command or a single value
	if(s.thetaDim >= 0)
		cmd = ReplaceString("<theta>", cmd, "k#theta(<energy>,<kx>,<ky>,<hv>,"+num2str(s.workFunction)+","+num2str(s.rotateAzimuth)+")")
	else
		cmd = ReplaceString("<theta>", cmd, num2str(s.fixedTheta))
	endif
	
	// Replace any occurence of <hv> with either a command or a single value
	if(s.hvDim >= 0)
		cmd = ReplaceString("<hv>", cmd, "k#hv(<energy>,<kx>,<ky>,<kz>,"+num2str(s.workFunction)+","+num2str(s.innerPotential)+ "," + num2str(s.rotateAzimuth)+")")
	else
		cmd = ReplaceString("<hv>", cmd, num2str(s.fixedHv))
	endif
	
	// Replace any occurence of <energy> with either a command or a single value
	if(s.energyDim >= 0)
		cmd = ReplaceString("<energy>", cmd, StringFromList(s.energyDim, dimList))
	else
		cmd = ReplaceString("<energy>", cmd, num2str(s.fixedEnergy))
	endif	
	
	// All that should be left now are flags <kx>, <ky> and <kz>.
	// Replace any occurence of these with either the appropriate name from dimList
	// (i.e., "x", "y", "z" or "t") or a single value, depending on whether it is one of the
	// data dimensions.
	if(s.thetaDim >= 0)
		cmd = ReplaceString("<kx>", cmd, StringFromList(s.thetaDim, dimList))
	else
		cmd = ReplaceString("<kx>", cmd, num2str((kxEndpnt(s,0)+kxEndpnt(s,1))/2))
	endif
	
	if(s.tiltDim >= 0)
		cmd = ReplaceString("<ky>", cmd, StringFromList(s.tiltDim, dimList))
	else
		cmd = ReplaceString("<ky>", cmd, num2str((kyEndpnt(s,0)+kyEndpnt(s,1))/2))
	endif
	
	if(s.hvDim >= 0)
		cmd = ReplaceString("<kz>", cmd, StringFromList(s.hvDim, dimList))
	else
		cmd = ReplaceString("<kz>", cmd, num2str((kzEndpnt(s,0)+kzEndpnt(s,1))/2))
	endif
	
	print cmd		// debugging
	
	// Do it.
	Execute/Q cmd
	
	return w
End


// *** Functions for converting (angles, hv) to momentum ***

ThreadSafe Static Function kx(energy, theta, hv, workFnc)		// k parallel to theta in units of 1/Angstroms
	Variable energy		// binding energy = E - EF in eV
	Variable theta			// angle in degrees
	Variable hv			// photon energy in eV
	Variable workFnc		// work function in eV (> 0)

	theta *= pi/180	// radians
	
	return (sqrt(2 * m * (energy + hv - workFnc)) / hbar) * sin(theta)
End

ThreadSafe Static Function ky(energy, theta, tilt, hv, workFnc)		// k parallel to tilt in units of 1/Angstroms
	Variable energy		// binding energy = E - EF in eV
	Variable theta, tilt		// angles in degrees
	Variable hv			// photon energy in eV
	Variable workFnc		// work function in eV (> 0)
	
	theta *= pi/180	// radians
	tilt *= pi/180		// radians
	
	return (sqrt(2 * m * (energy + hv - workFnc)) / hbar) * cos(theta) * sin(tilt)
End

ThreadSafe Static Function kz(energy, theta, tilt, hv, workFnc, V0)	// k perpendicular to the sample surface in units of 1/Angstroms
	Variable energy		// binding energy = E - EF in eV
	Variable theta, tilt		// angles in degrees
	Variable hv			// photon energy in eV
	Variable workFnc		// work function in eV (> 0)
	Variable V0			// inner potential in eV (defined as |E0| + workFnc, see Damascelli review)
	
	Variable result 
	result = (2 * m * (energy + hv - workFnc + V0)) / (hbar^2)
	result -= kx(energy, theta, hv, workFnc)^2
	result -= ky(energy, theta, tilt, hv, workFnc)^2
	result = sqrt(result)

	return result
End


// *** Functions for converting momenta to (angles, hv) ***

ThreadSafe Static Function theta(energy, kx, ky, hv, workFnc, phi)	// kx ===> theta rotation in degrees 
	Variable energy		// binding energy = E-E_F in eV
	Variable kx, ky		// momenta
	Variable hv			// photon energy in eV
	Variable workFnc		// work function in eV (> 0)
	Variable phi			// *software* azimuthal rotation in degrees

	// Account for azimuthal rotation. Basically this counter-rotates the k point back to its position in the input data.
	phi *= pi/180	// radians
	Variable kxr = kx*cos(phi) + ky*sin(phi)

	Variable result
	result = asin(kxr * hbar / sqrt(2 * m * (energy + hv - workFnc)))
	result *= 180/pi	// degrees
	
	return result
End

ThreadSafe Static Function tilt(energy, kx, ky, hv, workFnc, phi)	// kx, ky ===> tilt rotation in degrees
	Variable energy		// binding energy = E-E_F in eV
	Variable kx, ky		// momenta
	Variable hv			// photon energy in eV
	Variable workFnc		// work function in eV (> 0)
	Variable phi			// *software* azimuthal rotation in degrees
	
	// Get the theta angle based on the momentum...
	Variable th = theta(energy, kx, ky, hv, workFnc, phi)
	th *= pi/180	// radians
	
	// Account for azimuthal rotation. Basically this counter-rotates the k point back to its position in the input data.
	phi *= pi/180	// radians
	Variable kyr = ky*cos(phi) - kx*sin(phi)

	Variable result
	result = asin(kyr * hbar / (cos(th) * sqrt(2 * m * (energy + hv - workFnc))))
	result *= 180/pi	// degrees
	
	return result
End

ThreadSafe Static Function hv(energy, kx, ky, kz, workFnc, V0, phi)	// k in 1/Angstroms ===> hv in eV
	Variable energy		// binding energy = E-E_F in eV
	Variable kx, ky, kz		// momenta
	Variable workFnc		// work function in eV (> 0)
	Variable V0			// inner potential in eV (> 0)
	Variable phi			// *software* azimuthal rotation in degrees
	
	// Account for azimuthal rotation. Basically this counter-rotates the k point back to its position in the input data.
	phi *= pi/180	// radians
	Variable kxr = cos(phi)*kx + sin(phi)*ky
	Variable kyr = -sin(phi)*kx + cos(phi)*ky
	
	Variable result
	result = (hbar^2)*((kxr^2)+(kyr^2)+(kz^2)) / (2*m)
	result += -energy + workFnc - V0
	
	return result
End

