#! /bin/bash

P129R051Y2016=LC81290512016103LGN00-HM-bk-170928
P129R050Y2016=LC81290502016103LGN00-HM
OUTDB=tmp.sqlite
SCPDIR=SCP-shapefiles

#ogr2ogr -f SQLite $OUTDB pt480.shp -nln pt480
#ogr2ogr -update -f SQLite $OUTDB $SCPDIR/$P129R051Y2016.shp -nln p129r51y2016
#ogr2ogr -update -f SQLite $OUTDB $SCPDIR/$P129R050Y2016.shp -nln p129r50y2016

./spatialite $OUTDB <<EOS
.loadshp $SCPDIR/$P129R051Y2016 p129r51y2016 UTF-8 with_spatial_index
.loadshp $SCPDIR/$P129R050Y2016 p129r50y2016 UTF-8 with_spatial_index
--.loadshp pt480 pt480 UTF-8  with_spatial_index 

DELETE FROM geometry_columns WHERE  f_table_name = 'gt' OR  f_table_name = 'pt_gt';
DROP TABLE IF EXISTS gt;
CREATE TABLE gt AS
SELECT 
GEOMETRY,

CASE
 WHEN mc_id = 1 THEN 1
 WHEN mc_id = 2 THEN 2
 WHEN mc_id = 4 THEN 3
 WHEN mc_id = 3 THEN 4
 WHEN mc_id = 5 THEN 5
END AS class,

'LC81290512016103LGN00' AS GID

FROM p129r51y2016

UNION ALL SELECT 
GEOMETRY,

CASE
 WHEN mc_id = 1 THEN 1
 WHEN mc_id = 3 THEN 2
 WHEN mc_id = 5 THEN 3
 WHEN mc_id = 4 THEN 4
 WHEN mc_id = 2 THEN 5
END AS class,

'LC81290502016103LGN00' AS GID

FROM p129r50y2016
;

INSERT INTO geometry_columns VALUES ('gt','GEOMETRY',3,2,32647,'WKB');

DROP TABLE IF EXISTS pt_gt;
CREATE TABLE pt_gt AS 
SELECT pt480.GEOMETRY
,gt.class
,gt.year
FROM pt480, gt
WHERE ST_Intersects(gt.GEOMETRY, pt480.GEOMETRY);
INSERT INTO geometry_columns VALUES ('pt_gt','GEOMETRY',3,2,32647,'WKB');
EOS
