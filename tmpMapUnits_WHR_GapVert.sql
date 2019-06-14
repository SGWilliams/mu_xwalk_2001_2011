-- join map units from region 1-6 in WHRdB with map units from GapVert_48_2001

WITH 
tblWHRdB AS (
	SELECT *
	FROM [WHRdB].[dbo].[tblMapUnitDesc]
	WHERE ysnRegion1 = 1 OR 
		  ysnRegion2 = 1 OR
		  ysnRegion3 = 1 OR
		  ysnRegion4 = 1 OR
		  ysnRegion5 = 1 OR
		  ysnRegion6 = 1),
tblGapVert_48 AS (
	SELECT *
	FROM [GapVert_48_2001].[dbo].[tblMapUnitDesc])

SELECT *
FROM tblWHRdB FULL JOIN tblGapVert_48 ON
     tblWHRdB.intLSGapMapCode = tblGapVert_48.intLSGapMapCode
-- subset to 19 mapunits
WHERE tblWHRdB.intLSGapMapCode = 3108 OR
      tblWHRdB.intLSGapMapCode = 3109 OR
      tblWHRdB.intLSGapMapCode = 3204 OR
      tblWHRdB.intLSGapMapCode = 4142 OR
      tblWHRdB.intLSGapMapCode = 4542 OR
      tblWHRdB.intLSGapMapCode = 5108 OR
      tblWHRdB.intLSGapMapCode = 8104 OR
      tblWHRdB.intLSGapMapCode = 8105 OR
      tblWHRdB.intLSGapMapCode = 8403 OR
      tblWHRdB.intLSGapMapCode = 8405 OR
      tblWHRdB.intLSGapMapCode = 8503 OR
      tblWHRdB.intLSGapMapCode = 9229 OR
      tblWHRdB.intLSGapMapCode = 9234 OR
      tblWHRdB.intLSGapMapCode = 9242 OR
      tblWHRdB.intLSGapMapCode = 9308 OR
      tblWHRdB.intLSGapMapCode = 9402 OR
      tblWHRdB.intLSGapMapCode = 9601 OR
      tblWHRdB.intLSGapMapCode = 9855 OR
      tblWHRdB.intLSGapMapCode = 9912
      
/*
There are 591 mapunits that are region 1-6 in WHRdB.
There are also 591 mapunits in Gap_Vert_48_2001 (it was filtered to remove non CONUS mapunits)
However, one Alaskan mapunit slipped in and one CONUS mapunit was dropped.
2040	North Pacific Mesic Western Hemlock-Yellow-cedar Forest
8406	Introduced Riparian and Wetland Vegetation
*/
--***************************************************

-- No 2040 mapunits in GAP_AnalyticDB
SELECT DISTINCT	substring([strSpeciesModelCode],1,6) AS strUC
FROM    [WHRdB].[dbo].[tblSppMapUnitPres]
WHERE   (intLSGapMapCode = 2040) AND (ysnPres = 1 OR ysnPresAuxiliary = 1) -- AND (strSpeciesModelCode LIKE 'mAMBEx%')

-- Lots of species with 8406
SELECT DISTINCT	substring([strSpeciesModelCode],1,6) AS strUC
FROM    [WHRdB].[dbo].[tblSppMapUnitPres]
WHERE   (intLSGapMapCode = 8406) AND (ysnPres = 1 OR ysnPresAuxiliary = 1) -- AND (strSpeciesModelCode LIKE 'mAMBEx%')

-- WHERE strLSGapName like 'Introduced Riparian and Wetland Vegetation'

SELECT DISTINCT	substring([strSpeciesModelCode],1,6) AS strUC
FROM    [WHRdB].[dbo].[tblSppMapUnitPres]
WHERE   (intLSGapMapCode = 8406) AND (ysnPres = 1 OR ysnPresAuxiliary = 1) -- AND (strSpeciesModelCode LIKE 'mAMBEx%')


-- map unit use in GapVert_48_2001
SELECT *
FROM [GapVert_48_2001].[dbo].[tblMapUnitDesc]
WHERE ysnRegion1 = 1 OR 
      ysnRegion2 = 1 OR
	  ysnRegion3 = 1 OR
	  ysnRegion4 = 1 OR
	  ysnRegion5 = 1 OR
	  ysnRegion6 = 1

