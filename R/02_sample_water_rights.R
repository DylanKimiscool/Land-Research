# Inspect 100 water-right tracking rows without loading the statewide table in QGIS.
# Run from the project root: source('R/02_sample_water_rights.R')
# This is a deterministic diagnostic sample (lowest OBJECTID values), not an
# ownership estimate, random sample, or a Yakima-only selection.

if (!requireNamespace('jsonlite', quietly = TRUE)) {
  install.packages('jsonlite', repos = 'https://cloud.r-project.org')
}

service <- 'https://services.arcgis.com/6lCKYNJLvwTXqrmp/arcgis/rest/services/WR/FeatureServer/10'
query_url <- paste0(
  service, '/query?where=1%3D1&outFields=',
  paste(c('OBJECTID', 'WR_Doc_ID', 'WaRecPhaseId', 'PartyRoleTypeCode',
          'PersonLastOrOrganizationNM', 'PersonFirstNM', 'WaRecPrimaryNumber',
          'PriorityDate', 'WaRecProcessStatusTypeCode', 'PurposeOfUseTypeCodes',
          'InstantaneousQuantity', 'AnnualVolumeQuantity', 'IrrigatedAreaQuantity'),
        collapse = ','),
  '&returnGeometry=false&orderByFields=OBJECTID%20ASC&resultRecordCount=100&f=json'
)

dir.create('data/raw', recursive = TRUE, showWarnings = FALSE)
dir.create('outputs', recursive = TRUE, showWarnings = FALSE)
raw_path <- 'data/raw/ecology_tracking_first100_response.json'
utils::download.file(query_url, raw_path, mode = 'wb', quiet = TRUE)
response <- jsonlite::fromJSON(raw_path, simplifyVector = FALSE)
if (!is.null(response$error)) stop('Ecology service returned: ', response$error$message)
if (length(response$features) != 100L) {
  stop('Expected exactly 100 sample rows; got ', length(response$features),
       '. Check the raw JSON before using the result.')
}

fields <- c('OBJECTID', 'WR_Doc_ID', 'WaRecPhaseId', 'PartyRoleTypeCode',
            'PersonLastOrOrganizationNM', 'PersonFirstNM', 'WaRecPrimaryNumber',
            'PriorityDate', 'WaRecProcessStatusTypeCode', 'PurposeOfUseTypeCodes',
            'InstantaneousQuantity', 'AnnualVolumeQuantity', 'IrrigatedAreaQuantity')
get_value <- function(feature, field) {
  value <- feature$attributes[[field]]
  if (is.null(value) || length(value) == 0L) return(NA_character_)
  as.character(value)
}
sample_rows <- as.data.frame(lapply(fields, function(field) {
  vapply(response$features, get_value, character(1), field = field)
}), stringsAsFactors = FALSE)
names(sample_rows) <- fields
# ArcGIS JSON dates are Unix milliseconds; keep the original values in raw JSON.
milliseconds <- suppressWarnings(as.numeric(sample_rows$PriorityDate))
sample_rows$PriorityDate <- as.character(as.Date(
  as.POSIXct(milliseconds / 1000, origin = '1970-01-01', tz = 'UTC')
))
utils::write.csv(sample_rows, 'outputs/ecology_tracking_first100.csv',
                 row.names = FALSE, na = '')

capture <- c(
  paste('Retrieved UTC:', format(Sys.time(), tz = 'UTC', usetz = TRUE)),
  paste('Query:', query_url),
  'Sample rule: first 100 rows sorted by OBJECTID, statewide; NOT random or Yakima-specific.',
  'Not valid for owner rankings, priority rankings, or estimates of statewide coverage.',
  'A party labelled Primary is not automatically a verified current legal holder.',
  'PriorityDate is the right priority date, not the date its listed party acquired it.'
)
writeLines(capture, 'outputs/ecology_tracking_first100_provenance.txt')
cat('Saved 100 diagnostic water-right rows to outputs/ecology_tracking_first100.csv\n')
cat('Original response saved to ', raw_path, '\n', sep = '')
