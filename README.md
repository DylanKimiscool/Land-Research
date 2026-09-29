# Washington Land & Water Rights Research

This repository contains code, documentation, and processed data for a research project examining agricultural land, water rights, and ownership structures in Washington State.

The project is being developed as a reproducible workflow using R and QGIS. The long-term goal is to connect land and water-right records to ownership entities, with a particular focus on LLC ownership and the relationships between LLCs and larger companies.

## Current Research Workflow

The project currently combines Washington parcel data with Washington Department of Ecology water-right records.

Work completed so far includes:

- Profiling and validating agricultural parcel data
- Examining parcel identifiers, land-use codes, and duplicate parcel records
- Sampling Washington Department of Ecology water-right tracking records
- Examining water-right record statuses
- Linking tracking records to Place of Use (POU) information
- Creating a pilot POU dataset for testing the spatial workflow
- Exporting the pilot POU polygons as a GeoPackage for use in QGIS
- Creating a document-level queue for reviewing ownership/holder information
- Recording provenance information for major derived outputs

## Repository Structure

```text
Land-Research/
│
├── R/
│   ├── config.R
│   ├── 01_profile_parcels.R
│   ├── 02_sample_water_rights.R
│   ├── 04_link_tracking_to_place_of_use.R
│   ├── 05_export_pou_pilot_map.R
│   └── 06_make_holder_review_queue.R
│
├── data/
│   └── derived/
│       └── ecology_pou_pilot_29.gpkg
│
├── outputs/
│   ├── parcel profiling outputs
│   ├── Ecology tracking samples
│   ├── POU pilot summaries
│   ├── holder review queue
│   └── provenance files
│
├── docs/
│   ├── data_log.csv
│   └── ownership_review_template.csv
│
└── README.md

## Tools

- R
- QGIS
- GitHub
- Washington State geospatial and water-rights data
