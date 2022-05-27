# Main GENIE PostgreSQL Database

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

The workflow and scripts are provided as a reference only.  The workflow has 
not been tested.

