# Description: Workflow for creating a local PostgreSQL data of main
#   GENIE database releases.
# Author: Haley Hunter-Zinck
# Date: 2022-05-24

# create data folder
mkdir ~/data
mkdir ~/tmp

# download release 1
mkdir ~/data/genie_release_1
cd ~/data/genie_release_1
synapse get -r syn7844527 

# download release 2
mkdir ~/data/genie_release_2
cd ~/data/genie_release_2
synapse get -r syn11310744

# download release 3
mkdir ~/data/genie_release_3
cd ~/data/genie_release_3
synapse get -r syn11638406

# download release 4
mkdir ~/data/genie_release_4
cd ~/data/genie_release_4
synapse get -r syn13247707

# download release 5
mkdir ~/data/genie_release_5
cd ~/data/genie_release_5
synapse get -r syn17112456

# download release 6
mkdir ~/data/genie_release_6
cd ~/data/genie_release_6
synapse get -r syn20333031

# download relase 7
mkdir ~/data/genie_release_7
cd ~/data/genie_release_7
synapse get -r syn21551261

# download release 8
mkdir ~/data/genie_release_8
cd ~/data/genie_release_8
synapse get -r syn22228642

# download relase 9
mkdir ~/data/genie_release_9
cd ~/data/genie_release_9
synapse get -r syn24179657

# download release 10
mkdir ~/data/genie_release_10
cd ~/data/genie_release_10
synapse get -r syn25895958

# download relase 11
mkdir ~/data/genie_release_11
cd ~/data/genie_release_11
synapse get -r syn26706564

# create individual release schemas
Rscript create_db_genie_raw.R 

# aggregtate individual release schemas into a single schema
Rscript aggregate_public_genie.R

