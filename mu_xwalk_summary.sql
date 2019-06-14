/*
mu_xwalk_summary.sql

Summarizes species' utlization for 19 mapunits as they are
 xwalked from 2001 landcover to 2011. Each of the 19 mapunits 
 don't exist in 2011 legend.
 
13jun19
Steve Williams
*/
USE GapVert_48_2001;
GO

-- declare variables
declare @numRows int, @mu_2001 int, @mu_2011 int

-- set up table for output summary; if present - empty, if absent - create
IF OBJECT_ID('tempdb.dbo.#xwalkSumm', 'U') IS NOT NULL 
  DELETE FROM #xwalkSumm; 
ELSE
  CREATE TABLE #xwalkSumm (mu_2001 varchar(4), mu_2011 varchar(4), xwPres varchar(3), count int);

-- set up table of map unit xwalks
declare @xw table (mu_2001 int, mu_2011 int)
insert into @xw
values	(3108,3110),
		(3109,3110),
		(3204,3206),
		(4142,9213),
		(4542,5515),
		(5108,5812),
		(8104,8402),
		(8105,8402),
		(8403,8407),
		(8405,8407),
		(8503,8407),
		(9229,9221),
		(9234,9221),
		(9242,9214),
		(9308,9214),
		(9402,9214),
		(9601,9240),
		(9855,9825),
		(9912,4206)

-- start with lowest value
SELECT @mu_2001=MIN(mu_2001) FROM @xw
print 'initial mu_2001 record: ' + CAST(@mu_2001 AS nvarchar)

-- get number of records
SELECT @numRows=COUNT(*) FROM @xw
print 'number of records: ' + CAST(@numRows AS nvarchar)

-- loop until no more records
WHILE @numRows > 0
BEGIN
	-- get other info from that row
	SELECT @mu_2011 = mu_2011 FROM @xw WHERE mu_2001 = @mu_2001
	print 'Row: ' + CAST(@numRows AS nvarchar) + ', mu_2001: ' + CAST(@mu_2001 AS nvarchar) + ', mu_2011: ' + CAST(@mu_2011 AS nvarchar);
	WITH
	 tblMU_2001 AS (
		SELECT p.intLSGapMapCode AS mu_2001
			 , SUBSTRING(p.strSpeciesModelCode,1,6) AS uc
			 , p.strSpeciesModelCode AS smc
			 , CAST(p.ysnPres AS nvarchar) AS ysnPres_2001
			 --, p.ysnPresAuxiliary AS ysnPresAux_2001
		FROM GapVert_48_2001.dbo.tblModelInfo i INNER JOIN 
			  GapVert_48_2001.dbo.tblSppMapUnitPres p ON
			   i.strSpeciesModelCode = p.strSpeciesModelCode INNER JOIN
			  GapVert_48_2001.dbo.tblTaxa t ON
			   t.strUC = i.strUC
		WHERE t.ysnIncludeSpp = 1 AND
			  i.ysnIncludeSubModel = 1 AND
			  p.intLSGapMapCode = @mu_2001
			  ),
	 tblMU_2011 AS (
		SELECT p.intLSGapMapCode AS mu_2011
			 , SUBSTRING(p.strSpeciesModelCode,1,6) AS uc_1
			 , p.strSpeciesModelCode AS smc_1
			 , CAST(p.ysnPres AS nvarchar) AS ysnPres_2011
			 --, p.ysnPresAuxiliary AS ysnPresAux_2011
		FROM GapVert_48_2001.dbo.tblModelInfo i INNER JOIN 
			  GapVert_48_2001.dbo.tblSppMapUnitPres p ON
			   i.strSpeciesModelCode = p.strSpeciesModelCode INNER JOIN
			  GapVert_48_2001.dbo.tblTaxa t ON
			   t.strUC = i.strUC
		WHERE t.ysnIncludeSpp = 1 AND
			  i.ysnIncludeSubModel = 1 AND
			  p.intLSGapMapCode = @mu_2011
			  ),
	 tblMU_XW AS (
		SELECT CAST(mu_2001 AS varchar(4)) AS mu_2001
			 , CAST(mu_2011 AS varchar(4)) AS mu_2011
			 , ysnPres_2001 + '-' + ysnPres_2011 AS xwPres
			 --, CAST(ysnPresAux_2001 AS nvarchar) + '-' + CAST(ysnPresAux_2011 AS nvarchar) AS xwPresAux
			 , COUNT(*) AS count
		FROM tblMU_2001 INNER JOIN tblMU_2011 ON 
			  smc = smc_1	  
		GROUP BY mu_2001
			   , mu_2011
			   , ysnPres_2001
			   , ysnPres_2011
			   --, ysnPresAux_2001
			   --, ysnPresAux_2011
			   )
		
	 INSERT INTO #xwalkSumm
	 SELECT * FROM tblMU_XW
	 ORDER BY xwPres

	-- get the next record
	SELECT TOP 1 @mu_2001 = mu_2001 FROM @xw WHERE mu_2001 > @mu_2001 ORDER BY mu_2001 ASC
	-- decrease row count
	set @numRows = @numRows - 1 
END;

-- open output temp table
SELECT * FROM #xwalkSumm



-- drop the temp table if it exist
IF OBJECT_ID('tempdb.dbo.#xwalkSumm', 'U') IS NOT NULL 
  DROP TABLE #xwalkSumm; 

