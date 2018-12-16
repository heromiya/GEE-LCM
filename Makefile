gt_$(GID).tif:
	EXTENT=`ogrinfo -where "GID='$(GID)'" $(OUTDB) gt -al -summary | grep Extent` && \
	XMIN=`echo $$EXTENT | sed 's/Extent: (\([-.0-9].*\), \([-.0-9].*\)) - (\([-.0-9].*\), \([-.0-9].*\))/\1/g'` && \
	YMIN=`echo $$EXTENT | sed 's/Extent: (\([-.0-9].*\), \([-.0-9].*\)) - (\([-.0-9].*\), \([-.0-9].*\))/\2/g'` && \
	XMAX=`echo $$EXTENT | sed 's/Extent: (\([-.0-9].*\), \([-.0-9].*\)) - (\([-.0-9].*\), \([-.0-9].*\))/\3/g'` && \
	YMAX=`echo $$EXTENT | sed 's/Extent: (\([-.0-9].*\), \([-.0-9].*\)) - (\([-.0-9].*\), \([-.0-9].*\))/\4/g'` && \
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
