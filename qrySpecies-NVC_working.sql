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

/*
	This pulls map unit associations for a given species from the GAP Vert db
	NOTE: This only uses primary map unit presence as a criterion
*/
WITH
SppMUs AS
(SELECT 
	GapVert_48_2001.dbo.tblTaxa.strUC AS SppCode,
	GapVert_48_2001.dbo.tblTaxa.strSciName AS SciName,
	GapVert_48_2001.dbo.tblTaxa.strComName AS ComName,
	GapVert_48_2001.dbo.tblMapUnitDesc.intLSGapMapCode AS MUCode,
	GapVert_48_2001.dbo.tblMapUnitDesc.strLSGapName AS MUName

FROM GapVert_48_2001.dbo.tblSppMapUnitPres INNER JOIN tblTaxa 
		ON SUBSTRING(GapVert_48_2001.dbo.tblSppMapUnitPres.strSpeciesModelCode, 1, 6) = GapVert_48_2001.dbo.tblTaxa.strUC
		INNER JOIN GapVert_48_2001.dbo.tblMapUnitDesc
		ON GapVert_48_2001.dbo.tblSppMapUnitPres.intLSGapMapCode = GapVert_48_2001.dbo.tblMapUnitDesc.intLSGapMapCode
WHERE
	GapVert_48_2001.dbo.tblSppMapUnitPres.ysnPres = 1 AND
	GapVert_48_2001.dbo.tblTaxa.strUC = 'mRESQx'
GROUP BY GapVert_48_2001.dbo.tblTaxa.strUC, 
		 GapVert_48_2001.dbo.tblTaxa.strSciName, 
		 GapVert_48_2001.dbo.tblTaxa.strComName,
		 GapVert_48_2001.dbo.tblMapUnitDesc.intLSGapMapCode,
		 GapVert_48_2001.dbo.tblMapUnitDesc.strLSGapName
),

/*
	This pulls out boundary ids, map unit and macrogroup names,
	and cell counts for species from the GAP Analytic db

*/
SppBnd AS
(SELECT
	GAP_AnalyticDB.dbo.lu_boundary_species.boundary,
	GAP_AnalyticDB.dbo.lu_boundary_species.count,
	GAP_AnalyticDB.dbo.lu_boundary_species.species_cd,
	GAP_AnalyticDB.dbo.lu_boundary_gap_landfire.gap_landfire,
	GAP_AnalyticDB.dbo.gap_landfire.nvc_macro,
	GAP_AnalyticDB.dbo.gap_landfire.ecosys_lu,
	GAP_AnalyticDB.dbo.gap_landfire.level3
FROM
	GAP_AnalyticDB.dbo.lu_boundary_species INNER JOIN GAP_AnalyticDB.dbo.lu_boundary_gap_landfire 
	ON GAP_AnalyticDB.dbo.lu_boundary_species.boundary = GAP_AnalyticDB.dbo.lu_boundary_gap_landfire.boundary
	INNER JOIN GAP_AnalyticDB.dbo.gap_landfire 
	ON GAP_AnalyticDB.dbo.lu_boundary_gap_landfire.gap_landfire = GAP_AnalyticDB.dbo.gap_landfire.value
),

/*
	This summarizes habitat cell counts for a single species
	based on the CTE SppBnd created above

*/

SppBndCnt AS
(SELECT
	GAP_AnalyticDB.dbo.tblTaxa.strUC, 
	GAP_AnalyticDB.dbo.tblTaxa.strScientificName, 
	GAP_AnalyticDB.dbo.tblTaxa.strCommonName, 
	SppBnd.boundary,
	SppBnd.gap_landfire,
	SppBnd.ecosys_lu,
	SppBnd.nvc_macro,
	SppBnd.level3,
	SppBnd.count AS HabBndCount
FROM
	GAP_AnalyticDB.dbo.tblTaxa INNER JOIN SppBnd 
	ON GAP_AnalyticDB.dbo.tblTaxa.strUC = SppBnd.species_cd
WHERE GAP_AnalyticDB.dbo.tblTaxa.strUC = 'mRESQx'
),

/*
	This summarizes habitat cell counts by map unit and boundary

*/

SppMUBndCnt AS
(SELECT
	SppMUs.SppCode,
	SppMUs.SciName,
	SppMUs.ComName,
	SppBndCnt.ecosys_lu,
	SppBndCnt.nvc_macro,
	SppBndCnt.boundary AS BndID,
	SppBndCnt.HabBndCount
FROM
	SppMUs INNER JOIN SppBndCnt
	ON SppMUs.SppCode = SppBndCnt.strUC
	AND
	SppMUs.MUCode = SppBndCnt.level3
),

/*
	This summarizes cell counts in boundaries for macrogroups
*/

MacroBndCnt AS
(SELECT
	GAP_AnalyticDB.dbo.lu_boundary.value AS Bid,
	GAP_AnalyticDB.dbo.gap_landfire.nvc_macro,
	sum(GAP_AnalyticDB.dbo.lu_boundary_gap_landfire.count) AS MGBndCount
FROM
	GAP_AnalyticDB.dbo.lu_boundary INNER JOIN GAP_AnalyticDB.dbo.lu_boundary_gap_landfire ON
	GAP_AnalyticDB.dbo.lu_boundary.value = GAP_AnalyticDB.dbo.lu_boundary_gap_landfire.boundary
	INNER JOIN GAP_AnalyticDB.dbo.gap_landfire ON
	GAP_AnalyticDB.dbo.lu_boundary_gap_landfire.gap_landfire = GAP_AnalyticDB.dbo.gap_landfire.value

GROUP BY
	lu_boundary.value,
	gap_landfire.nvc_macro
)


/*
	This brings all the above together by combining the habitat
	cell count total for a given species across all boundaries within
	its habitat map and cell count totals for those boundaries 
	summed by NVC macrogroup.

	NOTE: This is all for a single species - Red Squirrel mRESQx

*/

SELECT 
	SppMUBndCnt.SppCode,
	SppMUBndCnt.SciName,
	SppMUBndCnt.ComName,
	--SppMUBndCnt.ecosys_lu AS MUName,
	SppMUBndCnt.nvc_macro AS Macrogroup,
	SppMUBndCnt.BndID,
	SppMUBndCnt.HabBndCount,
	sum(MacroBndCnt.MGBndCount) AS MGBndTotal
FROM 
	SppMUBndCnt INNER JOIN MacroBndCnt
	ON SppMUBndCnt.nvc_macro = MacroBndCnt.nvc_macro
	AND
	SppMUBndCnt.BndID = MacroBndCnt.Bid
GROUP BY 
	SppMUBndCnt.SppCode,
	SppMUBndCnt.SciName,
	SppMUBndCnt.ComName,
	SppMUBndCnt.nvc_macro,
	SppMUBndCnt.BndID,
	SppMUBndCnt.HabBndCount
ORDER BY
	SppMUBndCnt.BndID


/*
SELECT 
	SppMUBndCnt.SppCode,
	SppMUBndCnt.SciName,
	SppMUBndCnt.ComName,
	SppMUBndCnt.HabBndCount,
	sum(MacroBndCnt.MGBndCount) AS MGBndTotal
FROM 
	SppMUBndCnt INNER JOIN MacroBndCnt
	ON SppMUBndCnt.nvc_macro = MacroBndCnt.nvc_macro
	AND
	SppMUBndCnt.BndID = MacroBndCnt.Bid
GROUP BY 
	SppMUBndCnt.SppCode,
	SppMUBndCnt.SciName,
	SppMUBndCnt.ComName,
	SppMUBndCnt.HabBndCount
*/