# Export a small local QGIS layer from Ecology's matched place-of-use shapes.
# Run from the project root: source('R/05_export_pou_pilot_map.R')
# Polygons are mapped areas, not owners or distinct legal rights.

if (!requireNamespace('sf', quietly = TRUE) ||
    !requireNamespace('jsonlite', quietly = TRUE)) {
  stop('Install sf and jsonlite first.')
}
attributes_path <- 'outputs/ecology_pou_pilot_polygon_attributes.csv'
if (!file.exists(attributes_path)) stop('Run script 04 first.')
attributes <- utils::read.csv(attributes_path, stringsAsFactors = FALSE)
required <- c('OBJECTID', 'WR_DOC_ID', 'WR_Doc_NR')
if (!all(required %in% names(attributes))) stop('Missing pilot attribute fields.')
ids <- sort(as.integer(attributes$OBJECTID))
if (!length(ids) || anyNA(ids) || anyDuplicated(ids)) {
  stop('Expected unique, numeric polygon OBJECTIDs.')
}

service <- 'https://services.arcgis.com/6lCKYNJLvwTXqrmp/arcgis/rest/services/WR/FeatureServer/6'
raw_dir <- 'data/raw/ecology_pou_map_pilot'
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create('data/derived', recursive = TRUE, showWarnings = FALSE)
dir.create('outputs', recursive = TRUE, showWarnings = FALSE)
chunks <- split(ids, ceiling(seq_along(ids) / 15L))
maps <- vector('list', length(chunks))
urls <- character(length(chunks))

for (i in seq_along(chunks)) {
  urls[i] <- paste0(service, '/query?f=geojson&objectIds=',
                    paste(chunks[[i]], collapse = ','),
                    '&outFields=OBJECTID,WR_DOC_ID,WR_Doc_NR',
                    '&outSR=4326&returnGeometry=true')
  raw_path <- file.path(raw_dir, sprintf('geometry_batch_%02d.geojson', i))
  if (!file.exists(raw_path) || file.info(raw_path)$size == 0L) {
    utils::download.file(urls[i], raw_path, mode = 'wb', quiet = TRUE)
  }
  payload <- jsonlite::fromJSON(raw_path, simplifyVector = FALSE)
  if (!is.null(payload$error)) {
    stop('Ecology service error in ', raw_path, ': ', payload$error$message)
  }
  if (!identical(payload$type, 'FeatureCollection') ||
      length(payload$features) != length(chunks[[i]])) {
    stop('Incomplete GeoJSON batch; inspect ', raw_path)
  }
  maps[[i]] <- sf::st_read(raw_path, quiet = TRUE)
  if (!'OBJECTID' %in% names(maps[[i]]) ||
      !setequal(as.integer(maps[[i]]$OBJECTID), chunks[[i]])) {
    stop('Unexpected polygon OBJECTIDs in ', raw_path)
  }
}

map <- do.call(rbind, maps)
if (nrow(map) != length(ids) || anyDuplicated(map$OBJECTID) ||
    !setequal(as.integer(map$OBJECTID), ids) || any(sf::st_is_empty(map))) {
  stop('Map identity or geometry check failed.')
}
if (is.na(sf::st_crs(map)) || sf::st_crs(map)$epsg != 4326) {
  stop('Expected GeoJSON geometry in EPSG:4326.')
}
source_index <- match(as.integer(map$OBJECTID), as.integer(attributes$OBJECTID))
if (anyNA(source_index) ||
    !identical(as.character(map$WR_DOC_ID),
               as.character(attributes$WR_DOC_ID[source_index]))) {
  stop('Map document IDs differ from pilot attribute snapshot.')
}

output_path <- 'data/derived/ecology_pou_pilot_29.gpkg'
sf::st_write(map, output_path, layer = 'pilot_pou',
             delete_dsn = file.exists(output_path), quiet = TRUE)
writeLines(c(
  paste('Retrieved UTC:', format(Sys.time(), tz = 'UTC', usetz = TRUE)),
  paste('Source service:', service),
  paste('Input attributes:', attributes_path),
  paste('Feature count:', nrow(map)),
  paste('Distinct document IDs:', length(unique(map$WR_DOC_ID))),
  paste('CRS:', sf::st_crs(map)$input),
  'Selection is the exact set of polygon OBJECTIDs saved by script 04.',
  'GeoJSON batches are preserved in data/raw/ecology_pou_map_pilot.',
  paste('Query URLs:', paste(urls, collapse = ' ; ')),
  'WR_Doc_POU_ID is blank in the pilot attributes; OBJECTID is the map feature key.',
  'A polygon is a mapped place of use, not proof of a legal holder or parcel owner.',
  'No geometry-to-parcel or ownership join was performed.'
), 'outputs/ecology_pou_pilot_map_provenance.txt')
cat('Saved ', nrow(map), ' mapped features to ', output_path,
    ' (', length(unique(map$WR_DOC_ID)), ' document IDs).\n', sep = '')
