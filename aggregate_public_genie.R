# Description: aggregate GENIE public releases into a single database schema
#   for easy processing. 
# Author: Haley Hunter-Zinck
# Date: August 16, 2021

# setup ----------------------------

tic = as.double(Sys.time())

# packages
library(glue)

# sql
username = "postgres"
# note: password cached in ~/.pgpass
database <- "genie"
CMD_PSQL_STATEMENT <- glue("psql -U {username} -d {database} -c")
schema_std <- "genie_release_09"

# parameters
release_prefix <- "genie_release"
release_nos <- c(1:11)
debug = T

# functions ------------------------

now <- function(timeOnly = F, tz = "US/Pacific") {
  
  Sys.setenv(TZ=tz)
  
  if(timeOnly) {
    return(format(Sys.time(), "%H:%M:%S"))
  }
  
  return(format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
}

old2new <- function(old) {
  
  no_change <- c("assay_information", "genomic_information")
  
  if (is.element(old, no_change)) {
    return(old)
  }
  
  if (old == "data_clinical_patient") {
    return("patient")
  }
  
  if (old == "data_clinical_sample") {
    return("sample")
  }
  
  if (old == "data_fusions") {
    return("fusion")
  }
  
  if (old == "data_mutations_extended") {
    return("mutation")
  }
  
  if (old == "genie_data_cna_hg19") {
    return("cna")
  }
  
  return(NA)
}

query_postgres = function(query, is_query = T) {
  
  
  cmd_psql <- glue("{CMD_PSQL_STATEMENT} '{query}'")
  
  if(!is_query) {
    system(cmd_psql)
    return(T)
  }
  
  data <- system(cmd_psql, intern = T)
  return(as.matrix(data))
}

create_schema <- function(schema, drop_if_exists = F) {
  
  if (drop_if_exists) {
    query <- glue("DROP SCHEMA IF EXISTS \"{schema}\" CASCADE;")
    query_postgres(query, is_query = F)
  }
  
  query <- glue("CREATE SCHEMA IF NOT EXISTS \"{schema}\";")
  query_postgres(query, is_query = F)
  
  return(T)
}

copy_schema_and_tables <- function(new_schema, old_schema) {
  
  # get tables in the old schema
  query <- glue("SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = '{old_schema}'")
  old_tables <- query_postgres(query, is_query = T)
  
  # create schema
  create_schema(schema = new_schema, drop_if_exists = T)
    
  # for each table
  for (table_name in old_tables) {
    query <- glue("CREATE TABLE {new_schema}.{table_name} (LIKE {old_schema}.{table_name} INCLUDING ALL);")
    query_postgres(query, is_query = F)
  }
      
  return(T)
}

modify_schema_and_tables <- function(schema) {
  
  # get all tables in schema
  query <- glue("SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = '{schema}'")
  table_names <- query_postgres(query, is_query = T)
  
  # for each table
  for (old_table_name in table_names) {
    
    # change name to standard name
    new_table_name <- old2new(old = old_table_name)
    
    if(old_table_name != new_table_name) {
      query <- glue("ALTER TABLE {schema}.{old_table_name} RENAME TO {new_table_name}")
      query_postgres(query, is_query = F)
    }
    
    # add release column to table
    query = glue("ALTER TABLE {schema}.{new_table_name}
              ADD COLUMN release INTEGER")
    query_postgres(query, is_query = F)
  }

  return(T)
}

get_columns <- function(table_schema, table_name) {
  query <- glue("SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = '{table_schema}'
                AND table_name = '{table_name}'")
  column_names <- query_postgres(query, is_query = T)
  
  return(column_names)
}

write_quick_etl <- function(from_schema, from_table, to_schema, to_table, 
                            release_no, distinct = F) {
  
  # get column names
  from_cols <- get_columns(table_schema = from_schema, table_name = from_table)
  to_cols <- setdiff(get_columns(table_schema = to_schema, table_name = to_table), "release")
  
  # construct query
  query <- glue("INSERT INTO {to_schema}.{to_table} SELECT ")
  if(distinct) {
    query <- glue("{query} DISTINCT")
  }
  for (column_name in to_cols) {
    if(is.element(column_name, from_cols)) {
      query = glue("{query} {column_name},")
    } else {
      query = glue("{query} NULL AS {column_name}, ")
    }
  }
  
  query = glue("{query} {release_no} AS release FROM {from_schema}.{from_table}")
  
  return(query)
}

etl_release_01 <- function(from_schema, to_schema, release_no) {
  map_files <- matrix(c("data_clinical", "assay_information",
                        "genie_data_cna_hg19", "cna",
                        "data_fusions", "fusion",
                        "genie_combined", "genomic_information",
                        "data_mutations_extended", "mutation",
                        "data_clinical", "patient",
                        "data_clinical", "sample"), 
                      ncol = 2, dimnames = list(c(), c("from","to")), byrow = T)
  
  for(i in 1:nrow(map_files)) {
    
    query <- write_quick_etl(from_schema = from_schema, 
                             from_table = map_files[i,"from"], 
                             to_schema = to_schema, 
                             to_table = map_files[i,"to"], 
                             release_no = release_no,
                             distinct = map_files[i,"to"] == "assay_information")
    query_postgres(query, is_query = F)
  }
  
  return(T)
  
}

etl_release_old <- function(to_schema, from_schema, release_no) {
  map_files <- matrix(c("data_clinical_sample", "assay_information",
                        "genie_data_cna_hg19", "cna",
                        "data_fusions", "fusion",
                        "genie_combined", "genomic_information",
                        "data_mutations_extended", "mutation",
                        "data_clinical_patient", "patient",
                        "data_clinical_sample", "sample"), 
                      ncol = 2, dimnames = list(c(), c("from","to")), byrow = T)
  
  for(i in 1:nrow(map_files)) {
    
    query <- write_quick_etl(from_schema = from_schema, 
                             from_table = map_files[i,"from"], 
                             to_schema = to_schema, 
                             to_table = map_files[i,"to"], 
                             release_no = release_no,
                             distinct = map_files[i,"to"] == "assay_information")
    query_postgres(query, is_query = F)
  }
}

etl_release_07 <- function(to_schema, from_schema, release_no) {
  map_files <- matrix(c("data_clinical_sample", "assay_information",
                        "genie_data_cna_hg19", "cna",
                        "data_fusions", "fusion",
                        "genomic_information", "genomic_information",
                        "data_mutations_extended", "mutation",
                        "data_clinical_patient", "patient",
                        "data_clinical_sample", "sample"), 
                      ncol = 2, dimnames = list(c(), c("from","to")), byrow = T)
  
  for(i in 1:nrow(map_files)) {
    
    query <- write_quick_etl(from_schema = from_schema, 
                             from_table = map_files[i,"from"], 
                             to_schema = to_schema, 
                             to_table = map_files[i,"to"], 
                             release_no = release_no,
                             distinct = F)
    query_postgres(query, is_query = F)
  }
}

etl_release_new <- function(to_schema, from_schema, release_no) {
  map_files <- matrix(c("assay_information", "assay_information",
                        "genie_data_cna_hg19", "cna",
                        "data_fusions", "fusion",
                        "genomic_information", "genomic_information",
                        "data_mutations_extended", "mutation",
                        "data_clinical_patient", "patient",
                        "data_clinical_sample", "sample"), 
                      ncol = 2, dimnames = list(c(), c("from","to")), byrow = T)
  
  for(i in 1:nrow(map_files)) {
    
    query <- write_quick_etl(from_schema = from_schema, 
                             from_table = map_files[i,"from"], 
                             to_schema = to_schema, 
                             to_table = map_files[i,"to"], 
                             release_no = release_no,
                             distinct = F)
    query_postgres(query, is_query = F)
  }
}

etl <- function(schema, release_no) {
  
  if (release_no == 1) {
    etl_release_01(to_schema = schema, 
                  from_schema = glue("{release_prefix}_{sprintf('%02d', release_no)}"), 
                  release_no = release_no)
  } else if (release_no >=2 && release_no <=6) {
    etl_release_old(to_schema = schema, 
                   from_schema = glue("{release_prefix}_{sprintf('%02d', release_no)}"),
                   release_no = release_no)
  } else if (release_no == 7) {
    etl_release_07(to_schema = schema, 
                   from_schema = glue("{release_prefix}_{sprintf('%02d', release_no)}"),
                   release_no = release_no)
  } else if(release_no >= 7) {
    etl_release_new(to_schema = schema, 
                   from_schema = glue("{release_prefix}_{sprintf('%02d', release_no)}"),
                   release_no = release_no)
  } else {
    print(glue("Warning: no ETL procedure defined for release {release_no}."))
    return(F)
  }
  
  return (T)
}

# main -----------------------------

# create standardized schema
copy_schema_and_tables(new_schema = my_schema, old_schema = schema_std)
modify_schema_and_tables(my_schema)

# for each public release
for (release_no in release_nos) {
  
  if (debug) {
    cat(glue("{now()}: Loading GENIE public release {release_no}..."))
  }
  
  etl(schema = my_schema, release_no  = release_no)
  
  if (debug) {
    cat("Done!\n")
  }
}

# close out --------------------------

toc <- as.double(Sys.time())
print(glue("Runtime: {round(toc - tic)} s"))

