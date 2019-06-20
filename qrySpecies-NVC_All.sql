/*
	This is an attempt at quantifying the expected increase in cell counts for 
	a species' habitat map given a generalization of map unit selections to
	the corresponding NVC Macrogroup. Map units (NVC ecosystems) are lumped into
	121 macrogroups thereby adding commission error if included as species habitat
	without regard to the finer thematic scale of map unit.

	This query uses both the GAP Analytic db and the GAP Vert db to combine data
	on species habitat map selections from the Vert db with 'spatial' correlates
	of cell counts in the Analytic db. The later identifies geography using unique
	ids of 'boundaries' which are intersections of various data layers such as
	LCCs, ecoregions, counties, HUCs, etc. Separate tables contain data on boundary
	cell counts for each species (in the table lu_boundary_species) and for NVC
	categories (in the table lu_boundary_gap_landfire).

*/
-- declare variables
declare @numRows int,  @strUC varchar(6)

-- drop the temp tables if they exist
IF OBJECT_ID('tempdb.dbo.#sppNoAnc', 'U') IS NOT NULL 
  DROP TABLE #sppNoAnc; 
IF OBJECT_ID('tempdb.dbo.#sppMUMG', 'U') IS NOT NULL 
  DROP TABLE #sppMUMG; 


-- create empty temp table for sppHuc; if present - empty, if absent - create
IF OBJECT_ID('#tempdb.dbo.sppHuc', 'U') IS NOT NULL 
  DELETE FROM #sppHuc; 
ELSE
  CREATE TABLE #sppHuc (strUC varchar(6), strHUC12RNG varchar(12));

WITH
-- Build table of species seasonal/regional use of ancillary data
smAnc AS (
	SELECT	i.strUC AS strUC
		  ,	a.strSpeciesModelCode AS strSpeciesModelCode
		  , CAST(ysnHandModel AS int) AS intHandModel
		  , CAST(ysnHydroFW AS int) AS intHydroFW
		  , CAST(ysnHydroOW AS int) AS intHydroOW
		  , CAST(ysnHydroWV AS int) AS intHydroWV
		  , CASE
				WHEN (strSalinity Is Null OR strSalinity = 'All Types') THEN 0
				ELSE 1
			END AS intSalinity
		  , CASE
				WHEN (strStreamVel Is Null OR strStreamVel = 'All Types') THEN 0
				ELSE 1
			END AS intStreamVel
		  , CASE
				WHEN strEdgeType Is Null THEN 0
				ELSE 1
			END AS intEdgeType
		  , CASE
				WHEN strUseForInt Is Null THEN 0
				ELSE 1
			END AS intUseForInt
		  , CAST(cbxContPatch AS int) AS intContPatch
		  ,	CAST(cbxNonCPatch AS int) AS intNonCPatch
		  , CASE
				WHEN intPercentCanopy Is Null THEN 0
				ELSE 1
			END AS intPercentCanopy 
		  , CASE
				WHEN intAuxBuff Is Null THEN 0
				ELSE 1
			END AS intAuxBuff
		  , CASE
				WHEN strAvoid Is Null THEN 0
				ELSE 1
			END AS intAvoid
		  ,	CAST(ysnUrbanExclude AS int) AS intUrbanExclude
		  ,	CAST(ysnUrbanInclude AS int) AS intUrbanInclude
		  , CASE
				WHEN (intElevMin Is Null OR intElevMin < 1) THEN 0
				ELSE 1
			END AS intElevMin
		  , CASE
				WHEN intElevMax Is Null THEN 0
				ELSE 1
			END AS intElevMax
	FROM GapVert_48_2001.dbo.tblModelAncillary a 
		 INNER JOIN GapVert_48_2001.dbo.tblModelInfo i
			ON a.strSpeciesModelCode = i.strSpeciesModelCode
	WHERE	i.ysnIncludeSubModel = 1
	)
,

