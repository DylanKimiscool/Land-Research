# Yakima public parcel snapshot exported from QGIS on 2026-09-26.
# Keep this input unchanged. Run the script from the project root.
source_path <- 'data/raw/wa_parcels_2026_yakima_ag.gpkg'
source_layer <- 'parcels_2026'
county_field <- 'FIPS_NR'
parcel_field <- 'PARCEL_ID_NR'
landuse_field <- 'LANDUSE_CD'
row_id_field <- 'OBJECTID'
ag_codes <- c('81', '83') # provisional; confirm classification with Dr. Cook
