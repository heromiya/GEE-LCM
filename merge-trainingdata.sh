#! /bin/bash

export NSAMPLE=1000 # Number of sample per class in a scene.

# For Windows with OSGeo4W64 and Git Bash
if [ $OS = 'Windows_NT' ]; then 
    export PYTHONPATH=/c/OSGeo4W64/apps/Python37/Lib
    export PATH=$PATH:/c/OSGeo4W64/bin
    export PATH=$PATH:`pwd`
    export GRASS=/c/OSGeo4W64/bin/grass78.bat
else
    export GRASS=grass78
fi

export WORKDIR=$(mktemp -d)
export OUTDB=$WORKDIR/tmp.sqlite
SCPDIR="SCP-shapefiles"
#:<<'#EOF'

rm -f $OUTDB
SQL=$WORKDIR/tmp.sql
echo "DELETE FROM geometry_columns WHERE f_table_name = 'gt' OR  f_table_name = 'pt_gt'; DROP TABLE IF EXISTS gt; CREATE TABLE gt AS" > $SQL

for SHP in `ls $SCPDIR | grep shp$ | sed 's/\.shp//g'; do
    TBL=$(echo $SHP | sed 's/-.*//g' | tr A-Z a-z | sed 's/-//g')
    GID=$(echo $SHP | sed -e "s/\(L.\{24\}\).*/\1/g; s/-//g")
    PROJ="$(cat $SCPDIR/$SHP.prj)"
    EPSG=$(python3 identifyEPSG.py "$PROJ")
    spatialite -silent $OUTDB ".loadshp $SCPDIR/$SHP $TBL UTF-8 $EPSG geometry" 
    printf "SELECT ST_Transform(GEOMETRY,4326) as geometry,MC_ID as mc_id,'$GID' AS GID FROM $TBL UNION ALL " >> $SQL
done

echo "; INSERT INTO geometry_columns VALUES ('gt','geometry',3,2,4326,0);" >> $SQL
sed -i 's/UNION ALL ;/;/' $SQL
spatialite -silent $OUTDB < $SQL

spatialite -silent $OUTDB ".loadshp 'past/Danworks' danworks UTF-8 32648 geometry"
spatialite -silent $OUTDB "INSERT INTO gt (geometry,mc_id,gid) SELECT ST_Transform(geometry,4326), mc_id, gid from danworks; SELECT CreateSpatialIndex('gt','geometry');"


mkdir -p pointize
f_pointize() {
    export GID=$1
    export WORKDIR_P=$(mktemp -d)
    make -C pointize -f $PWD/Makefile gt_${GID}_1.gpkg gt_${GID}_2.gpkg gt_${GID}_3.gpkg gt_${GID}_4.gpkg
    #mv $WORKDIR_P/gt_$GID.* pointize/
#    rm -rf $WORKDIR_P
}
export -f f_pointize

parallel --version
if [ $? -eq 0 ]; then
    parallel --bar f_pointize ::: `spatialite $OUTDB "SELECT gid from gt group by gid;"`
else 
    for GID in `spatialite $OUTDB "SELECT gid from gt group by gid;" | sed 's/\r//g'`; do 
        f_pointize $GID
    done
fi

#EOF

rm -f gt-pt.*
for GPKG in pointize/*.gpkg ; do
    LAYER=$(ogrinfo $GPKG | grep Point | awk '{print $2}')
    ogr2ogr -append -sql "SELECT geom, '`echo $LAYER | sed 's/gt_//g'`' as gid, cast(value as integer) as class, cast(`echo $LAYER | sed 's/gt_L[CETM][0-9]\{2\}_[A-Z0-9]\{4\}_[0-9]\{6\}_\([0-9]\{4\}\)[0-9]\{4\}/\1/; s/gt_L[CET][0-9]\{7\}\([0-9]\{4\}\).*/\1/; s/gt_L[CET][0-9]._\([0-9]\{4\}\).*/\1/;'` as integer) AS year from $LAYER" gt-pt.shp $GPKG $LAYER
done
