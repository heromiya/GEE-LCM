gt_$(GID).tif:
	EXTENT=`spatialite -silent $(OUTDB) "SELECT ST_MinX(ST_Collect(geometry)),ST_MinY(ST_Collect(geometry)),ST_MaxX(ST_Collect(geometry)),ST_MaxY(ST_Collect(geometry)) from gt where GID='$(GID)'"` && \
	XMIN=`echo $$EXTENT | cut -d '|' -f 1` && \
	YMIN=`echo $$EXTENT | cut -d '|' -f 2`  && \
	XMAX=`echo $$EXTENT | cut -d '|' -f 3`  && \
	YMAX=`echo $$EXTENT | cut -d '|' -f 4`  && \
	gdal_rasterize -te $$XMIN $$YMIN $$XMAX $$YMAX -a mc_id -l gt -where "GID='$(GID)'" -of GTiff -co COMPRESS=Deflate -a_nodata 255 -tr $(RES) $(RES) -ot Byte $(OUTDB) $@
gt_$(GID)_1.gpkg: gt_$(GID).tif #gt_$(GID).vrt gt_$(GID).csv
	rm -f $@
	N_MAX=`gdalinfo -hist $< | grep bucket -A 1 | tail -n 1 | sed 's/^ *//g' | cut -f 2 -d " "`; if [ $$N_MAX -lt $(NSAMPLE_1) ]; then N=$$N_MAX; else N=$(NSAMPLE_1); fi; printf "r.in.gdal input=gt_$(GID).tif output=gt_$(GID) --overwrite \ng.region raster=gt_$(GID) \nr.null map=gt_$(GID) setnull=2,3,4 \nr.random input=gt_$(GID) npoint=$$N vector=gt_$(GID)_1 seed=777 --overwrite \nv.out.ogr input=gt_$(GID)_1 output=gt_$(GID)_1.gpkg format=GPKG --overwrite" > $(GID)_1.sh
	chmod u+x $(GID)_1.sh
	TMPLOCATION=`mktemp -d grass-XXXXX` && \
	$(GRASS) -c EPSG:4326 $$TMPLOCATION/PERMANENT --exec $(GRASS_EXEC) `pwd`/$(GID)_1.sh && \
	rm -rf $$TMPLOCATION

gt_$(GID)_2.gpkg: gt_$(GID).tif
	rm -f $@
	N_MAX=`gdalinfo -hist $< | grep bucket -A 1 | tail -n 1 | sed 's/^ *//g' | cut -f 3 -d " "`; if [ $$N_MAX -lt $(NSAMPLE_2) ]; then N=$$N_MAX; else N=$(NSAMPLE_2); fi; printf "r.in.gdal input=gt_$(GID).tif output=gt_$(GID) --overwrite \ng.region raster=gt_$(GID) \nr.null map=gt_$(GID) setnull=1,3,4 \nr.random input=gt_$(GID) npoint=$$N vector=gt_$(GID)_2 seed=777 --overwrite \nv.out.ogr input=gt_$(GID)_2 output=gt_$(GID)_2.gpkg format=GPKG --overwrite" > $(GID)_2.sh
	chmod u+x $(GID)_2.sh
	TMPLOCATION=`mktemp -d grass-XXXXX` && \
	$(GRASS) -c EPSG:4326 $$TMPLOCATION/PERMANENT --exec $(GRASS_EXEC) `pwd`/$(GID)_2.sh && \
	rm -rf $$TMPLOCATION

gt_$(GID)_3.gpkg: gt_$(GID).tif
	rm -f $@
	N_MAX=`gdalinfo -hist $< | grep bucket -A 1 | tail -n 1 | sed 's/^ *//g' | cut -f 4 -d " "`; if [ $$N_MAX -lt $(NSAMPLE_3) ]; then N=$$N_MAX; else N=$(NSAMPLE_3); fi; printf "r.in.gdal input=gt_$(GID).tif output=gt_$(GID) --overwrite \ng.region raster=gt_$(GID) \nr.null map=gt_$(GID) setnull=1,2,4 \nr.random input=gt_$(GID) npoint=$$N vector=gt_$(GID)_3 seed=777 --overwrite \nv.out.ogr input=gt_$(GID)_3 output=gt_$(GID)_3.gpkg format=GPKG --overwrite" > $(GID)_3.sh
	chmod u+x $(GID)_3.sh
	TMPLOCATION=`mktemp -d grass-XXXXX` && \
	$(GRASS) -c EPSG:4326 $$TMPLOCATION/PERMANENT --exec $(GRASS_EXEC) `pwd`/$(GID)_3.sh && \
	rm -rf $$TMPLOCATION

gt_$(GID)_4.gpkg: gt_$(GID).tif
	rm -f $@
	N_MAX=`gdalinfo -hist $< | grep bucket -A 1 | tail -n 1 | sed 's/^ *//g' | cut -f 5 -d " "`; if [ $$N_MAX -lt $(NSAMPLE_4) ]; then N=$$N_MAX; else N=$(NSAMPLE_4); fi; printf "r.in.gdal input=gt_$(GID).tif output=gt_$(GID) --overwrite \ng.region raster=gt_$(GID) \nr.null map=gt_$(GID) setnull=1,2,3 \nr.random input=gt_$(GID) npoint=$$N vector=gt_$(GID)_4 seed=777 --overwrite \nv.out.ogr input=gt_$(GID)_4 output=gt_$(GID)_4.gpkg format=GPKG --overwrite" > $(GID)_4.sh
	chmod u+x $(GID)_4.sh
	TMPLOCATION=`mktemp -d grass-XXXXX` && \
	$(GRASS) -c EPSG:4326 $$TMPLOCATION/PERMANENT --exec $(GRASS_EXEC) `pwd`/$(GID)_4.sh && \
	rm -rf $$TMPLOCATION


###########################################
gt_$(GID).tmp: gt_$(GID).tif
	gdal_translate -of XYZ $< $@
gt_$(GID).csv: gt_$(GID).tmp
	echo "x,y,mc_id" > $@
	for MC_ID in 1 2 3 4; do awk -v mc_id=$$MC_ID '$$3 == mc_id {print rand(),$$0}' $< | sort -k 1 | head -n $(NSAMPLE) | awk 'BEGIN{OFS=","}{print $$2,$$3,$$4}' >> $@; done
gt_$(GID).vrt:
	echo "<OGRVRTDataSource><OGRVRTLayer name='gt_$(GID)'><SrcDataSource>gt_$(GID).csv</SrcDataSource><GeometryType>wkbPoint</GeometryType><LayerSRS>WGS84</LayerSRS><GeometryField encoding='PointFromColumns' x='x' y='y'/></OGRVRTLayer></OGRVRTDataSource>" > $@
