# Run from project root: Rscript R/01_profile_parcels.R
source('R/config.R')
if (!requireNamespace('sf', quietly = TRUE)) stop('Install the R package sf first.')
if (!file.exists(source_path)) stop('Missing input: ', source_path)
dir.create('outputs', showWarnings = FALSE, recursive = TRUE)
parcels <- sf::st_read(source_path, layer = source_layer, quiet = TRUE)
required <- c(county_field, parcel_field, landuse_field, row_id_field)
missing <- setdiff(required, names(parcels))
if (length(missing)) stop('Missing expected columns: ', paste(missing, collapse = ', '))
x <- sf::st_drop_geometry(parcels)
x$county <- trimws(as.character(x[[county_field]]))
x$parcel_id <- trimws(as.character(x[[parcel_field]]))
x$landuse <- trimws(as.character(x[[landuse_field]]))
x$row_id <- as.character(x[[row_id_field]])
if (anyNA(x$row_id) || anyDuplicated(x$row_id)) stop('Row IDs must be unique and present.')
if (anyNA(x$county) || any(x$county != '077')) stop('Unexpected county in Yakima snapshot.')
if (anyNA(x$landuse) || any(!x$landuse %in% ag_codes)) stop('Unexpected land-use code.')
if (anyNA(x$parcel_id) || any(x$parcel_id == '')) stop('Missing parcel identifiers.')

counts <- as.data.frame(table(county_fips = x$county, landuse_code = x$landuse),
                        stringsAsFactors = FALSE)
names(counts)[3] <- 'feature_rows'
counts <- counts[counts$feature_rows > 0, , drop = FALSE]
write.csv(counts, 'outputs/landuse_by_county.csv', row.names = FALSE, na = '')

keys <- paste(x$county, x$parcel_id, sep = ':')
frequencies <- table(keys)
quality <- data.frame(
  measure = c('feature_rows', 'distinct_county_parcel_ids', 'repeated_parcel_ids',
              'extra_rows_from_repeated_parcel_ids', 'missing_parcel_ids',
              'distinct_feature_row_ids', 'owner_field_present'),
  value = c(nrow(x), length(frequencies), sum(frequencies > 1),
            sum(frequencies - 1), sum(is.na(x$parcel_id) | x$parcel_id == ''),
            length(unique(x$row_id)), as.integer(any(grepl('owner', names(x), ignore.case = TRUE))))
)
write.csv(quality, 'outputs/quality_report.csv', row.names = FALSE)

# Repeated parcel IDs may be multiple polygons. Never silently count each as a separate owner.
repeated <- names(frequencies)[frequencies > 1]
if (length(repeated)) {
  repeated_rows <- x[keys %in% repeated, c(county_field, parcel_field, landuse_field, row_id_field), drop = FALSE]
  names(repeated_rows) <- c('county_fips', 'parcel_id', 'landuse_code', 'feature_row_id')
  repeated_rows <- repeated_rows[order(repeated_rows$parcel_id, repeated_rows$feature_row_id), , drop = FALSE]
  write.csv(repeated_rows, 'outputs/repeated_parcel_id_rows.csv', row.names = FALSE, na = '')
}
message('Profile complete: ', nrow(x), ' feature rows; ', length(frequencies), ' distinct parcel IDs.')
message('No ownership summary: this public input contains no owner names.')
