/*
	qrySubmodel-NVC.sql

	This identifies MacroGroups associated with species' habitat and quantifies
	the expected increase in extent for a generalization of map unit selections to
	the corresponding NVC Macrogroup. Map units (NVC ecosystems) are lumped into
	121 macrogroups, thereby adding commission error.

	This query uses both the GAP Analytic db and the GAP Vert db to combine data
	on species habitat map selections from the Vert db with 'spatial' correlates
	of cell counts in the Analytic db. The later identifies geography using unique
	ids of 'boundaries' which are intersections of various data layers such as
	LCCs, ecoregions, counties, HUCs, etc. Separate tables contain data on boundary
	cell counts for each species (in the table lu_boundary_species) and for NVC
	categories (in the table lu_boundary_gap_lcv1).

	The resulting output is only an approximation due to the use of range 
	polygons (HUC12RNG) to delineate regional submodel boundaries. All species'
	data confirmed < 2% difference in model extent with the vast majority < 1 %.

	-Steve Williams
	20aug2019

	Required dBs:
		GAP_AnalyticDB
		GapVert_48_2001

	Output:
		habMG_SppMG_Summary.txt
		habMG_Spp_Summary.txt

*/

-- drop the temp tables if they exist
IF OBJECT_ID('tempdb.dbo.#sppNoAnc', 'U') IS NOT NULL 
  DROP TABLE #sppNoAnc; 
IF OBJECT_ID('tempdb.dbo.#smHABtable', 'U') IS NOT NULL 
  DROP TABLE #smHABtable; 
IF OBJECT_ID('tempdb.dbo.#muhc', 'U') IS NOT NULL 
  DROP TABLE #muhc; 

print 'Creating list of non-ancillary species utilizing forest landcover.';

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
		d.intForest = 1
--		AND sppAnyAnc.strUC = 'bCWWIx'
print '------------------------------------------------------------------';

print 'Creating table of species submodel habitat use (MapUnit & MacroGroup).';
-- Get MapUnits and MacroGroups associated with species from the GapVert_48_2001 dB
--	NOTE: This only uses primary map unit presence as a criterion
SELECT
	t.strUC AS SppCode
  , p.strSpeciesModelCode
  , t.strSciName AS SciName
  ,	t.strComName AS ComName
  ,	d.intLSGapMapCode AS MUCode
  ,	d.strLSGapName AS MUName
  ,	lf.macro_cd AS MGCode
  ,	lf.nvc_macro AS MGName
INTO #smHABtable
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
	i.ysnIncludeSubModel = 1;
--select * from #smHABtable
--select distinct SppCode, MUCode from #smHABtable WHERE strSpeciesModelCode like '%6'
print '------------------------------------------------------------------';

/*
-- Get list of Hucs that contain species seasonal range from GapVert_48_2001
print '======================================='
print 'Gathering species huc range data...'

/************** Loop of Spp  ***************/
-- declare variables
DECLARE @numRows int, @strUC varchar(6)

/*
-- create empty temp table for sppHuc; if present - empty, if absent - create
IF OBJECT_ID('tempdb.dbo.#sppHuc', 'U') IS NOT NULL 
  DELETE FROM #sppHuc;
  --DROP TABLE #sppHuc; 
ELSE
  CREATE TABLE #sppHuc (strUC varchar(6), strSeason varchar(1), strHUC12RNG varchar(12));
*/

-- temporarily create and maintain temp table for sppHuc in GAP_AnalyticDB (remove from final code)
-- this is for debugging purposes and code must be hand run to avoid errors
--CREATE TABLE GAP_AnalyticDB.dbo.tmp_sppHuc (strUC varchar(6), strSeason varchar(1), strHUC12RNG varchar(12));
--DROP TABLE GAP_AnalyticDB.dbo.tmp_sppHuc

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
		  , CASE
				WHEN r.intGapSeas = 1 THEN 'Y'
				WHEN r.intGapSeas = 3 THEN 'W'
				WHEN r.intGapSeas = 4 THEN 'S'
				ELSE 'x'
			END AS 'strSeason'
		  , h.huc12rng AS strHUC12RNG
		FROM GapVert_48_2001.dbo.tblRanges r
		INNER JOIN GAP_AnalyticDB.dbo.hucs h
			ON h.huc12rng = r.strHUC12RNG
		INNER JOIN GAP_AnalyticDB.dbo.lu_boundary b
			ON b.hucs = h.objectid
		INNER JOIN GAP_AnalyticDB.dbo.lu_boundary_species bs
			ON bs.boundary = b.value AND
			   bs.species_cd = LOWER(r.strUC)
		WHERE r.strUC = @strUC --'bEUCDx'
			  AND  r.intGapPres < 4
			  AND (r.intGapSeas = 1 OR	-- y
			       r.intGapSeas = 3 OR  -- w
			       r.intGapSeas = 4)    -- s
	)

	 INSERT INTO GAP_AnalyticDB.dbo.tmp_sppHuc
	 SELECT * 
	 FROM sppHucRng

	-- get the next record
	SELECT TOP 1 @strUC = strUC FROM #sppNoAnc WHERE strUC > @strUC ORDER BY strUC ASC
	-- decrease row count
	SET @numRows = @numRows - 1 