WHERE strFuncGroup1 = 'Anthropogenic                    '
ORDER BY intLSGapMapCode
WHERE intLSGapMapCode = 8406
WHERE strLSGapName like 'Introduced Riparian and Wetland Vegetation'

SELECT *
	FROM [WHRdB].[dbo].[tblMapUnitDesc]
	WHERE ysnRegion1 = 1 OR 
		  ysnRegion2 = 1 OR
		  ysnRegion3 = 1 OR
		  ysnRegion4 = 1 OR
		  ysnRegion5 = 1 OR
		  ysnRegion6 = 1

-- map unit use in GAP_AnalyticDB
SELECT *
FROM [GAP_AnalyticDB].[dbo].[gap_landfire]
WHERE ecosys_lu like 'Introduced Riparian and Wetland Vegetation'



-- Other missing Mapunits 
-- In GAP_AnalyticDB??
SELECT *
FROM [GAP_AnalyticDB].[dbo].[gap_landfire]

-- subset to blank mapunits
WHERE level3 = 4542 OR
      level3 = 9308 OR
      level3 = 9912 OR
      level3 = 4142 OR
      level3 = 9213 OR
      level3 = 9242 OR
      level3 = 9234

-- subset to 19 mapunits
WHERE level3 = 3108 OR
      level3 = 3109 OR
      level3 = 3204 OR
      level3 = 4142 OR
      level3 = 4542 OR
      level3 = 5108 OR
      level3 = 8104 OR
      level3 = 8105 OR
      level3 = 8403 OR
      level3 = 8405 OR
      level3 = 8503 OR
      level3 = 9229 OR
      level3 = 9234 OR
      level3 = 9242 OR
      level3 = 9308 OR
      level3 = 9402 OR
      level3 = 9601 OR
      level3 = 9855 OR
      level3 = 9912

-- Join based on code 
/* 
591 mapunits in WHR tblMapUnitDesc table
585 mapunits in Analytic gap_landfire descriptor table (GAP_LANDFIRE_NationalTerrestrialEcosystems2011.tif)
572 match
13 in Analytic (with no info other than code) that are not present in WHR
	0
	97
	205
	206
	211
	209
	222
	267
	394
	418
	419
	421
	564
19 in WHR that are not present in Analytic
	3108	Unconsolidated Shore (Lake/River/Pond)
	3109	Unconsolidated Shore (Beach/Dune)
	3204	Great Lakes Acidic Rocky Shore and Cliff                                                           
	4142	East-Central Texas Plains Floodplain Forest                                                        
	4542	Laurentian Jack Pine-Red Pine Forest                                                               
	5108	Northern Rocky Mountain Avalanche Chute Shrubland                                                  
	8104	Utility Swath - Herbaceous
	8105	Successional Shrub/Scrub (Other)
	8403	Introduced Upland Vegetation - Forbland
	8503	Ruderal Upland - Old Field
	8405	Introduced Upland Vegetation - Perennial Grassland
	9229	Great Lakes Freshwater Estuary and Delta                                                           
	9234	Northern Great Lakes Coastal Marsh                                                                 
	9242	Laurentian-Acadian Freshwater Marsh                                                                
	9308	Laurentian-Acadian Alkaline Conifer-Hardwood Swamp                                                 
	9402	Great Lakes Wooded Dune and Swale                                                                  
	9601	Northern Atlantic Coastal Plain Pitch Pine Lowland                                                 
	9855	Inter-Mountain Basins Montane Riparian Systems                                                     
	9912	South-Central Interior / Upper Coastal Plain Wet Flatwoods                                         

*/
WITH 
tblWHRdB AS (
	SELECT *
	FROM [WHRdB].[dbo].[tblMapUnitDesc]
	WHERE ysnRegion1 = 1 OR 
		  ysnRegion2 = 1 OR
		  ysnRegion3 = 1 OR
		  ysnRegion4 = 1 OR
		  ysnRegion5 = 1 OR
		  ysnRegion6 = 1),
tblAnalytic AS (
	SELECT *
	FROM [GAP_AnalyticDB].[dbo].[gap_landfire])

SELECT *
FROM tblWHRdB FULL JOIN tblAnalytic ON
     tblWHRdB.intLSGapMapCode = tblAnalytic.level3
