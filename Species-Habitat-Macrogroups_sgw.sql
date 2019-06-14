USE GapVert_48_2001;
GO
-- Overall, edits reduced records from 19337 to 17090
WITH
/* 
Changed NonAncillary WHERE statement to tblModelInfo.ysnIncludeSubModel = 1 (dropped 1450 to 1078 records)
Included strSalinity = 'All Types' (added 4 records - 1082)
Included strStreamVel = 'All Types' (no change)
Removed FlowAcc variables since they were not implemented on any model (no change)
Removed intEdgeEcoWidth since it's controlled by strEdgeType (added 5 records - 1087)
Removed strForIntBuffer since it's controlled by strUseForInt (no change)
Removed Patch variables except chxContPatch and chxNonCPatch (added 2 records - 1089)
Added intElevMin < 1 (added 4 records - 1093)
*/
NonAncillary AS (
	SELECT	SUBSTRING(a.strSpeciesModelCode, 1, 6) AS uc,
			a.strSpeciesModelCode,
			ysnHydroFW,
			ysnHydroOW,
			ysnHydroWV,
			ysnHydroSprings,
			strSalinity,
			strStreamVel,
			strEdgeType,
			strUseForInt,
			cbxContPatch,
			cbxNonCPatch,
			intPercentCanopy,
			intAuxBuff,
			strAvoid,
			ysnUrbanExclude,
			ysnUrbanInclude,
			intElevMin,
			intElevMax,
			intSlopeMin,
			intSlopeMax
	FROM tblModelAncillary a INNER JOIN tblModelInfo i
		  ON a.strSpeciesModelCode = i.strSpeciesModelCode
	WHERE	i.ysnIncludeSubModel = 1 AND
			ysnHydroFW = 0 AND 
			ysnHydroOW = 0 AND 
			ysnHydroWV = 0 AND 
			ysnHydroSprings = 0 AND 
			(strSalinity Is Null OR strSalinity = 'All Types') AND 
			(strStreamVel Is Null OR strStreamVel = 'All Types') AND 
			strEdgeType Is Null AND 
			strUseForInt Is Null AND 
			cbxContPatch = 0 AND 
			cbxNonCPatch = 0 AND 
			intPercentCanopy Is Null AND 
			intAuxBuff Is Null AND 
			strAvoid Is Null AND 
			ysnUrbanExclude = 0 AND 
			ysnUrbanInclude = 0 AND 
			(intElevMin Is Null OR intElevMin < 1) AND 
			intElevMax Is Null AND 
			intSlopeMin Is Null AND 
			intSlopeMax Is Null
),
/*
Added tblModelInfo.ysnIncludeSubModel = 1 filter (reduced records from 97308 to 90128)
*/
ForestSelected AS (
	SELECT 
		d.intLSGapMapCode, 
		d.strLSGapName, 
		d.intForest,
		p.strSpeciesModelCode, 
		p.ysnPres
	FROM
		tblMapUnitDesc d INNER JOIN 
		 tblSppMapUnitPres p ON
		  d.intLSGapMapCode = p.intLSGapMapCode INNER JOIN
		 tblModelInfo i ON
		  p.strSpeciesModelCode = i.strSpeciesModelCode
	WHERE
		i.ysnIncludeSubModel = 1 AND
		d.intForest = 1 AND
		p.ysnPres = 1
),
-- added tblTaxa.ysnIncludeSpp = 1 filter (reduced records from 1948 to 1719)
Taxa AS (
	SELECT 
		strUC,
		strSciName,
		strComName
	FROM
		tblTaxa
	WHERE ysnIncludeSpp = 1
)

SELECT 
	t.strSciName AS ScientificName,
	t.strComName AS CommonName,
	t.strUC AS SC,
	a.strSpeciesModelCode AS SMC,
	f.intLSGapMapCode AS MUCode,
	f.strLSGapName AS MUName,
	CASE 
		WHEN 
			SUBSTRING(a.strSpeciesModelCode, 8, 1)='y'
			THEN 'year-round'
		WHEN
			SUBSTRING(a.strSpeciesModelCode, 8, 1)='s'
			THEN 'summer'
		WHEN
			SUBSTRING(a.strSpeciesModelCode, 8, 1)='w'
			THEN 'winter'
	END AS Season,		
	CASE 
		WHEN 
			SUBSTRING(a.strSpeciesModelCode, 9, 1)='1'
			THEN 'Northwest'
		WHEN
			SUBSTRING(a.strSpeciesModelCode, 9, 1)='2'
			THEN 'Upper Midwest'
		WHEN
			SUBSTRING(a.strSpeciesModelCode, 9, 1)='3'
			THEN 'Northeast'
		WHEN
			SUBSTRING(a.strSpeciesModelCode, 9, 1)='4'
			THEN 'Southwest'
		WHEN
			SUBSTRING(a.strSpeciesModelCode, 9, 1)='5'
			THEN 'Great Plains'
		WHEN
			SUBSTRING(a.strSpeciesModelCode, 9, 1)='6'
			THEN 'Southeast'
	END AS Region
FROM
	NonAncillary a INNER JOIN ForestSelected f
	ON a.strSpeciesModelCode = f.strSpeciesModelCode
	INNER JOIN Taxa t ON a.uc = t.strUC
