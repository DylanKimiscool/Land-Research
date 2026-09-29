
# Make a document-level review queue from the saved pilot snapshot.
# Run from project root after scripts 04 and 05:
# source('R/06_make_holder_review_queue.R')
# The listed name is a tracking-table party, not a verified current holder.

if (!requireNamespace('sf', quietly = TRUE)) stop('Install sf first.')
summary_path <- 'outputs/ecology_pou_pilot_document_summary.csv'
attributes_path <- 'outputs/ecology_pou_pilot_polygon_attributes.csv'
map_path <- 'data/derived/ecology_pou_pilot_29.gpkg'
output_path <- 'outputs/ecology_holder_review_queue.csv'
if (!all(file.exists(c(summary_path, attributes_path, map_path)))) {
  stop('Run scripts 04 and 05 in this project folder first.')
}
if (file.exists(output_path)) {
  stop('Review queue already exists. Move or rename it first to preserve any manual review.')
}

docs <- utils::read.csv(summary_path, stringsAsFactors = FALSE,
                        colClasses = 'character', check.names = FALSE)
attrs <- utils::read.csv(attributes_path, stringsAsFactors = FALSE,
                         colClasses = 'character', check.names = FALSE)
map <- sf::st_read(map_path, quiet = TRUE)
required_docs <- c('WR_Doc_ID', 'WaRecPrimaryNumber', 'PersonLastOrOrganizationNM',
                   'PersonFirstNM', 'PartyRoleTypeCode', 'PriorityDate',
                   'WaRecProcessStatusTypeCode', 'PurposeOfUseTypeCodes',
                   'mapped_pou_feature_count')
required_attrs <- c('OBJECTID', 'WR_DOC_ID', 'WR_Doc_NR')
if (!all(required_docs %in% names(docs)) ||
    !all(required_attrs %in% names(attrs)) ||
    !all(required_attrs %in% names(map))) {
  stop('Unexpected columns in the saved pilot files.')
}
if (anyDuplicated(docs$WR_Doc_ID) || anyDuplicated(attrs$OBJECTID) ||
    anyDuplicated(map$OBJECTID) || any(sf::st_is_empty(map))) {
  stop('Duplicate IDs or empty map geometry; inspect the pilot inputs.')
}
index <- match(as.character(map$OBJECTID), attrs$OBJECTID)
if (anyNA(index) || nrow(map) != nrow(attrs) ||
    !identical(as.character(map$WR_DOC_ID), attrs$WR_DOC_ID[index]) ||
    !setequal(as.character(map$OBJECTID), attrs$OBJECTID)) {
  stop('Map and attribute snapshot do not agree on feature and document IDs.')
}
counts <- table(attrs$WR_DOC_ID)
expected <- as.integer(counts[docs$WR_Doc_ID])
expected[is.na(expected)] <- 0L
if (!identical(expected, as.integer(docs$mapped_pou_feature_count)) ||
    !all(attrs$WR_DOC_ID %in% docs$WR_Doc_ID)) {
  stop('Document counts or IDs do not agree with mapped features.')
}

object_ids <- character(nrow(docs))
map_numbers <- character(nrow(docs))
number_check <- character(nrow(docs))
review_flags <- character(nrow(docs))
for (i in seq_len(nrow(docs))) {
  subset <- attrs[attrs$WR_DOC_ID == docs$WR_Doc_ID[i], , drop = FALSE]
  object_ids[i] <- paste(sort(as.integer(subset$OBJECTID)), collapse = '; ')
  nums <- sort(unique(trimws(subset$WR_Doc_NR[nzchar(trimws(subset$WR_Doc_NR))])))
  primary_number <- trimws(docs$WaRecPrimaryNumber[i])
  map_numbers[i] <- paste(nums, collapse = '; ')
  number_check[i] <- if (!nrow(subset)) 'no mapped polygon' else if (
    primary_number %in% nums) 'primary number among mapped numbers' else
      'primary number differs from mapped number'
  flags <- character(0)
  if (!nrow(subset)) flags <- c(flags, 'no polygon in this layer')
  if (nrow(subset) > 1L) flags <- c(flags, 'multiple polygons for document')
  if (nrow(subset) && !primary_number %in% nums) {
    flags <- c(flags, 'document number needs review')
  }
  review_flags[i] <- paste(flags, collapse = '; ')
}

queue <- data.frame(
  WR_Doc_ID = docs$WR_Doc_ID,
  tracking_primary_number = docs$WaRecPrimaryNumber,
  tracking_party_name_unverified = trimws(paste(
    docs$PersonFirstNM, docs$PersonLastOrOrganizationNM)),
  tracking_party_role = docs$PartyRoleTypeCode,
  priority_date = docs$PriorityDate,
  tracking_status = docs$WaRecProcessStatusTypeCode,
  purpose_codes = docs$PurposeOfUseTypeCodes,
  mapped_pou_feature_count = expected,
  mapped_objectids = object_ids,
  mapped_document_numbers = map_numbers,
  number_check = number_check,
  review_flags = review_flags,
  current_holder_name = rep('', nrow(docs)),
  holder_evidence_type = rep('', nrow(docs)),
  holder_evidence_url_or_file = rep('', nrow(docs)),
  holder_evidence_date = rep('', nrow(docs)),
  holder_review_status = rep('unverified', nrow(docs)),
  review_notes = rep('', nrow(docs)),
  stringsAsFactors = FALSE, check.names = FALSE
)
# Oldest priority dates first for review; this is NOT an owner ranking.
queue <- queue[order(queue$priority_date, queue$WR_Doc_ID), , drop = FALSE]
utils::write.csv(queue, output_path, row.names = FALSE, na = '')
writeLines(c(
  paste('Created UTC:', format(Sys.time(), tz = 'UTC', usetz = TRUE)),
  paste('Inputs:', paste(c(summary_path, attributes_path, map_path), collapse = '; ')),
  'One row per sampled document ID, not one row per polygon, right holder, or owner.',
  'Oldest priority dates appear first to guide review, not to rank owners.',
  'Tracking-table names and primary numbers require source-document review.',
  'A mapped place of use does not establish legal title or parcel ownership.',
  'Manual review columns are blank; never fill them from name resemblance alone.',
  'Re-running stops if the queue exists so human annotations cannot be overwritten.'
), 'outputs/ecology_holder_review_queue_provenance.txt')
cat('Wrote ', nrow(queue), ' document review rows to ', output_path,
    '; ', sum(queue$number_check == 'primary number differs from mapped number'),
    ' mapped-document number differences need review.\n', sep = '')
