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

-- declare and set species variable
DECLARE @strUC VARCHAR(6)
SET @strUC = 'mRESQx';

-- Get map unit associations for a given species from the GAP Vert db (117 for mRESQx)
--	NOTE: This only uses primary map unit presence as a criterion

WITH
SppMUs AS (
	SELECT DISTINCT
		t.strUC AS SppCode
	  ,	t.strSciName AS SciName
	  ,	t.strComName AS ComName
	  ,	d.intLSGapMapCode AS MUCode
	  ,	d.strLSGapName AS MUName
	FROM GapVert_48_2001.dbo.tblSppMapUnitPres p 
		 INNER JOIN GapVert_48_2001.dbo.tblTaxa t
			ON SUBSTRING(p.strSpeciesModelCode, 1, 6) = t.strUC
		 INNER JOIN GapVert_48_2001.dbo.tblMapUnitDesc d
			ON p.intLSGapMapCode = d.intLSGapMapCode
		 INNER JOIN GapVert_48_2001.dbo.tblModelInfo i
			ON p.strSpeciesModelCode = i.strSpeciesModelCode
	WHERE
		p.ysnPres = 1 
		AND (i.intRegionCode >= 1 AND i.intRegionCode <=6) -- added region filter
		AND i.ysnIncludeSubModel = 1			-- added submodel Include filter
		AND t.strUC = @strUC
	)
,

-- Get corresponding MacroGroups from landcover legend in GapAnalytic_DB (43 for mRESQx)
SppMGs AS (
	SELECT DISTINCT
		SppMUs.SppCode
	  ,	SppMUs.SciName
	  ,	SppMUs.ComName
	  ,	lf.macro_cd
	  ,	lf.nvc_macro
	FROM
		SppMUs 
		INNER JOIN GAP_AnalyticDB.dbo.gap_landfire lf
			ON SppMUs.MUCode = lf.level3
	)
,

-- Get total habitat per species for CONUS
HabMU AS (
	SELECT
		(LEFT(cs.strUC,1) + UPPER(SUBSTRING(cs.strUC,2,4)) + RIGHT(cs.strUC,1)) AS strUC
	  ,	SUM(intCnt) AS HabMU_Cnt
	  --,	SUM(intCnt) * 0.00034749194269 AS HabMU_SqMile
	  --,	FORMAT(SUM(intCnt) * 0.00034749194269, 'N1') AS HabMU_SqMile2
	FROM GAP_AnalyticDB.dbo.tblSppSeasConusSumm cs
	GROUP BY (LEFT(cs.strUC,1) + UPPER(SUBSTRING(cs.strUC,2,4)) + RIGHT(cs.strUC,1))
	)
,

-- Get list of Hucs that have species habitat
HucRng AS (
	SELECT DISTINCT
		h.huc12rng
	  --, bs.species_cd
	  --, b.value AS bndID
	FROM GAP_AnalyticDB.dbo.lu_boundary_species bs
	INNER JOIN GAP_AnalyticDB.dbo.lu_boundary b
		ON bs.boundary = b.value
	INNER JOIN GAP_AnalyticDB.dbo.hucs h
		ON b.hucs = h.objectid
	WHERE bs.species_cd = @strUC
	)
,

-- Get MacroGroup cell count within species range
HabMG AS (
	SELECT 
		SppMGs.SppCode
	  --, lf.macro_cd
	  --, lf.nvc_macro
	  --, HucRng.huc12rng
	  , SUM(lb.count) AS HabMG_Cnt
	  , SUM(lb.count) * 0.00034749194269 AS HabMG_SqMile
	FROM GAP_AnalyticDB.dbo.gap_landfire lf
	INNER JOIN GAP_AnalyticDB.dbo.lu_boundary_gap_landfire lb
		ON lf.value = lb.gap_landfire
	INNER JOIN GAP_AnalyticDB.dbo.lu_boundary b
		ON lb.boundary = b.value
	INNER JOIN GAP_AnalyticDB.dbo.hucs h
		ON b.hucs = h.objectid
	INNER JOIN HucRng
		ON h.huc12rng = HucRng.huc12rng
	INNER JOIN SppMGs
		ON SppMGs.nvc_macro = lf.nvc_macro
	GROUP BY SppMGs.SppCode
		   --, lf.macro_cd
		   --, lf.nvc_macro
		   --, HucRng.huc12rng
	)

-- Combine habitat count by MapUnit and MacroGroup
SELECT
	HabMU.strUC
  , FORMAT(HabMU.HabMU_Cnt, 'N0') AS HabMU_Cnt
  , FORMAT(HabMG.HabMG_Cnt, 'N0') AS HabMG_Cnt
FROM HabMU 
	 INNER JOIN HabMG
		ON HabMU.strUC = HabMG.sppCode


