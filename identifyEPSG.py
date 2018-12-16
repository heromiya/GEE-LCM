import sys
from osgeo import osr

args = sys.argv
srsWkt = args[1]

# Load in the projection WKT
sr = osr.SpatialReference(srsWkt)

# Try to determine the EPSG/SRID code
res = sr.AutoIdentifyEPSG()
if res == 0: # success
    print(sr.GetAuthorityCode(None))
    # SRID=4269
else:
    print('Could not determine SRID')
