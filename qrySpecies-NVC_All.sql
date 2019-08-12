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
	categories (in the table lu_boundary_gap_lcv1).

*/
-- declare variables
declare @numRows int, @strUC varchar(6)


-- drop the temp tables if they exist
IF OBJECT_ID('tempdb.dbo.#sppNoAnc', 'U') IS NOT NULL 
  DROP TABLE #sppNoAnc; 
IF OBJECT_ID('tempdb.dbo.#sppMUMG', 'U') IS NOT NULL 
  DROP TABLE #sppMUMG; 


/*
-- create empty temp table for sppHuc; if present - empty, if absent - create
IF OBJECT_ID('tempdb.dbo.#sppHuc', 'U') IS NOT NULL 
  DELETE FROM #sppHuc;
  --DROP TABLE #sppHuc; 
ELSE
  CREATE TABLE #sppHuc (strUC varchar(6), strHUC12RNG varchar(12), hab_Cnt bigint);
*/
-- temporarily create and maintain temp table for sppHuc in GAP_AnalyticDB (remove from final code)
-- this is for debugging purposes and code must be hand run to avoid errors
--CREATE TABLE GAP_AnalyticDB.dbo.tmp_sppHuc (strUC varchar(6), strHUC12RNG varchar(12), hab_Cnt bigint);
--DROP TABLE GAP_AnalyticDB.dbo.tmp_sppHuc

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

-- List of species with no ancillary data use anywhere (n = 211)
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
		p.ysnPres = 1 AND
		i.ysnIncludeSubModel = 1 AND
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
	 INNER JOIN GapVert_48_2001.dbo.tblModelInfo i
		ON p.strSpeciesModelCode = i.strSpeciesModelCode
WHERE
	p.ysnPres = 1 AND
	i.ysnIncludeSubModel = 1

-- Get list of Hucs that contain species range from GapVert_48_2001, 
--   then get cell count for that spp/huc combination from GAP_AnalyticDB 
---------------------------------------------------------------------
-- Set up loop on sppNoAnc to run query by species (takes 1hr 5min to complete)
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
		    r.strUC
		  , h.huc12rng AS strHUC12RNG
		  , ISNULL(CAST(SUM(bs.count) AS bigint), 0) AS 'hab_Cnt' 
		FROM GapVert_48_2001.dbo.tblRanges r
		INNER JOIN GAP_AnalyticDB.dbo.hucs h
			ON h.huc12rng = r.strHUC12RNG
		INNER JOIN GAP_AnalyticDB.dbo.lu_boundary b
			ON b.hucs = h.objectid
		INNER JOIN GAP_AnalyticDB.dbo.lu_boundary_species bs
			ON bs.boundary = b.value AND
			   bs.species_cd = LOWER(r.strUC)
		WHERE r.strUC = @strUC --'bEUCDx'
			  /*AND (r.intGapOrigin = 1 OR 
				   r.intGapOrigin = 4)*/
			  AND  r.intGapPres < 4
			  AND (r.intGapSeas = 1 OR
			       r.intGapSeas = 3 OR
			       r.intGapSeas = 4)
		GROUP BY
			r.strUC
		  , h.huc12rng
	)
/*
--test
		SELECT DISTINCT
		    r.strUC
		  --, h.huc12rng AS strHUC12RNG
		  , ISNULL(CAST(SUM(bs.count) AS bigint), 0) AS 'hab_Cnt' 
		FROM GapVert_48_2001.dbo.tblRanges r
		INNER JOIN GAP_AnalyticDB.dbo.hucs h
			ON h.huc12rng = r.strHUC12RNG
		INNER JOIN GAP_AnalyticDB.dbo.lu_boundary b
			ON b.hucs = h.objectid
		INNER JOIN GAP_AnalyticDB.dbo.lu_boundary_species bs
			ON bs.boundary = b.value AND
			   bs.species_cd = LOWER(r.strUC)
		WHERE r.strUC = 'bEATOx' --@strUC bGREPx mCHITx rYHGEx
			  AND  r.intGapPres < 4
			  AND (r.intGapSeas = 1 OR  -- y
			       r.intGapSeas = 3 OR  -- w
			       r.intGapSeas = 4)    -- s
		GROUP BY
			r.strUC
		  --, h.huc12rng
*/

	 INSERT INTO GAP_AnalyticDB.dbo.tmp_sppHuc
	 SELECT * FROM sppHucRng

	-- get the next record
	SELECT TOP 1 @strUC = strUC FROM #sppNoAnc WHERE strUC > @strUC ORDER BY strUC ASC
	-- decrease row count
	set @numRows = @numRows - 1 
