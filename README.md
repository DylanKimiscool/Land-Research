# Washington Land & Water Rights Research

This repository contains code, documentation, and processed data for a research project examining land ownership and water rights in Washington State.

## Research Goal

The project aims to connect land parcels and water rights to their ownership entities, with a particular focus on LLC ownership. The long-term goal is to create a reproducible workflow for identifying ownership patterns across Washington State.

## Progress

### Agricultural Parcel Data
- Imported and processed Washington parcel data in R.
- Filtered the dataset to identify agricultural land.
- Created a dataset containing 11,337 agricultural parcel features representing 10,427 unique parcels.
- Began examining the attributes and geographic structure of these parcels.

### Washington Ecology Place of Use (POU) Data
- Imported Washington Department of Ecology Place of Use polygon data.
- Inspected the structure, attributes, and geometry of the POU dataset.
- Created a smaller pilot dataset for developing and testing the workflow.
- Exported the pilot spatial dataset as a GeoPackage for use in R and QGIS.
- Created supporting CSV files documenting polygon attributes and the source documents.

### R and QGIS Workflow
- Used R to load, inspect, filter, summarize, and export spatial data.
- Imported processed spatial data into QGIS for geographic inspection.
- Checked feature counts, unique parcel counts, coordinate reference systems, geometry types, and relevant attributes.
- Began developing a reproducible workflow so the analysis can later be applied to larger datasets.

## Current Stage

The current stage focuses on preparing and understanding the land parcel and water-rights datasets before linking them to ownership records. The next steps will involve developing methods for identifying LLC ownership and connecting ownership information with the spatial datasets.

## Tools

- R
- QGIS
- GitHub
- Washington State geospatial and water-rights data
