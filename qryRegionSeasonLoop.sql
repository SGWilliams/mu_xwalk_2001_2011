/****** Loop of Spp, Region & Season  ******/
-- declare variables
declare @numSpp int, @spp varchar(6),
		@numReg int, @reg int,
		@numSeas int, @seas varchar(1)

-- drop the temp tables if they exist
IF OBJECT_ID('tempdb.dbo.#t0srs', 'U') IS NOT NULL 
  DROP TABLE #t0srs; 
IF OBJECT_ID('tempdb.dbo.#t1spp', 'U') IS NOT NULL 
  DROP TABLE #t1spp; 
IF OBJECT_ID('tempdb.dbo.#t2reg', 'U') IS NOT NULL 
  DROP TABLE #t2reg; 
IF OBJECT_ID('tempdb.dbo.#t3seas', 'U') IS NOT NULL 
  DROP TABLE #t3seas; 

SELECT 
	strUC
  , strSeasonCode
  , intRegionCode
  , strSpeciesModelCode
INTO #t0srs
FROM GapVert_48_2001.dbo.tblModelInfo mi
	 INNER JOIN #sppNoAnc sna
	 ON mi.strUC = sna.strUC
WHERE ysnIncludeSubModel = 1
	AND strUC LIKE 'bCO%' --'bGRHAx%' 'bCOYEx%'
	AND intRegionCode >= 1 AND intRegionCode <= 6
	AND (strSeasonCode = 'S' OR strSeasonCode = 'W' OR strSeasonCode = 'Y')

-- Set up muliple embedded loops on sppNoAnc to run query by species, region & season
--  (takes ??? to complete)
-- get list of species
SELECT DISTINCT strUC INTO #t1spp FROM #t0srs
-- get number of species
SELECT @numSpp = COUNT(*) FROM #t1spp  --#sppNoAnc
print 'number of species: ' + CAST(@numSpp AS nvarchar)
-- start with lowest spp value
SELECT @spp = MIN(strUC) FROM #t1spp  --#sppNoAnc
-- loop species until no more records
WHILE @numSpp > 0
BEGIN
	-- work on selected species
	print '=============================='
	print 'working on species: '  + @spp
	-- drop the reg temp table if it exists
	IF OBJECT_ID('tempdb.dbo.#t2reg', 'U') IS NOT NULL 
		DROP TABLE #t2reg; 
	-- get list of regions for the current species
	SELECT DISTINCT intRegionCode INTO #t2reg FROM #t0srs WHERE strUC = @spp
	-- get number of regions
	SELECT @numReg = COUNT(*) FROM #t2reg
	print 'number of regions: ' + CAST(@numReg AS nvarchar)
	-- start with lowest value
	SELECT @reg = MIN(intRegionCode) FROM #t2reg
	-- loop region until no more records
	WHILE @numReg > 0
	BEGIN
		-- drop the temp tables if they exist
		IF OBJECT_ID('tempdb.dbo.#t3seas', 'U') IS NOT NULL 
			DROP TABLE #t3seas; 	
		-- work on selected region
		print '------------------------'
		print 'working on region: ' + CAST(@reg AS nvarchar)
		SELECT * INTO #t3seas FROM #t0srs WHERE strUC = @spp AND intRegionCode = @reg

		-- get number of seasons within current region
		SELECT @numSeas = COUNT(*) FROM #t3seas
		print 'number of seasons: ' + CAST(@numSeas AS nvarchar) 
		-- start with lowest value
		SELECT @seas = MIN(strSeasonCode) FROM #t3seas

		-- loop season until no more records
		WHILE @numSeas > 0
		BEGIN
			-- work on selected season
			print 'working on season: ' + @seas
			
			-- get the next record
			SELECT TOP 1 @seas = strSeasonCode FROM #t3seas WHERE strSeasonCode > @seas ORDER BY strSeasonCode ASC
			-- decrease row count
			set @numSeas = @numSeas - 1 
		END;

		-- get the next record
		SELECT TOP 1 @reg = intRegionCode FROM #t2reg WHERE intRegionCode > @reg ORDER BY intRegionCode ASC
		-- decrease row count
		set @numReg = @numReg - 1 
	END;

	-- get the next record
	SELECT TOP 1 @spp = strUC FROM #t1spp WHERE strUC > @spp ORDER BY strUC ASC
	-- decrease row count
	set @numSpp = @numSpp - 1 
END;