-- Identify species that have no ancillary data use in any seasonal/regional submodels
sppAnyAnc AS (
	SELECT
		strUC
	  ,	SUM ( intHandModel +
			  intHydroFW +
			  intHydroOW +
			  intHydroWV +
			  intSalinity +
			  intStreamVel +
			  intEdgeType +
			  intUseForInt +
			  intContPatch +
			  intNonCPatch +
			  intPercentCanopy +
			  intAuxBuff +
			  intAvoid +
			  intUrbanExclude +
			  intUrbanInclude +
			  intElevMin +
			  intElevMax ) AS anyAnc
	FROM smAnc
	GROUP BY strUC
	)

-- List of species with no ancillary data use anywhere (n = 295)
--  and utilize at least one forested map unit
SELECT DISTINCT
	sppAnyAnc.strUC
INTO #sppNoAnc
FROM sppAnyAnc 
		INNER JOIN GapVert_48_2001.dbo.tblModelInfo i
		ON sppAnyAnc.strUC = i.strUC
		INNER JOIN GapVert_48_2001.dbo.tblSppMapUnitPres p
		ON i.strSpeciesModelCode = p.strSpeciesModelCode
		INNER JOIN GapVert_48_2001.dbo.tblMapUnitDesc d
		ON p.intLSGapMapCode = d.intLSGapMapCode
WHERE anyAnc = 0 AND 
		d.intForest = 1;

-- Get MapUnits and MacroGroups associated with species from the GapVert_48_2001 dB
--	NOTE: This only uses primary map unit presence as a criterion
SELECT DISTINCT
	t.strUC AS SppCode
  , t.strSciName AS SciName
  ,	t.strComName AS ComName
  ,	d.intLSGapMapCode AS MUCode
  ,	d.strLSGapName AS MUName
  ,	lf.macro_cd AS MGCode
  ,	lf.nvc_macro AS MGName
INTO #sppMUMG
FROM GapVert_48_2001.dbo.tblSppMapUnitPres p 
	 INNER JOIN GapVert_48_2001.dbo.tblTaxa t
		ON SUBSTRING(p.strSpeciesModelCode, 1, 6) = t.strUC
	 INNER JOIN GapVert_48_2001.dbo.tblMapUnitDesc d
		ON p.intLSGapMapCode = d.intLSGapMapCode
	 INNER JOIN #sppNoAnc
		ON t.strUC = #sppNoAnc.strUC
	 INNER JOIN GAP_AnalyticDB.dbo.gap_landfire lf
		ON d.intLSGapMapCode = lf.level3
WHERE
	p.ysnPres = 1

-- Get list of Hucs that contain species habitat from GAP_AnalyticDB 
---------------------------------------------------------------------
-- Set up loop on sppNoAnc to run query by species (takes 1hr 25min to complete)
-- start with lowest value
SELECT @strUC = MIN(strUC) FROM #sppNoAnc
print 'initial spp record: ' + @strUC

-- get number of records
SELECT @numRows = COUNT(*) FROM #sppNoAnc
print 'number of records: ' + CAST(@numRows AS nvarchar)

-- loop until no more records
WHILE @numRows > 0
BEGIN
	-- work on selected record
	print 'Row: ' + CAST(@numRows AS nvarchar) + ', spp: ' + @strUC;
	
	WITH sppHucRng AS (
		SELECT DISTINCT
			(LEFT(bs.species_cd,1) + UPPER(SUBSTRING(bs.species_cd,2,4)) + RIGHT(bs.species_cd,1)) AS strUC
		  , h.huc12rng AS strHUC12RNG
		FROM GAP_AnalyticDB.dbo.lu_boundary_species bs
		INNER JOIN GAP_AnalyticDB.dbo.lu_boundary b
			ON bs.boundary = b.value
		INNER JOIN GAP_AnalyticDB.dbo.hucs h
			ON b.hucs = h.objectid
		WHERE (LEFT(bs.species_cd,1) + UPPER(SUBSTRING(bs.species_cd,2,4)) + RIGHT(bs.species_cd,1)) = @strUC)

	 INSERT INTO #sppHuc
	 SELECT * FROM sppHucRng

	-- get the next record
	SELECT TOP 1 @strUC = strUC FROM #sppNoAnc WHERE strUC > @strUC ORDER BY strUC ASC
	-- decrease row count
	set @numRows = @numRows - 1 