END;
---------------------------------------------------------------------

WITH
-- Calculate the counts from the modeled MapUnits within each species' range
-- Get distinct list of MapUnits per species
smu AS (
	SELECT DISTINCT
		SppCode
	  , MUCode
	  , MUName
	  , MGCode
	  , MGName
	FROM #sppMUMG
	WHERE SppCode = 'bEATOx'
	)
,

-- Add huc list from range data to MapUnits
smuh AS (
	SELECT 
		smu.SppCode
	  , smu.MUCode
	  , smu.MUName
	  , smu.MGCode
	  , smu.MGName
	  , sh.strHUC12RNG
	FROM smu
	INNER JOIN GAP_AnalyticDB.dbo.tmp_sppHuc sh
		ON smu.SppCode = sh.strUC
	)
,

-- Get MapUnit cell count within species range
smuhc AS (
	SELECT
		smuh.SppCode
	  , smuh.MUCode
	  , smuh.strHUC12RNG
	  , ISNULL(SUM(bl.count),0) AS 'HabMU_Cnt'
	FROM smuh
	LEFT JOIN GAP_AnalyticDB.dbo.hucs h
		ON smuh.strHUC12RNG = h.huc12rng
	LEFT JOIN GAP_AnalyticDB.dbo.lu_boundary b
		ON h.objectid = b.hucs
	INNER JOIN GAP_AnalyticDB.dbo.lu_boundary_gap_lcv1 bl
		ON b.value = bl.boundary
	INNER JOIN GAP_AnalyticDB.dbo.lcv1 lc   --IMPORT CSV OF LCv1
		ON lc.value = bl.lcv1  
		AND lc.value = smuh.MUCode
	GROUP BY
		smuh.SppCode
	  , smuh.MUCode
	  , smuh.strHUC12RNG	
	)
,

-- Join to full spp/mapunit/huc list
smuch2 AS (
	SELECT 
		smuh.SppCode
	  , smuh.MUCode
	  , smuh.MUName
	  , smuh.MGCode
	  , smuh.MGName
	  , smuh.strHUC12RNG
	  , ISNULL(smuhc.HabMU_Cnt, 0) AS 'HabMU_Cnt'
	FROM smuh
	LEFT JOIN smuhc
		ON smuh.SppCode = smuhc.SppCode AND
		   smuh.MUCode = smuhc.MUCode AND
		   smuh.strHUC12RNG = smuhc.strHUC12RNG
	)
--,

-- Aggregate Spp/MU/Huc to Spp/MG
--sppMU AS (
	SELECT 
		smuch2.SppCode
	  --, smuch2.MUCode
	  --, smuch2.MUName
	  , smuch2.MGCode
	  , smuch2.MGName
	  --, smuch2.strHUC12RNG
	  , SUM(smuch2.HabMU_Cnt) AS 'HabMUMG_Cnt'
	FROM smuch2
	GROUP BY
		smuch2.SppCode
	  --, smuch2.MUCode
	  --, smuch2.MUName
	  , smuch2.MGCode
	  , smuch2.MGName
	  --, smuch2.strHUC12RNG
	)
,

-- Calculate the counts from all the MapUnits within each species' range
-- Get distinct list of MacroGroups per species
smg AS (
	SELECT DISTINCT
		SppCode
	  , MGCode
	  , MGName
	FROM #sppMUMG
	--WHERE SppCode = 'aARSAx'
	)
,

-- Join all MapUnits associated with MacroGroups
smgmu AS (
	SELECT 
		SppCode
	  , MGCode
	  , MGName
	  , level3 AS MUCode
	  , ecosys_lu AS MUName
	FROM smg 
	INNER JOIN GAP_AnalyticDB.dbo.gap_landfire lf
		ON smg.MGCode = lf.macro_cd
	)
,

-- Add huc list from range data to MapUnits
smgmuh AS (
	SELECT 
		SppCode
	  , MGCode
	  , MGName
	  , MUCode
	  , MUName
	  , strHUC12RNG
	FROM smgmu
	INNER JOIN GAP_AnalyticDB.dbo.tmp_sppHuc sh
		ON smgmu.SppCode = sh.strUC
	)
,

