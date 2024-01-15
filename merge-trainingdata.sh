#! /bin/bash

OPT=`getopt -o b:e:r:1:2:3:4: -l pmin:,pmax:,rmin:,rmax: -- "$@"`
eval set -- "$OPT"

while true
do
    case $1 in
        -b) export YEAR_BEGIN=$2;;
        -e) export YEAR_END=$2;;
        -r) export RES=$2;;
        -1) export NSAMPLE_1=$2;;
        -2) export NSAMPLE_2=$2;;
        -3) export NSAMPLE_3=$2;;
        -4) export NSAMPLE_4=$2;;
        --pmax) export PMAX=$2;;        
        --pmin) export PMIN=$2;;        
        --rmax) export RMAX=$2;;        
        --rmin) export RMIN=$2;;
        --) shift
            break
            ;;
    esac
    shift 2
done

:<<"#EOF"
export YEAR_BEGIN=$1
export YEAR_END=$2
export RES=$3
export NSAMPLE_1=$4 # Number of sample per class in a scene.
export NSAMPLE_2=$5
export NSAMPLE_3=$6
export NSAMPLE_4=$7
#EOF

if [ -z "$NSAMPLE_4" ]; then
    echo "Number of samples for 4 classes are not provided. $NSAMPLE_1 is applied to all classes."
    export NSAMPLE_2=$NSAMPLE_1
    export NSAMPLE_3=$NSAMPLE_1
    export NSAMPLE_4=$NSAMPLE_1
fi

# For Windows with OSGeo4W64 and Git Bash. Requiring "gdal-full" in OSGeo4W.
if [ "$OS" = 'Windows_NT' ]; then 
    export PYTHONPATH=/c/OSGeo4W64/apps/Python37/Lib
    export PATH=$PATH:/c/OSGeo4W64/bin
    export PATH=$PATH:`pwd`
    export GRASS=/c/OSGeo4W64/bin/grass78.bat
else
    export GRASS=grass
    export GRASS_EXEC=sh
fi

export WORKDIR=$(mktemp -d)
export OUTDB=$WORKDIR/tmp.sqlite
SCPDIR="SCP-shapefiles"

rm -f $OUTDB
SQL=$WORKDIR/tmp.sql
echo "DELETE FROM geometry_columns WHERE f_table_name = 'gt' OR  f_table_name = 'pt_gt'; DROP TABLE IF EXISTS gt; CREATE TABLE gt AS" > $SQL

for SHP in `find $SCPDIR -type f -regex ".*shp$" | sed 's/\.shp//g'`; do
    YEAR=$(echo $SHP | sed "s/$SCPDIR\/L[CETM][0-9]\{2\}_[A-Z0-9]\{4\}_[0-9]\{6\}_\([0-9]\{4\}\).*/\1/; s/$SCPDIR\/L[CET][0-9]\{7\}\([0-9]\{4\}\).*/\1/; s/$SCPDIR\/L[CET][0-9]._\([0-9]\{4\}\).*/\1/;")
    P=$(echo $SHP | sed "s/$SCPDIR\/L[CETM][0-9]\{2\}_[A-Z0-9]\{4\}_\([0-9]\{3\}\)\([0-9]\{3\}\)_\([0-9]\{4\}\).*/\1/g; s/$SCPDIR\/L[CET][0-9]\([0-9]\{3\}\)\([0-9]\{3\}\)\([0-9]\{4\}\).*/\1/;")
    R=$(echo $SHP | sed "s/$SCPDIR\/L[CETM][0-9]\{2\}_[A-Z0-9]\{4\}_\([0-9]\{3\}\)\([0-9]\{3\}\)_\([0-9]\{4\}\).*/\2/g; s/$SCPDIR\/L[CET][0-9]\([0-9]\{3\}\)\([0-9]\{3\}\)\([0-9]\{4\}\).*/\2/;")
    if [ $YEAR -ge $YEAR_BEGIN -a $YEAR -le $YEAR_END -a $P -ge $PMIN -a $P -le $PMAX -a $R -ge $RMIN -a $R -le $RMAX ]; then
        TBL=$(echo $(basename $SHP) | tr A-Z a-z | sed 's/-/_/g') # | sed 's/-.*//g'
        GID=$(echo $(basename $SHP) | sed -e "s/-/_/g") # s/\(L.\{24\}\).*/\1/g; 
        PROJ="$(cat $SHP.prj)"
        EPSG=$(python identifyEPSG.py "$PROJ")
	ogr2ogr -append -f SQLite -dsco SPATIALITE=YES -nlt PROMOTE_TO_MULTI $OUTDB $SHP.shp # -select MC_ID,C_ID,SCP_UID  $WORKDIR/$(basename $SHP.shp) $SHP.shp
        #spatialite -silent $OUTDB ".loadshp $WORKDIR/$(basename $SHP) $TBL UTF-8 $EPSG geometry"
        printf "SELECT ST_Transform(GEOMETRY,4326) as geometry,MC_ID as mc_id,'$GID' AS GID FROM ${TBL} UNION ALL " >> $SQL
    fi