END;
---------------------------------------------------------------------

WITH
-- Get distinct list of MacroGroups per species
sppMG AS (
	SELECT DISTINCT
		SppCode
	  , MGCode
	  , MGName
	FROM #sppMUMG
	)
,

-- Get MacroGroup cell count within species range
sppHabMG AS (
	SELECT 
		sppMG.SppCode
	  , lf.macro_cd AS MacroGroupCode
	  , lf.nvc_macro AS MacroGroupName
	  --, #sppHuc.strHUC12RNG
	  , SUM(lb.count) AS HabMG_Cnt
	  --, SUM(lb.count) * 0.00034749194269 AS HabMG_SqMile
	FROM GAP_AnalyticDB.dbo.gap_landfire lf
	INNER JOIN GAP_AnalyticDB.dbo.lu_boundary_gap_landfire lb
		ON lf.value = lb.gap_landfire
	INNER JOIN GAP_AnalyticDB.dbo.lu_boundary b
		ON lb.boundary = b.value
	INNER JOIN GAP_AnalyticDB.dbo.hucs h
		ON b.hucs = h.objectid
	INNER JOIN #sppHuc
		ON h.huc12rng = #sppHuc.strHUC12RNG
	INNER JOIN sppMG
		ON sppMG.MGName = lf.nvc_macro
	GROUP BY sppMG.SppCode
		   , lf.macro_cd
		   , lf.nvc_macro
		   --, #sppHuc.strHUC12RNG
	)
,

-- Get MapUnit cell count within species range and sum by MacroGroup
sppHabMU AS (
	SELECT 
		#sppMUMG.SppCode
	  --, MUCode AS MapUnitCode
	  --, MUName AS MapUnitName
	  , MGName
	  --, #sppHuc.strHUC12RNG
	  , SUM(lb.count) AS HabMU_Cnt
	  --, SUM(lb.count) * 0.00034749194269 AS HabMU_SqMile
	FROM GAP_AnalyticDB.dbo.gap_landfire lf
	INNER JOIN GAP_AnalyticDB.dbo.lu_boundary_gap_landfire lb
		ON lf.value = lb.gap_landfire
	INNER JOIN GAP_AnalyticDB.dbo.lu_boundary b
		ON lb.boundary = b.value
	INNER JOIN GAP_AnalyticDB.dbo.hucs h
		ON b.hucs = h.objectid
	INNER JOIN #sppHuc
		ON h.huc12rng = #sppHuc.strHUC12RNG
	INNER JOIN #sppMUMG
		ON #sppMUMG.MUName = lf.ecosys_lu
	GROUP BY #sppMUMG.SppCode
		   --, MUCode
		   --, MUName
		   , MGName
		   --, #sppHuc.strHUC12RNG
	)

-- Combine habitat count by MapUnit and MacroGroup
SELECT
	sppHabMG.SppCode
  , sppHabMG.MacroGroupCode
  , sppHabMG.MacroGroupName
  --, FORMAT(sppHabMU.HabMU_Cnt, 'N0') AS HabMU_Cnt
  --, FORMAT(sppHabMG.HabMG_Cnt, 'N0') AS HabMG_Cnt
  ,	FORMAT(sppHabMU.HabMU_Cnt * 0.00034749194269, 'N1') AS HabMU_SqMile
  ,	FORMAT(sppHabMG.HabMG_Cnt * 0.00034749194269, 'N1') AS HabMG_SqMile
  , FORMAT((CAST(sppHabMU.HabMU_Cnt AS float) / CAST(sppHabMG.HabMG_Cnt AS float)) * 100, 'N6') AS 'MUnit/MGroup Percent Ratio'
FROM sppHabMU 
	 INNER JOIN sppHabMG
		ON sppHabMU.SppCode = sppHabMG.sppCode AND
		   sppHabMU.MGName = sppHabMG.MacroGroupName
ORDER BY sppHabMG.SppCode, sppHabMG.MacroGroupCode
