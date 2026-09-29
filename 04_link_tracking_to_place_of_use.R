# Pilot link between sampled tracking rows and Ecology place-of-use records.
# Run from project root after 03: source('R/04_link_tracking_to_place_of_use.R')
# A mapped place of use is neither proof of parcel ownership nor a unique right.

if (!requireNamespace('jsonlite', quietly = TRUE)) {
  stop('Install jsonlite first: install.packages("jsonlite")')
}

tracking_path <- 'outputs/ecology_tracking_random1000.csv'
if (!file.exists(tracking_path)) stop('Run 03_random_tracking_sample.R first.')
tracking <- utils::read.csv(tracking_path, stringsAsFactors = FALSE)
needed <- c('OBJECTID', 'WR_Doc_ID', 'WaRecProcessStatusTypeCode',
            'PurposeOfUseTypeCodes', 'PersonLastOrOrganizationNM', 'PriorityDate')
if (!all(needed %in% names(tracking))) stop('Tracking sample is missing required columns.')

is_ir <- !is.na(tracking$PurposeOfUseTypeCodes) &
  grepl('(^|[[:space:]])IR([[:space:]]|$)', tracking$PurposeOfUseTypeCodes)
eligible <- tracking[!is.na(tracking$WaRecProcessStatusTypeCode) &
                     tracking$WaRecProcessStatusTypeCode == 'Active' & is_ir, ]
eligible <- eligible[!is.na(eligible$WR_Doc_ID) &
                     grepl('^[0-9]+$', eligible$WR_Doc_ID), ]
eligible <- eligible[!duplicated(eligible$WR_Doc_ID), ]
pilot <- head(eligible, 30L)
if (!nrow(pilot)) stop('No valid active IR document IDs in the saved sample.')

raw_dir <- 'data/raw/ecology_pou_link_pilot'
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create('outputs', recursive = TRUE, showWarnings = FALSE)
selection_path <- file.path(raw_dir, 'selected_doc_ids.csv')
if (file.exists(selection_path)) {
  previous <- utils::read.csv(selection_path, colClasses = 'character')$WR_Doc_ID
  if (!identical(previous, as.character(pilot$WR_Doc_ID))) {
    stop('Existing pilot ID selection differs. Preserve the old snapshot before rerunning.')
  }
} else {
  utils::write.csv(data.frame(WR_Doc_ID = as.character(pilot$WR_Doc_ID)),
                   selection_path, row.names = FALSE)
}

service <- 'https://services.arcgis.com/6lCKYNJLvwTXqrmp/arcgis/rest/services/WR/FeatureServer/6'
fetch <- function(url, path) {
  if (!file.exists(path) || file.info(path)$size == 0L) {
    utils::download.file(url, path, mode = 'wb', quiet = TRUE)
  }
  response <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (!is.null(response$error)) stop('Service error in ', path, ': ', response$error$message)
  response
}

# Ask for IDs first so a server transfer limit cannot silently omit polygons.
where <- paste0('WR_DOC_ID IN (', paste(pilot$WR_Doc_ID, collapse = ','), ')')
ids_url <- paste0(service, '/query?f=json&returnIdsOnly=true&where=',
                  utils::URLencode(where, reserved = TRUE))
ids_response <- fetch(ids_url, file.path(raw_dir, 'matching_polygon_ids.json'))
object_ids <- sort(unique(as.integer(unlist(ids_response$objectIds, use.names = FALSE))))
if (anyNA(object_ids)) stop('Invalid polygon IDs returned; inspect the saved JSON.')

fields <- c('OBJECTID', 'WR_DOC_ID', 'WR_Doc_POU_ID', 'WR_Doc_NR')
get_field <- function(feature, field) {
  value <- feature$attributes[[field]]
  if (is.null(value) || !length(value)) return(NA_character_)
  as.character(value)
}
parts <- list()
if (length(object_ids)) {
  chunks <- split(object_ids, ceiling(seq_along(object_ids) / 100L))
  for (i in seq_along(chunks)) {
    url <- paste0(service, '/query?f=json&returnGeometry=false&objectIds=',
                  paste(chunks[[i]], collapse = ','),
                  '&outFields=', paste(fields, collapse = ','))
    path <- file.path(raw_dir, sprintf('polygon_attributes_%03d.json', i))
    response <- fetch(url, path)
    features <- response$features
    if (length(features) != length(chunks[[i]]) || isTRUE(response$exceededTransferLimit)) {
      stop('Incomplete polygon batch; inspect ', path)
    }
    part <- as.data.frame(lapply(fields, function(field) {
      vapply(features, get_field, character(1), field = field)
    }), stringsAsFactors = FALSE)
    names(part) <- fields
    if (!setequal(as.integer(part$OBJECTID), chunks[[i]])) {
      stop('Unexpected polygon OBJECTIDs in ', path)
    }
    parts[[i]] <- part
  }
}
polygons <- if (length(parts)) do.call(rbind, parts) else {
  setNames(as.data.frame(matrix(character(0), nrow = 0, ncol = length(fields))), fields)
}
if (anyDuplicated(polygons$OBJECTID) ||
    !all(polygons$WR_DOC_ID %in% pilot$WR_Doc_ID)) {
  stop('Polygon identity check failed; inspect saved responses.')
}
utils::write.csv(polygons, 'outputs/ecology_pou_pilot_polygon_attributes.csv',
                 row.names = FALSE, na = '')

# One summary row per sampled document; zero means no polygon found in this layer.
counts <- table(polygons$WR_DOC_ID)
pilot$mapped_pou_feature_count <- as.integer(counts[as.character(pilot$WR_Doc_ID)])
pilot$mapped_pou_feature_count[is.na(pilot$mapped_pou_feature_count)] <- 0L
utils::write.csv(pilot, 'outputs/ecology_pou_pilot_document_summary.csv',
                 row.names = FALSE, na = '')
writeLines(c(
  paste('Retrieved UTC:', format(Sys.time(), tz = 'UTC', usetz = TRUE)),
  paste('Service:', service), paste('IDs URL:', ids_url),
  paste('Tracking sample input:', tracking_path),
  paste('Pilot document count:', nrow(pilot)),
  paste('Matching mapped polygon features:', nrow(polygons)),
  'Selection: first 30 distinct numeric document IDs among Active tracking rows with token IR.',
  'Selection order follows saved random sample OBJECTID order; this is a diagnostic pilot.',
  'Raw ID and attributes JSON are saved; the live service may change after download.',
  'A tracking-row party name is not verified as the current legal right holder.',
  'The number of mapped polygons is NOT the number of water rights, parcels, or owners.',
  'A missing polygon does not establish that the right is invalid or has no place of use.',
  'No geometry, parcel overlap, ownership or seniority ranking was calculated.'
), 'outputs/ecology_pou_pilot_provenance.txt')
cat('Checked ', nrow(pilot), ' document IDs: ',
    sum(pilot$mapped_pou_feature_count > 0L), ' have mapped place-of-use features; ',
    sum(pilot$mapped_pou_feature_count == 0L), ' have none in this layer.\n', sep = '')