END;
print '=======================================';
print '------------------------------------------------------------------';
*/

-- Tally the MapUnit counts within Hucs
print 'Creating table of MapUnit counts within Hucs.';
SELECT 
	h.huc12rng
  , lb.lcv1
  , SUM(lb.count) AS 'count'
INTO #muhc
FROM GAP_AnalyticDB.dbo.hucs h
INNER JOIN GAP_AnalyticDB.dbo.lu_boundary b
	ON h.objectid = b.hucs
INNER JOIN GAP_AnalyticDB.dbo.lu_boundary_gap_lcv1 lb
	ON b.value = lb.boundary
GROUP BY h.huc12rng
	   , lb.lcv1;
print '------------------------------------------------------------------';
-- Set up muliple embedded loops on sppNoAnc to run submodel query 
--  by species, region & season to build habitat counts on MUs & MGs.
--  (takes 5 hours to complete)
/****** Loop of Spp, Region & Season  ******/
-- declare variables
DECLARE @numSpp int, @spp varchar(6),
		@numReg int, @reg int,
		@numSeas int, @seas varchar(1),
		@ssm varchar(9)

-- drop the looping temp tables if they exist
DROP TABLE IF EXISTS #t0srs
DROP TABLE IF EXISTS #t1spp
DROP TABLE IF EXISTS #t2reg
DROP TABLE IF EXISTS #t3seas
-- reset output temp table
DROP TABLE IF EXISTS #sppMUMG
CREATE TABLE #sppMUMG (SppCode varchar(6), 
						MGCode varchar(20),
						MGName varchar(255),
						HabMU_Cnt bigint,
						HabMG_Cnt bigint);

print 'Create list of species/region/season submodels.';
SELECT 
	mi.strUC
  , mi.strSeasonCode
  , mi.intRegionCode
  , mi.strSpeciesModelCode
INTO #t0srs
FROM GapVert_48_2001.dbo.tblModelInfo mi
	 INNER JOIN #sppNoAnc sna
	 ON mi.strUC = sna.strUC
WHERE ysnIncludeSubModel = 1
	--AND mi.strUC LIKE 'bCOYEx%' --'bGRHAx%' 'bCOYEx%'
	AND mi.intRegionCode >= 1 AND mi.intRegionCode <= 6
	AND (mi.strSeasonCode = 'S' OR mi.strSeasonCode = 'W' OR mi.strSeasonCode = 'Y');
print '---------------------------------------------';