ORDER BY value

-- Utilized map units within CONUS models in WHRdB
/*
591 mapunits utilized, identical overall list in both tblSppMapUnitPres and tblMapUnitDesc (region 1-6)

*/
WITH 
tblWHR_Pres AS (
	SELECT DISTINCT	intLSGapMapCode AS MapCode_Pres
	FROM    [WHRdB].[dbo].[tblSppMapUnitPres]
	WHERE  (substring([strSpeciesModelCode],9,1) >= 1 and 
			substring([strSpeciesModelCode],9,1) <= 6) and 
			(ysnPres = 1 OR ysnPresAuxiliary = 1)
	),
tblWHR_Desc AS (
	SELECT intLSGapMapCode AS MapCode_Desc, 
	       strLSGapName
	FROM [WHRdB].[dbo].[tblMapUnitDesc]
	WHERE ysnRegion1 = 1 OR
	      ysnRegion2 = 1 OR
	      ysnRegion3 = 1 OR
	      ysnRegion4 = 1 OR
	      ysnRegion5 = 1 OR
	      ysnRegion6 = 1
	)
SELECT *
FROM tblWHR_Pres FULL JOIN tblWHR_Desc ON
     MapCode_Pres = MapCode_Desc

/*
Join WHR_Pres and WHR_Desc by MapCode and Region
*/
-- generate region summaries from Pres table.  WHY ARE THEY ALL 590 OR 591 MAPUNITS?
WITH 
tblWHR_Pres1 AS (
	SELECT DISTINCT	intLSGapMapCode AS MapCode_Pres,
					substring([strSpeciesModelCode],9,1) AS Region_Pres
	FROM    [WHRdB].[dbo].[tblSppMapUnitPres]
	WHERE  substring([strSpeciesModelCode],9,1) = 1 and 
			(ysnPres = 1 OR ysnPresAuxiliary = 1)
	),
tblWHR_Pres2 AS (
	SELECT DISTINCT	intLSGapMapCode AS MapCode_Pres,
					substring([strSpeciesModelCode],9,1) AS Region_Pres
	FROM    [WHRdB].[dbo].[tblSppMapUnitPres]
	WHERE  substring([strSpeciesModelCode],9,1) =2 and 
			(ysnPres = 1 OR ysnPresAuxiliary = 1)
	),
tblWHR_Pres3 AS (
	SELECT DISTINCT	intLSGapMapCode AS MapCode_Pres,
					substring([strSpeciesModelCode],9,1) AS Region_Pres
	FROM    [WHRdB].[dbo].[tblSppMapUnitPres]
	WHERE  substring([strSpeciesModelCode],9,1) = 3 and 
			(ysnPres = 1 OR ysnPresAuxiliary = 1)
	),
tblWHR_Pres4 AS (
	SELECT DISTINCT	intLSGapMapCode AS MapCode_Pres,
					substring([strSpeciesModelCode],9,1) AS Region_Pres
	FROM    [WHRdB].[dbo].[tblSppMapUnitPres]
	WHERE  substring([strSpeciesModelCode],9,1) = 4 and 
			(ysnPres = 1 OR ysnPresAuxiliary = 1)
	),
tblWHR_Pres5 AS (
	SELECT DISTINCT	intLSGapMapCode AS MapCode_Pres,
					substring([strSpeciesModelCode],9,1) AS Region_Pres
	FROM    [WHRdB].[dbo].[tblSppMapUnitPres]
	WHERE  substring([strSpeciesModelCode],9,1) = 5 and 
			(ysnPres = 1 OR ysnPresAuxiliary = 1)
	),
tblWHR_Pres6 AS (
	SELECT DISTINCT	intLSGapMapCode AS MapCode_Pres,
					substring([strSpeciesModelCode],9,1) AS Region_Pres
	FROM    [WHRdB].[dbo].[tblSppMapUnitPres]
	WHERE  substring([strSpeciesModelCode],9,1) = 6 and 
			(ysnPres = 1 OR ysnPresAuxiliary = 1)
	),

tblWHR_Desc1 AS (
	SELECT intLSGapMapCode AS MapCode_Desc, 
	       strLSGapName,
		   (CAST(ysnRegion1 AS int) * 1) AS Region_Desc
	FROM [WHRdB].[dbo].[tblMapUnitDesc]
	WHERE ysnRegion1 = 1
	),
