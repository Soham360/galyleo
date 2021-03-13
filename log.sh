#!/usr/bin/env sh
# ======================================================================
#
# NAME
#
#     log.sh
#
# DESCRIPTION
#
#     A library of shell functions for writing formatted log messages to
#     standard output and standard error.
#
# USAGE
#
#     If you would like to use this library in your shell script, then 
#     source it at the beginning of your shell script.
#
#         source log.sh
#
#     Once the library has been sourced, you can call functions from the 
#     library in your shell script.
#
# AUTHOR
#
#     Marty Kandes, Ph.D.
#     Computational & Data Science Research Specialist
#     High-Performance Computing User Services Group
#     San Diego Supercomputer Center
#     University of California, San Diego
#
# LAST UPDATED
#
#     Sunday, March 7th, 2021
#
# ----------------------------------------------------------------------

function log_output() {

  # Declare local variables.
  local -i log_level
  local output_message

  # Assign input values to local variables.
  log_level="${1}"
  output_message="${2}"

  # If quiet mode is not enabled, then write the output message to
  # standard output.
  if [[ "${log_level}" -ne 0 ]]; then

    echo "${output_message}" >&1

  fi
 
  return 0 
}

function log_error() {

  # Declare local variables.
  local -i log_level
  local error_message

  # Assign input values to local variables.
  log_level="${1}"
  error_message="${2}"

  # If quiet mode is not enabled, then write the error message to
  # standard error.
  if [[ "${log_level}" -ne 0 ]]; then

    echo "ERROR :: ${error_message}" >&2

  fi

  return 0

}

function log_warning() {

  # Declare local variables.
  local -i log_level
  local warning_message

  # Assign input values to local variables.
  log_level="${1}"
  warning_message="${2}"

  # If quiet mode is enabled, then write 
  # the warning message to standard error.
  if [[ "${log_level}" -ne 0 ]]; then

    echo "WARNING :: ${warning_message}" >&2

  fi

}

# ======================================================================