-- get list of species to work on
print 'Set list of species for looping';
SELECT DISTINCT strUC INTO #t1spp FROM #t0srs
-- get number of species
SELECT @numSpp = COUNT(*) FROM #t1spp
print 'number of species: ' + CAST(@numSpp AS nvarchar);
-- start with lowest value and loop until no more records
SELECT @spp = MIN(strUC) FROM #t1spp
WHILE @numSpp > 0
BEGIN
	-- work on selected species
	print '==============================';
	print 'working on species: '  + @spp;
	-- reset list of regions for the current species
	DROP TABLE IF EXISTS #t2reg
	SELECT DISTINCT intRegionCode INTO #t2reg FROM #t0srs WHERE strUC = @spp
	-- get number of regions
	SELECT @numReg = COUNT(*) FROM #t2reg
	print 'number of regions: ' + CAST(@numReg AS nvarchar);
	-- start with lowest value and loop region until no more records
	SELECT @reg = MIN(intRegionCode) FROM #t2reg
	WHILE @numReg > 0
	BEGIN
		-- work on selected region
		print '------------------------'
		print 'working on region: ' + CAST(@reg AS nvarchar);
		-- reset MU and MG output tables
		DROP TABLE IF EXISTS #smMU
		CREATE TABLE #smMU (SppCode varchar(6), 
								MUCode int,
								MUName varchar(255),
								MGCode varchar(20),
								MGName varchar(255),
								strHUC12RNG varchar(12),
								HabMU_Cnt bigint);
		DROP TABLE IF EXISTS #smMG
		CREATE TABLE #smMG (SppCode varchar(6), 
								MUCode int,
								MUName varchar(255),
								MGCode varchar(20),
								MGName varchar(255),
								strHUC12RNG varchar(12),
								HabMG_Cnt bigint);
		-- reset list of seasons for the current region
		DROP TABLE IF EXISTS #t3seas
		SELECT * INTO #t3seas FROM #t0srs WHERE strUC = @spp AND intRegionCode = @reg
		-- get number of seasons within current region
		SELECT @numSeas = COUNT(*) FROM #t3seas
		print 'number of seasons: ' + CAST(@numSeas AS nvarchar);
		-- start with lowest value and loop season until no more records
		SELECT @seas = MIN(strSeasonCode) FROM #t3seas
		WHILE @numSeas > 0
		BEGIN
			-- work on selected season
			print '  season: ' + @seas; 
			-- set the submodel
			SET @ssm = @spp + '-' + @seas + CAST(@reg AS nvarchar);
			-- drop previous range table if it exists
			DROP TABLE IF EXISTS #srh
			-- create table of range hucs for current species, region and season
			SELECT 
				rh.strHUC12RNG 
			INTO #srh
			FROM GAP_AnalyticDB.dbo.tblHuc12rngRegion rh
				 INNER JOIN GAP_AnalyticDB.dbo.tmp_sppHuc sh
					ON rh.strHUC12RNG = sh.strHUC12RNG
			WHERE rh.intRegionCode = @reg 
				  AND sh.strUC = @spp
				  AND (sh.strSeason = @seas OR
				       sh.strSeason = 'Y');

			-- Calculate the counts from the modeled MapUnits within submodel range
			WITH
			-- get list of MapUnits per submodel
			smu AS (
				SELECT
					SppCode
				  , MUCode
				  , MUName
				  , MGCode
				  , MGName
				FROM #smHABtable
				WHERE strSpeciesModelCode = @ssm
				)
			,

			-- join huc list to MapUnit list
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
				INNER JOIN #srh
					ON sh.strHUC12RNG = #srh.strHUC12RNG
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
			smuhc2 AS (
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
				ON smuh.SppCode = smuhc.SppCode
					AND smuh.MUCode = smuhc.MUCode 
					AND smuh.strHUC12RNG = smuhc.strHUC12RNG
				)
			
			-- unload MU output
			INSERT INTO #smMU
			SELECT * 
			FROM smuhc2;

			-- Calculate the counts from all MapUnits within submodel range
			WITH
			-- get distinct list of MacroGroups per species
			smg AS (
				SELECT DISTINCT
					SppCode
				  , MGCode
				  , MGName
				FROM #smHABtable
				WHERE strSpeciesModelCode = @ssm
				)
			,

			-- Join all MapUnits associated with MacroGroups
			smgmu AS (
				SELECT 
					smg.SppCode
				  , smg.MGCode
				  , smg.MGName
				  , lf.level3 AS MUCode
				  , lf.ecosys_lu AS MUName
				FROM smg 
				INNER JOIN GAP_AnalyticDB.dbo.gap_landfire lf
					ON smg.MGCode = lf.macro_cd
				)
			,

			-- Add huc list from range data to MapUnits
			smgmuh AS (
				SELECT 
					smgmu.SppCode
				  , smgmu.MGCode
				  , smgmu.MGName
				  , smgmu.MUCode
				  , smgmu.MUName
				  , sh.strHUC12RNG
				FROM smgmu
				INNER JOIN GAP_AnalyticDB.dbo.tmp_sppHuc sh
					ON smgmu.SppCode = sh.strUC
				INNER JOIN #srh
					ON sh.strHUC12RNG = #srh.strHUC12RNG
				)
			,

			-- Join MapUnit/Huc counts to Spp/MU/Huc list
			smgmuhc AS (
				SELECT
					smgmuh.SppCode
					, smgmuh.MUCode
					, smgmuh.MUName
					, smgmuh.MGCode
					, smgmuh.MGName
					, smgmuh.strHUC12RNG
					, ISNULL(#muhc.count, 0) AS 'HabMG_Cnt'
				FROM smgmuh
				LEFT JOIN #muhc
					ON strHUC12RNG = huc12rng 
						AND MUCode = lcv1
				)
			
			-- unload MG output
			INSERT INTO #smMG
			SELECT * 
			FROM smgmuhc

			-- get the next record
			SELECT TOP 1 @seas = strSeasonCode FROM #t3seas WHERE strSeasonCode > @seas ORDER BY strSeasonCode ASC
			-- decrease row count
			set @numSeas = @numSeas - 1 
		END; -- of season loop

		WITH
		-- Aggregate count from Spp/MU/Huc to Spp/MG for both
		--   tight MU and expanded MU habitat.

		-- Tight MU habitat - this count output should match geotiff
		-- get distinct mapunit/huc counts to remove redundant records
		--   due to multiple seasons
		smuchd AS (
			SELECT DISTINCT
				SppCode
			  , MUCode
			  , MUName
			  , MGCode
			  , MGName
			  , strHUC12RNG
			  , HabMU_Cnt
			FROM #smMU
			)
		,
		-- sum count for magrogroups
		sppMU AS (
			SELECT
				SppCode
			  , MGCode
			  , MGName
			  , SUM(HabMU_Cnt) AS 'HabMU_Cnt'
			FROM smuchd
			GROUP BY
				SppCode
			  , MGCode
			  , MGName
			)
		,

		-- Expanded MU habitat - this count output is due to MG expansion
		-- get distinct mapunit/huc counts to remove redundant records
		--   due to multiple seasons
		smgmuhcd AS (
			SELECT DISTINCT
				SppCode
			  , MUCode
			  , MUName
			  , MGCode
			  , MGName
			  , strHUC12RNG
			  , HabMG_Cnt
			FROM #smMG
			)
		,
		-- sum count for magrogroups
		sppMG AS (
			SELECT DISTINCT
				SppCode
			  --, MUCode
			  --, MUName
			  , MGCode
			  , MGName
			  --, strHUC12RNG
			  , SUM(HabMG_Cnt) AS 'HabMG_Cnt'
			FROM smgmuhcd
			GROUP BY
				SppCode
				--, MUCode
				--, MUName
				, MGCode
				, MGName
				--, strHUC12RNG
			)
		,

		-- Combine Tight (MU) and Expanded (MG) habitat count
		sppMUMG AS (
			SELECT
				CASE
					WHEN mu.SppCode IS NULL THEN mg.SppCode
					ELSE mu.SppCode
				END AS 'SppCode'
			  , CASE
					WHEN mu.MGCode IS NULL THEN mg.MGCode
					ELSE mu.MGCode
				END AS 'MGCode'
			  , CASE
					WHEN mu.MGName IS NULL THEN mg.MGName
					ELSE mu.MGName
				END AS 'MGName'
			  , CASE
					WHEN mu.HabMU_Cnt IS NULL THEN 0
					ELSE mu.HabMU_Cnt
				END AS 'HabMU_Cnt'
			  , CASE
					WHEN mg.HabMG_Cnt IS NULL THEN 0
					ELSE mg.HabMG_Cnt
				END AS 'HabMG_Cnt'
			FROM sppMU mu
				FULL JOIN sppMG mg
				ON mu.SppCode = mg.sppCode
				AND mu.MGCode = mg.MGCode
			)
		,
		-- Remove records with zero in both count fields
		sppMUMGhab AS (
			SELECT
				Sppcode
			  , MGCode
			  , MGName
			  , HabMU_Cnt
			  , HabMG_Cnt
			FROM sppMUMG
			WHERE HabMU_Cnt > 0 OR HabMG_Cnt > 0
			)
		
		-- unload regional output 
		INSERT INTO #sppMUMG
		SELECT * FROM sppMUMGhab

		-- get the next record
		SELECT TOP 1 @reg = intRegionCode FROM #t2reg WHERE intRegionCode > @reg ORDER BY intRegionCode ASC
		-- decrease row count
		set @numReg = @numReg - 1 
	END  -- of region loop

	-- get the next record
	SELECT TOP 1 @spp = strUC FROM #t1spp WHERE strUC > @spp ORDER BY strUC ASC
	-- decrease row count
	set @numSpp = @numSpp - 1 
END  -- of species loop
print '==============================';
	
-- Aggregate final output table
DROP TABLE IF EXISTS #mgSummary;

WITH
-- Get count of tight mapunits
smu AS (
	SELECT DISTINCT 
		SppCode
	  , MGCode
	  , MUCode 
	FROM #smHABtable
	)
,
mut AS (
	SELECT
		SppCode
	  , MGCode
	  , COUNT(DISTINCT MUCode) AS 'nT'
	FROM smu
	GROUP BY
		SppCode
	  , MGCode
	)
,
-- Get count of expanded mapunits 
smg AS (
	SELECT DISTINCT
		SppCode
	  , MGCode
	FROM #smHABtable
	)
,
-- join all MapUnits associated with MacroGroups
smgmu AS (
	SELECT 
		smg.SppCode
	  , smg.MGCode
	  , lf.level3 AS MUCode
	FROM smg 
	INNER JOIN GAP_AnalyticDB.dbo.gap_landfire lf
		ON smg.MGCode = lf.macro_cd
	)
,
mue AS (
	SELECT
		SppCode
	  , MGCode
	  , COUNT(DISTINCT MUCode) AS 'nE'
	FROM smgmu
	GROUP BY
		SppCode
	  , MGCode
	)
,

-- summarize Spp/MG mapunit count
mumg0 AS (
	SELECT
		Sppcode
	  , MGCode
	  , MGName
	  , SUM(HabMU_Cnt) AS 'HabMU_Cnt'
	  , SUM(HabMG_Cnt) AS 'HabMG_Cnt'
	FROM #sppMUMG
	GROUP BY
		Sppcode
	  , MGCode
	  , MGName
	)		

-- save output as temp file
SELECT
	mumg0.Sppcode
  , t.strComName
  , t.strSciName
  , mumg0.MGCode
  , mumg0.MGName
  , mut.nT
  , mue.nE
  , mumg0.HabMU_Cnt
  , mumg0.HabMG_Cnt
  --, FORMAT(mumg0.HabMU_Cnt, 'N0') AS HabMUMG_Cnt
  --, FORMAT(mumg0.HabMG_Cnt, 'N0') AS HabMG_Cnt
  --,	FORMAT(mumg0.HabMU_Cnt * 0.09, 'N1') AS 'HabMG_Ha (Tight)'
  --,	FORMAT(mumg0.HabMG_Cnt * 0.09, 'N1') AS 'HabMG_Ha (Expanded)'
  --, FORMAT(((1 - (CAST(mumg0.HabMU_Cnt AS float) / CAST(mumg0.HabMG_Cnt AS float))) * 100), 'N0') AS 'MacroGroup % Increase'
INTO #mgSummary
FROM mumg0
	FULL JOIN mut
	ON mumg0.SppCode = mut.SppCode
	AND mumg0.MGCode = mut.MGCode
	FULL JOIN mue
	ON mumg0.SppCode = mue.SppCode
	AND mumg0.MGCode = mue.MGCode
	INNER JOIN GapVert_48_2001.dbo.tblTaxa t
	ON mumg0.SppCode = t.strUC;

-- open and format Spp/MG summary
SELECT 
	Sppcode
  , strComName
  , strSciName
  , MGCode
  , MGName
  , nT AS 'N MU Tight'
  , nE AS 'N MU Expanded'
  ,	FORMAT(HabMU_Cnt * 0.09, 'N1') AS 'HabMG_Ha (Tight)'
  ,	FORMAT(HabMG_Cnt * 0.09, 'N1') AS 'HabMG_Ha (Expanded)'
  , FORMAT(((1 - (CAST(HabMU_Cnt AS float) / CAST(HabMG_Cnt AS float))) * 100), 'N0') AS 'MacroGroup % Increase'
FROM #mgSummary;

-- open and format Spp summary
SELECT 
	Sppcode
  , strComName
  , strSciName
  , SUM(nT) AS 'N MU Tight'
  , SUM(nE) AS 'N MU Expanded'
  ,	FORMAT(SUM(HabMU_Cnt) * 0.09, 'N1') AS 'HabMG_Ha (Tight)'
  ,	FORMAT(SUM(HabMU_Cnt) * 0.09, 'N1') AS 'HabMG_Ha (Expanded)'
  , FORMAT(((1 - (CAST(SUM(HabMU_Cnt) AS float) / CAST(SUM(HabMG_Cnt) AS float))) * 100), 'N0') AS 'MacroGroup % Increase'
FROM #mgSummary
GROUP BY 
	Sppcode
  , strComName
  , strSciName;








SELECT
	Sppcode
	, SUM(HabMU_Cnt) AS 'HabMU_Cnt'
	, SUM(HabMG_Cnt) AS 'HabMG_Cnt'
FROM #sppMUMG
GROUP BY
	Sppcode


------------------
--select * from #srh
--select * from #smMU
--select * from #smMG
--select * from #sppMUMG