tblWHR_Desc2 AS (
	SELECT intLSGapMapCode AS MapCode_Desc, 
	       strLSGapName,
		   (CAST(ysnRegion2 AS int) * 2) AS Region_Desc
	FROM [WHRdB].[dbo].[tblMapUnitDesc]
	WHERE ysnRegion2 = 1
	),
tblWHR_Desc3 AS (
	SELECT intLSGapMapCode AS MapCode_Desc, 
	       strLSGapName,
		   (CAST(ysnRegion3 AS int) * 3) AS Region_Desc
	FROM [WHRdB].[dbo].[tblMapUnitDesc]
	WHERE ysnRegion3 = 1
	),
tblWHR_Desc4 AS (
	SELECT intLSGapMapCode AS MapCode_Desc, 
	       strLSGapName,
		   (CAST(ysnRegion4 AS int) * 4) AS Region_Desc
	FROM [WHRdB].[dbo].[tblMapUnitDesc]
	WHERE ysnRegion4 = 1
	),
tblWHR_Desc5 AS (
	SELECT intLSGapMapCode AS MapCode_Desc, 
	       strLSGapName,
		   (CAST(ysnRegion5 AS int) * 5) AS Region_Desc
	FROM [WHRdB].[dbo].[tblMapUnitDesc]
	WHERE ysnRegion5 = 1
	),
tblWHR_Desc6 AS (
	SELECT intLSGapMapCode AS MapCode_Desc, 
	       strLSGapName,
		   (CAST(ysnRegion6 AS int) * 6) AS Region_Desc
	FROM [WHRdB].[dbo].[tblMapUnitDesc]
	WHERE ysnRegion6 = 1
	)

SELECT * 
FROM tblWHR_Pres1 FULL JOIN tblWHR_Desc1 ON
	 MapCode_Pres = MapCode_Desc AND
	 Region_Pres = Region_Desc




-- Checking crosswalk of 19 GapVert_48_2001 mapunits not in 2011 landcover (AnalyticDB)
WITH
 tblMU_0 AS (
	SELECT p.intLSGapMapCode AS mu
		 , SUBSTRING(p.strSpeciesModelCode,1,6) AS uc
		 , p.strSpeciesModelCode AS smc
		 , p.ysnPres AS ysnPres_0
		 , p.ysnPresAuxiliary AS ysnPresAux_0
	FROM GapVert_48_2001.dbo.tblModelInfo i INNER JOIN 
	      GapVert_48_2001.dbo.tblSppMapUnitPres p ON
		   i.strSpeciesModelCode = p.strSpeciesModelCode INNER JOIN
          GapVert_48_2001.dbo.tblTaxa t ON
		   t.strUC = i.strUC
	WHERE t.ysnIncludeSpp = 1 AND
	      i.ysnIncludeSubModel = 1 AND
	      p.intLSGapMapCode = 3204
	      ),
 tblMU_1 AS (
	SELECT p.intLSGapMapCode AS mu_1
		 , SUBSTRING(p.strSpeciesModelCode,1,6) AS uc_1
		 , p.strSpeciesModelCode AS smc_1
		 , p.ysnPres AS ysnPres_1
		 , p.ysnPresAuxiliary AS ysnPresAux_1
	FROM GapVert_48_2001.dbo.tblModelInfo i INNER JOIN 
	      GapVert_48_2001.dbo.tblSppMapUnitPres p ON
		   i.strSpeciesModelCode = p.strSpeciesModelCode INNER JOIN
          GapVert_48_2001.dbo.tblTaxa t ON
		   t.strUC = i.strUC
	WHERE t.ysnIncludeSpp = 1 AND
	      i.ysnIncludeSubModel = 1 AND
	      p.intLSGapMapCode = 3206
	      )
SELECT uc
	  ,smc
	  ,mu
	  ,ysnPres_0
	  ,ysnPres_1
	  ,mu_1
	  ,ysnPresAux_0
	  ,ysnPresAux_1
FROM tblMU_0 INNER JOIN tblMU_1 ON 
	  smc = smc_1	  
WHERE ysnPres_0 <> ysnPres_1 OR
      ysnPresAux_0 <> ysnPresAux_1