done

echo "; INSERT INTO geometry_columns VALUES ('gt','geometry',3,2,4326,0);" >> $SQL
sed -i 's/UNION ALL ;/;/' $SQL
spatialite -silent $OUTDB < $SQL

spatialite -silent $OUTDB ".loadshp 'past/Danworks' danworks UTF-8 32648 geometry"
spatialite -silent $OUTDB "INSERT INTO gt (geometry,mc_id,gid) SELECT ST_Transform(geometry,4326), mc_id, gid from danworks; SELECT CreateSpatialIndex('gt','geometry');"


mkdir -p pointize
f_pointize() {
    export GID=$1
    make -C pointize -f $PWD/Makefile gt_${GID}_1.gpkg gt_${GID}_2.gpkg gt_${GID}_3.gpkg gt_${GID}_4.gpkg
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

rm -f gt-pt.*
for GPKG in pointize/*.gpkg ; do
    LAYER=$(ogrinfo $GPKG | grep Point | awk '{print $2}')
    GID=$(echo $LAYER | sed 's/gt_//g')
    #YEAR=$(echo $LAYER | sed 's/gt_L[CETM][0-9]\{2\}_[A-Z0-9]\{4\}_[0-9]\{6\}_\([0-9]\{4\}\)[0-9]\{4\}_[0-9]/\1/; s/gt_L[CET][0-9]\{7\}\([0-9]\{4\}\).*/\1/; s/gt_L[CET][0-9]._\([0-9]\{4\}\).*/\1/;')
    YEAR=$(echo $LAYER | sed 's/gt_L[CETM][0-9]\{2\}_[A-Z0-9]\{4\}_[0-9]\{6\}_\([0-9]\{4\}\).*/\1/; s/gt_L[CET][0-9]\{7\}\([0-9]\{4\}\).*/\1/; s/gt_L[CET][0-9]._\([0-9]\{4\}\).*/\1/;')
    if [ -z "$(echo $GID | grep L[CETM][0-9][0-9]_)" ]; then
	DOY=$(echo $GID | sed 's/L[CETM][0-9]\{11\}\([0-9]\{3\}\).*/\1/g')
	MONTH=$(date +%m -d "1 Jan $YEAR $(expr $DOY - 1) days")
	DAY=$(date +%d -d "1 Jan $YEAR $(expr $DOY - 1) days")
    else
	MONTH=$(echo $GID | sed 's/L[CETM][0-9]\{2\}_[0-9]\{4\}\([0-9]\{2\}\).*/\1/g; s/L[CETM][0-9]\{2\}_[A-Z0-9]\{4\}_[0-9]\{6\}_[0-9]\{4\}\([0-9]\{2\}\).*/\1/g;' | sed 's/^0//g')
	DAY=$(echo $GID | sed 's/L[CETM][0-9]\{2\}_[0-9]\{4\}[0-9]\{2\}\([0-9]\{2\}\).*/\1/g; s/L[CETM][0-9]\{2\}_[A-Z0-9]\{4\}_[0-9]\{6\}_[0-9]\{4\}[0-9]\{2\}\([0-9]\{2\}\).*/\1/g;' | sed 's/^0//g')
	DOY=$(date --date="$(printf %04d-%02d-%02d $YEAR $MONTH $DAY)" +%j)
    fi
    ogr2ogr -append -sql "SELECT geom, '$GID' as gid, cast(value as integer) as class, cast($YEAR as integer) AS year, cast($MONTH as integer) AS month, cast($DAY as integer) AS day, cast($DOY as integer) AS doy from $LAYER" gt-pt.shp $GPKG $LAYER

done
zip gt-pt.zip gt-pt.shp gt-pt.dbf gt-pt.shx gt-pt.prj
