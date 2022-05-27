# Main GENIE PostgreSQL Database

## Overview
The following set of scripts provide an approximate guide for creating a local
PostgreSQL database for the main GENIE public releases.  These scripts have 
not been thoroughly tested and should be used as an approximate reference only.

The `create_db_genie_raw.R` script creates an individual schema for each release
and the `aggregate_public_genie.R` script aggregates all releases into a single 
schema, adding an additional column labeled `release` to each table to mark the 
release provenance of each row of data.  

See `genie-main-postgresql.sh` for an outline of all steps.  

## Installation

1. Clone this repository and navigate to the directory:
```
git clone git@github.com:Sage-Bionetworks/genie-main-postgresql.git
cd genie-main-postgresql
```

2. Install all required R packages:
```
R -e 'renv::restore()'
```

3. Install the synapse command line client (see https://help.synapse.org/docs/Getting-Started-with-Synapse-API-Clients.2098758106.html)
4. Install PostgreSQL via pgAdmin (see https://www.pgadmin.org/)
5. Open the the pgAdmin tool and create a database called `genie`.
6. Cache your password for the `postgres` user in `~/.pgpass` (see https://www.postgresql.org/docs/current/libpq-pgpass.html)

## Synapse credentials

Cache your Synapse personal access token (PAT) as an environmental variable:
```
export SYNAPSE_AUTH_TOKEN={your_personal_access_token_here}
```

or store in ~/.synapseConfig with the following format:
```
[authentication]

# either authtoken OR username and password
authtoken = {your_personal_access_token_here}
```

## Usage

These scripts are provided as a reference only.  The full workflow has 
not been thoroughly tested but in an ideal world:

```
sh genie-main-postgresql.sh
```

## Notes on primary and foreign keys

Primary and foreign keys are mapped below.  They are not automatically specified 
when tables are constructed due to duplicated primary keys in the raw data.

patient
PRIMARY KEY(patient_id, release)

sample
PRIMARY KEY(sample_id, release)
CONSTRAINT fk_patient
	FOREIGN KEY(patient_id, release)
		REFERENCES patient(patient_id, release)

mutation
PRIMARY KEY(chromosome, start_position, end_position, reference_allele, tumor_seq_allele1, tumor_sample_barcode, release)
CONSTRAINT fk_sample
	FOREIGN KEY(tumor_sample_barcode, release)
		REFERENCES sample(sample_id, release)


genomic_information
PRIMARY KEY(chromosome, start_position, end_position, seq_assay_id, release)
CONSTRAINT fk_assay
	FOREIGN KEY(seq_assay_id, release)
		REFERENES assay_information(seq_assay_id, release)


fusion
PRIMARY KEY(hugo_symbol, tumor_sample_barcode, release)
CONSTRAINT fk_sample
	FOREIGN KEY(tumor_sample_barcode, release)
		REFERENCES sample(sample_id, release)

cna
PRIMARY KEY(id, chrom, loc_start, loc_end, release)
CONSTRAINT fk_sample
	FOREIGN KEY(id, release)
		REFERENCES sample(sample_id, release)

assay_information
PRIMARY_KEY(seq_assay_id, release)

