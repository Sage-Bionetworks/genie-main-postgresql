# Description: from all public releases, read files in raw format and create
#   release specific schemas in a relational database.  
# Author: Haley Hunter-Zinck
# Date: August 13, 2021
# assumptions: 
# - genie database has already been created 
# - genie release data files are stored in ~/data/genie_release_{number}

# setup ------------------------

tic = as.double(Sys.time())

# libraries
library(glue)

# directories
dir_data_genie <- "~/data"
dir_tmp <- "/tmp"
release_folder_prefix <- "genie_release"

# sql
username = "postgres"
# note: password cached in ~/.pgpass
database <- "genie"
cmd_psql_statement <- glue("psql -U {username} -d {database} -c")
cmd_psql_file <- glue("psql -U {username} -d {database} -f")

# checks -------------------

# TODO: check that database exists, else exit with message and command

# functions -------------------

get_release_str <- function(folder_name, major_only = F) {
  expr <- gregexpr(pattern = "[0-9.]+", text = folder_name)[[1]]
  release_no <- regmatches(folder_name, expr)
  if (major_only) {
    return(strsplit(x = release_no, split = ".", fixed = T)[[1]][1])
  }
  return(release_no)
}

get_table_name_from_file_name <- function(file_path) {
  file_name <- rev(strsplit(file_path, split = "/")[[1]])[1]
  file_prefix <- strsplit(file_name, split = ".", fixed = T)[[1]][1]
  return(file_prefix)
}

create_schema <- function(schema, drop_if_exists = F) {
  
  cmd_sql_prefix <- ""
  if (drop_if_exists) {
    cmd_sql_prefix <- glue("DROP SCHEMA IF EXISTS \"{schema}\" CASCADE;")
  }
  cmd_sql_body <- glue("CREATE SCHEMA IF NOT EXISTS \"{schema}\";")
  cmd_sql_suffix <- ""
  
  cmd_sql <- glue("{cmd_sql_prefix}\n{cmd_sql_body}\n{cmd_sql_suffix}")
  cmd_psql <- glue("{cmd_psql_statement} '{cmd_sql}'")
  system(cmd_psql)
  
  return(T)
}

get_variable_type <- function(variable_name) {
  
  var_int <- c("start_position", "end_position", "loc.start",
                "loc.end")
  var_num <-  c("t_ref_count", "t_alt_count", "n_ref_count", "n_alt_count", 
                "n_depth", "t_depth",
                "gnomad_af", "gnomad_afr_af", 
                "gnomad_amr_af", "gnomad_asj_af",
                "gnomad_eas_af", "gnomad_fin_af",
                "gnomad_nfe_af", "gnomad_oth_af",
                "gnomad_sas_af", "polyphen_score")
  var_boo <- c("mutationincis_flag")
  
  if (is.element(tolower(variable_name), var_int)) {
    return("INTEGER")
  }

  if (is.element(tolower(variable_name), var_num)) {
    return("NUMERIC")
  }
  
  if (is.element(tolower(variable_name), var_boo)) {
    return("BOOLEAN")
  }
  
  return("VARCHAR")
}

get_header <- function(file_path, delim, comment) {
  header <- c()
  nlines <- 1
  while(length(header) == 0) {
    header <- scan(file_path, what = "character", nlines = nlines, sep = delim, 
                   comment.char = comment)
    nlines = nlines + 1
  }
  
  return(header)
}

modify_column_name <- function(column_name) {
  return(gsub(pattern = ".", replacement = "_", x = column_name, fixed = T))
}