-- Tally the MapUnit counts within Hucs
muhc AS (
	SELECT 
		h.huc12rng
	  , lb.lcv1
	  , SUM(lb.count) AS 'count'
	FROM GAP_AnalyticDB.dbo.hucs h
	INNER JOIN GAP_AnalyticDB.dbo.lu_boundary b
		ON h.objectid = b.hucs
	INNER JOIN GAP_AnalyticDB.dbo.lu_boundary_gap_lcv1 lb
		ON b.value = lb.boundary
	GROUP BY h.huc12rng
		   , lb.lcv1
	)
,

-- Join MapUnit/Huc counts to Spp/MU/Huc list
smgmuhc AS (
	SELECT
		SppCode
	  , MGCode
	  , MGName
	  , MUCode
	  , MUName
	  , strHUC12RNG
	  , ISNULL(count, 0) AS 'HabMG_Cnt'
	FROM smgmuh
	LEFT JOIN muhc
		ON strHUC12RNG = huc12rng AND
		   MUCode = lcv1
	)
,

-- Aggregate Spp/MU/Huc to Spp/MG
sppMG AS (
	SELECT 
		SppCode
	  --, MUCode
	  --, MUName
	  , MGCode
	  , MGName
	  --, strHUC12RNG
	  , SUM(HabMG_Cnt) AS 'HabMG_Cnt'
	FROM smgmuhc
	GROUP BY
		SppCode
	  --, MUCode
	  --, MUName
	  , MGCode
	  , MGName
	  --, strHUC12RNG
	)
,

-- Combine habitat count by MapUnit and MacroGroup
sppMUMGhab AS (
	SELECT
		sppMU.SppCode
	  , sppMU.MGCode
	  , sppMU.MGName
	  --, sppMU.strHUC12RNG
	  , sppMU.HabMUMG_Cnt
	  , sppMG.HabMG_Cnt
	FROM sppMU
		 FULL JOIN sppMG
			ON sppMU.SppCode = sppMG.sppCode
		   AND sppMU.MGCode = sppMG.MGCode
		   --AND sppMU.strHUC12RNG = sppMG.strHUC12RNG
	)

-- Remove records with zero in both count fields
SELECT
	Sppcode
  , MGCode
  , MGName
  , HabMUMG_Cnt
  , HabMG_Cnt
  --, FORMAT(HabMUMG_Cnt, 'N0') AS HabMUMG_Cnt
  --, FORMAT(HabMG_Cnt, 'N0') AS HabMG_Cnt
  ,	FORMAT(HabMUMG_Cnt * 0.09, 'N1') AS HabMUMG_Ha
  ,	FORMAT(HabMG_Cnt * 0.09, 'N1') AS HabMG_Ha
  , FORMAT((CAST(HabMUMG_Cnt AS float) / CAST(HabMG_Cnt AS float)) * 100, 'N0') AS 'MUMG/MG Ratio'
FROM sppMUMGhab
WHERE HabMUMG_Cnt > 0 OR HabMG_Cnt > 0;

/*
@@@@@@@@@@@@@@@@@@@@@@
Checked cell counts against tiffs:

SppCode				tiff				sql				% diff

MISSING
bEUCDx
bGREPx
mCHITx
rYHGEx
*/

/* unfinished code
-- Build table of MU counts per Species and MacroGroups
WITH
-- Get number of MU per species
spmuc AS (
	SELECT 
		SppCode
	  , count(*) AS sppMUcnt
	FROM #sppMUMG
	GROUP BY 
		SppCode
	ORDER BY SppCode
	)
,

-- Get number of MUs in MGs selected by Spp
WITH --@@@@@@@@@@@@@@@@@@@@@@
--What is the count actually counting - seems there are multiples coming out of lf table
mgmuc0 AS (
	SELECT DISTINCT
		SppCode
		, smumg.MUCode
	  , macro_cd AS MGCode
	FROM #sppMUMG smumg
		 INNER JOIN GAP_AnalyticDB.dbo.gap_landfire lf
			ON smumg.MGCode = lf.macro_cd
	WHERE SppCode like 'bCOREx'-- AND MUCode = 1201
	GROUP BY 
		SppCode
		, smumg.MUCode
	  , macro_cd
	)
--,

-- Add the number of distinct MUs
--mgmuc AS (
	SELECT
		SppCode
	  , MGCode
	  , COUNT(*) AS 'mgMUcnt'
	FROM mgmuc0
	GROUP BY
		SppCode
	  , MGCode

*/