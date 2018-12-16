#! /bin/bash

export OUTDB=/dev/shm/tmp.sqlite
SCPDIR="`pwd`/SCP-shapefiles"

rm -f $OUTDB

SQL=tmp.sql
echo "DELETE FROM geometry_columns WHERE  f_table_name = 'gt' OR  f_table_name = 'pt_gt'; DROP TABLE IF EXISTS gt; CREATE TABLE gt AS" > $SQL

for SHP in `ls $SCPDIR | grep shp$ | sed 's/\.shp//g'`; do
	TBL=$(echo $SHP | sed 's/-.*//g' | tr A-Z a-z | sed 's/-//g')
	GID=$(echo $SHP | sed -e "s/\(L.\{24\}\).*/\1/g; s/-//g")
	PROJ="$(cat $SCPDIR/$SHP.prj)"
	EPSG=$(python identifyEPSG.py "$PROJ")
	spatialite -silent $OUTDB ".loadshp $SCPDIR/$SHP $TBL UTF-8 $EPSG geometry" 
	printf "SELECT ST_Transform(GEOMETRY,4326) as geometry,MC_ID as mc_id,'$GID' AS GID FROM $TBL UNION ALL " >> $SQL
done

echo "; INSERT INTO geometry_columns VALUES ('gt','geometry',3,2,4326,0);" >> $SQL
sed -i 's/UNION ALL ;/;/' $SQL
spatialite -silent $OUTDB < $SQL

spatialite -silent $OUTDB ".loadshp 'past/Danworks' danworks UTF-8 32648 geometry"
spatialite -silent $OUTDB "INSERT INTO gt (geometry,mc_id,gid) SELECT ST_Transform(geometry,4326), mc_id, gid from danworks; SELECT CreateSpatialIndex('gt','geometry');"

#:<<'#EOF'

mkdir pointize
cd pointize
for GID in `spatialite $OUTDB "SELECT gid from gt group by gid;"`; do 
	export GID
	make -f ../Makefile gt_$GID.shp
done
cd ..

rm -f gt-pt.*
for LAYER in `ogrinfo pointize | grep Point | awk '{print $2}'`; do
	ogr2ogr -append -sql "SELECT '`echo $LAYER | sed 's/gt_//g'`' as gid, cast(mc_id as integer) as class, cast(`echo $LAYER | sed -e 's/gt_.*\([12][089][0-9][0-9]\).*/\1/g' -e 's/.*_.*_.*_\([0-9]...\)[0-9].../\1/g'` as integer) AS year from $LAYER" gt-pt.shp pointize $LAYER
done
#EOF