create_table_from_file <- function(file_path, table_name = NA, schema = "public", 
                                  drop_if_exists = F, delim = "\t", comment = "#") {
  
  if(is.na(table_name)) {
    table_name <- get_table_name_from_file_name(file_path)
  }
  
  header <- get_header(file_path = file_path, delim = delim, comment = comment)
  
  cmd_sql_prefix_a <- glue("SET search_path to \"{schema}\";")
  cmd_sql_prefix_b <- ""
  if(drop_if_exists) {
    cmd_sql_prefix_b <- glue("DROP TABLE IF EXISTS {table_name};")
  }
  cmd_sql_prefix_c <- glue("CREATE TABLE IF NOT EXISTS {table_name} (")
  cmd_sql_prefix <- glue("{cmd_sql_prefix_a} \n{cmd_sql_prefix_b}\n{cmd_sql_prefix_c}")
  
  cmd_sql_body <- ""
  for (i in seq_len(length(header))) {
    
    type = get_variable_type(header[i])
    
    if (i == 1) {
      cmd_sql_column <- glue("\n{modify_column_name(header[i])} {type}")
    } else {
      cmd_sql_column <- glue(",\n{modify_column_name(header[i])} {type}")
    }
    cmd_sql_body <- glue("{cmd_sql_body} {cmd_sql_column}")
  }
  cmd_sql_suffix <- ")"
  
  cmd_sql <- glue("{cmd_sql_prefix}\n{cmd_sql_body}\n{cmd_sql_suffix}")
  cmd_psql <- glue("{cmd_psql_statement} '{cmd_sql}'")
  system(cmd_psql)
  
  return(table_name)
}

load_table <- function(file_path, table_name = NA, schema = "public", delim = "\t") {
  
  if (is.na(table_name)) {
    table_name = get_table_name_from_file_name(file_path)
  }
  
  file_tmp_text <- glue("{dir_tmp}/file.txt")
  cmd_bash <- glue("grep -v '^#' {file_path} > {file_tmp_text}")
  system(cmd_bash)
  
  cmd_sql_prefix <- glue("SET search_path to '{schema}';")
  cmd_sql_body <- glue("COPY {table_name} FROM '{file_tmp_text}'")
  cmd_sql_suffix <- glue("CSV HEADER DELIMITER E'{delim}'")
  cmd_sql <- glue("{cmd_sql_prefix} {cmd_sql_body} {cmd_sql_suffix}")
  
  file_tmp_sql <- glue("{dir_tmp}/file.sql")
  write(cmd_sql, file = file_tmp_sql)
  cmd_psql <- glue("{cmd_psql_file} '{file_tmp_sql}'")
  system(cmd_psql)
  
  # clean up
  file.remove(file_tmp_text)
  file.remove(file_tmp_sql)
  
  return(T)
}


filter_files <- function(files, remove_with_suffix = "pdf", remove_with_name = NA) {
  idx_rm <- grep(pattern = "pdf$", x = files)
  if(length(idx_rm)) {
    files <- files[-idx_rm]
  }
  
  if(!is.na(remove_with_name)) {
    idx_rm <- grep(pattern = remove_with_name, x = files)
    if(length(idx_rm)) {
      files <- files[-idx_rm]
    }
  }
  
  return(files)
}

create_release <- function(dir_release, drop_schema = F, drop_table = F) {
  
  release_files <- filter_files(list.files(dir_release, full.names = T), 
                                remove_with_suffix = "pdf",
                                remove_with_name = "data_CNA.txt")
  release_no = as.double(get_release_str(dir_release, major_only = T))
  schema <- glue("{release_folder_prefix}_{sprintf('%02d', release_no)}")
  
  create_schema(schema, drop_if_exists = drop_schema)
  
  # get release files
  for (release_file in release_files) {
    create_table_from_file(file_path = release_file, schema = schema, 
                           drop_if_exists = drop_table)
    load_table(release_file, schema = schema)
  }
  
  return(T)
}

# main -------------------

dir_releases <- list.files(path = dir_data_genie, 
                           pattern = glue("{release_folder_prefix}_*"),
                           full.name = T)

for (dir_release in dir_releases) {
  create_release(dir_release, drop_schema = T, drop_table = T)
}

# close out --------------------------

toc <- as.double(Sys.time())
print(glue("Runtime: {round(toc - tic)} s"))
