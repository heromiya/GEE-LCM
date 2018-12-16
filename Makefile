gt_$(GID).tif:
	EXTENT=`spatialite -silent $(OUTDB) "SELECT ST_MinX(ST_Collect(geometry)),ST_MinY(ST_Collect(geometry)),ST_MaxX(ST_Collect(geometry)),ST_MaxY(ST_Collect(geometry)) from gt where GID='$(GID)'"` && \
	XMIN=`echo $$EXTENT | cut -d '|' -f 1` && \
	YMIN=`echo $$EXTENT | cut -d '|' -f 2`  && \
	XMAX=`echo $$EXTENT | cut -d '|' -f 3`  && \
	YMAX=`echo $$EXTENT | cut -d '|' -f 4`  && \
	gdal_rasterize -te $$XMIN $$YMIN $$XMAX $$YMAX -a mc_id -l gt -where "GID='$(GID)'" -of GTiff -co COMPRESS=Deflate -a_nodata 255 -tr 0.00025 0.00025 -ot Byte $(OUTDB) $@
gt_$(GID).tmp: gt_$(GID).tif
	gdal_translate -of XYZ $< $@
gt_$(GID).csv: gt_$(GID).tmp
	echo "x,y,mc_id" > $@
	for MC_ID in 1 2 3 4; do awk -v mc_id=$$MC_ID '$$3 == mc_id {print rand(),$$0}' $< | sort -k 1 | head -n 512 | awk 'BEGIN{OFS=","}{print $$2,$$3,$$4}' >> $@; done
gt_$(GID).vrt:
	echo "<OGRVRTDataSource><OGRVRTLayer name='gt_$(GID)'><SrcDataSource>gt_$(GID).csv</SrcDataSource><GeometryType>wkbPoint</GeometryType><LayerSRS>WGS84</LayerSRS><GeometryField encoding='PointFromColumns' x='x' y='y'/></OGRVRTLayer></OGRVRTDataSource>" > $@
gt_$(GID).shp: gt_$(GID).vrt gt_$(GID).csv
	rm -f $@
	ogr2ogr $@ $<
