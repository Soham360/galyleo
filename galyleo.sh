#!/usr/bin/env sh
# ======================================================================
#
# NAME
#
#     galyleo.sh
#
# DESCRIPTION
#
#     A shell utility to help you launch Jupyter notebooks on a remote
#     system in a secure way.
#
# USAGE
#
#     <INSERT USAGE DESCRIPTION HERE>
#
# DEPENDENCIES
#
#     <INSERT DEPS DESCRIPTION HERE>
#
# AUTHOR(S)
#
#     Marty Kandes, Ph.D.
#     Computational & Data Science Research Specialist
#     High-Performance Computing User Services Group
#     San Diego Supercomputer Center
#     University of California, San Diego
#
# LAST UPDATED
#
#     Wednesday, March 17th, 2021
#
# ----------------------------------------------------------------------

# Declare a global environment variable to set the installation location
# of galyleo. DO NOT leave as PWD when deployed in production. In the
# future, may include a Makefile with a PREFIX option to install
# correctly and set this variable. e.g., https://github.com/oyvinev/log.sh

declare -xr GALYLEO_INSTALL_DIR="${PWD}"

# Declare a global environment variable to set the galyleo cache
# directory, which will hold all output files generated by galyleo.
# e.g., Slurm batch job scripts, Slurm standard output files, etc.

declare -xr GALYLEO_CACHE_DIR="${HOME}/.galyleo"

# Declare a set of global environment variables used to identify a
# specific execution of galyleo. e.g., used to label a unique id of the
# generated batch job script.

declare -xr CURRENT_LOCAL_TIME="$(date +'%Y%m%dT%H%M%S%z')"
declare -xir CURRENT_UNIX_TIME="$(date +'%s')"
declare -xir RANDOM_ID="${RANDOM}"

# Source all shell libraries required for galyleo.

source "${GALYLEO_INSTALL_DIR}/lib/slog.sh"

# ----------------------------------------------------------------------
# galyleo_launch
#
#   Launches a Jupyter notebook server on a remote system. There will be
#   several modes of operation that are supported with the 'launch'
#   command. However, only the 'local' launch mode is available at this
#   time. i.e., 'local' -> no SSH involved.
#
# Globals:
#
#   GALYLEO_CACHE_DIR
#   SLOG_LEVEL
#
# Arguments:
#
#   -M | --mode <mode>
#   -A | --account <account>
#   -R | --reservation <reservation>
#   -p | --partition <partition>
#   -q | --qos <qos>
#   -N | --nodes <nodes>
#   -n | --ntasks-per-node <ntasks_per_node>
#   -c | --cpus-per-task <cpus_per_node>
#   -M | --memory-per-node <memory_per_node>
#   -m | --memory-per-cpu <memory_per_cpu>
#   -G | --gpus <gpus>
#      | --gres <gres>
#   -t | --time-limit <time_limit>
#   -C | --constraint <constraint>
#   -j | --jupyter <jupyter_interface>
#   -d | --notebook-dir <jupyter_notebook_dir>
#   -r | --reverse-proxy <reverse_proxy_fqdn>
#   -D | --dns-domain <dns_domain>
#   -s | --sif <singularity_image_file>
#   -B | --bind <singularity_bind_mounts>
#      | --nv
#   -e | --env-modules <env_modules>
#      | --conda-env <conda_env>
#
# Returns:
#
#   True  (0) if the launch was successful.
#   False (1) if the launch failed and/or was halted.
#
# ----------------------------------------------------------------------
function galyleo_launch() {

  # Declare galyleo launch mode variable and set its default to 'local'.
  local mode='local'

  # Declare input variables associated with Slurm sbatch options.
  local account=''
  local reservation=''
  local partition='shared'
  local qos=''
  local -i nodes=1
  local -i ntasks_per_node=1
  local -i cpus_per_task=1
  local -i memory_per_node=-1
  local -i memory_per_cpu=2
  local gpus=''
  local gres=''
  local time_limit='00:30:00'
  local constraint=''
  local exclude=''
  local comment='galyleo'

  # Declare input variables associated with Jupyter runtime environment.
  local jupyter_interface='lab'
  local jupyter_notebook_dir=''

  # Declare input variable associated with reverse proxy service.
  local reverse_proxy_fqdn='expanse-user-content.sdsc.edu'
  local dns_domain='eth.cluster'

  # Declare input variables associated with Singularity containers.
  local singularity_image_file=''
  local singularity_bind_mounts=''
  local singularity_gpu_type=''

  # Declare input variables associated with environment modules.
  local env_modules=''

  # Declare input variables associated with conda environments.
  local conda_env=''

  # Declare internal galyelo_launch variables not affected by input variables.
  local job_name="galyleo-${CURRENT_LOCAL_TIME}-${CURRENT_UNIX_TIME}-${RANDOM_ID}"
  local -i job_id=-1
  local http_response=''
  local -i http_status_code=-1

  # Read in command-line options and assign input variables to local
  # variables.
  while (("${#}" > 0)); do
    case "${1}" in
      -M | --mode )
        mode="${2}"
        shift 2
        ;;
      -A | --account )
        account="${2}"
        shift 2
        ;;
      -R | --reservation )
        reservation="${2}"
        shift 2
        ;;
      -p | --partition )
        partition="${2}"
        shift 2
        ;;
      -q | --qos )
        qos="${2}"
        shift 2
        ;;
      -N | --nodes )
        nodes="${2}"
        shift 2
        ;;
      -n | --ntasks-per-node )
        ntasks_per_node="${2}"
        shift 2
        ;;
      -c | --cpus-per-task )
        cpus_per_task="${2}"
        shift 2
        ;;
      -M | --memory-per-node )
        memory_per_node="${2}"
        shift 2
        ;;
      -m | --memory-per-cpu )
        memory_per_cpu="${2}"
        shift 2
        ;;
      -G | --gpus )
        gpus="${2}"
        shift 2
        ;;
      --gres )
        gres="${2}"
        shift 2
        ;;
      -t | --time-limit )
        time_limit="${2}"
        shift 2
        ;;
      -C | --constraint )
        constraint="${2}"
        shift 2
        ;;
      -j | --jupyter )
        jupyter_interface="${2}"
        shift 2
        ;;
      -d | --notebook-dir )
        jupyter_notebook_dir="${2}"
        shift 2
        ;;
      -r | --reverse-proxy )
        reverse_proxy_fqdn="${2}"
        shift 2
        ;;
      -D | --dns-domain )
        dns_domain="${2}"
        shift 2
        ;;
      -s | --sif )
        singularity_image_file="${2}"
        shift 2
        ;;
      -B | --bind )
        singularity_bind_mounts="${2}"
        shift 2
        ;;
      --nv )
        singularity_gpu_type='nv'
        shift 1
        ;;
      --rocm )
        singularity_gpu_type='rocm'
        shift 1
        ;;
      -e | --env-modules )
        env_modules="${2}"
        shift 2
        ;;
      --conda-env )
        conda_env="${2}"
        shift 2
        ;;
      -Q | --quiet )
        SLOG_LEVEL=0
        shift 1
        ;;
      *)
        slog error -m "Command-line option ${1} not recognized or not supported."
        return 1
    esac
  done

  # Print all command-line options read in for launch to standard output.
  slog output -m 'Preparing galyleo for launch into Jupyter orbit ...'
  slog output -m 'Listing all launch parameters ...'
  slog output -m '  command-line option      : value'
  slog output -m "    -M | --mode            : ${mode}"
  slog output -m "    -A | --account         : ${account}"
  slog output -m "    -R | --reservation     : ${reservation}"
  slog output -m "    -p | --partition       : ${partition}"
  slog output -m "    -q | --qos             : ${qos}"
  slog output -m "    -N | --nodes           : ${nodes}"
  slog output -m "    -n | --ntasks-per-node : ${ntasks_per_node}"
  slog output -m "    -c | --cpus-per-task   : ${cpus_per_task}"
  slog output -m "    -M | --memory-per-node : ${memory_per_node}"
  slog output -m "    -m | --memory-per-cpu  : ${memory_per_cpu}"
  slog output -m "    -G | --gpus            : ${gpus}"
  slog output -m "       | --gres            : ${gres}"
  slog output -m "    -t | --time-limit      : ${time_limit}"
  slog output -m "    -j | --jupyter         : ${jupyter_interface}"
  slog output -m "    -d | --notebook-dir    : ${jupyter_notebook_dir}"
  slog output -m "    -r | --reverse-proxy   : ${reverse_proxy_fqdn}"
  slog output -m "    -D | --dns-domain      : ${dns_domain}"
  slog output -m "    -s | --sif             : ${singularity_image_file}"
  slog output -m "    -B | --bind            : ${singularity_bind_mounts}"
  slog output -m "       | --nv              : ${singularity_gpu_type}"
  slog output -m "    -e | --env-modules     : ${env_modules}"
  slog output -m "       | --conda-env       : ${conda_env}"

  # Request a subdomain connection token from reverse proxy service. If the 
  # reverse proxy service returns an HTTP/S error, then halt the launch.
  http_response="$(curl -s -w %{http_code} https://manage.${reverse_proxy_fqdn}/getlink.cgi -o -)"
  http_status_code="$(echo ${http_response} | awk '{print $NF}')"
  if (( "${http_status_code}" != 200 )); then
    slog error -m "Unable to connect to the reverse proxy service: ${http_status_code}"
    return 1
  fi

  # Export the fully qualified domain name of the reverse proxy host as
  # a read-only environment variable.
  declare -xr REVERSE_PROXY_FQDN="${reverse_proxy_fqdn}"
 
  # Extract the reverse proxy connection token and export it as a
  # read-only environment variable.
  declare -xr REVERSE_PROXY_TOKEN="$(echo ${http_response} | awk 'NF>1{printf $((NF-1))}' -)"

  # Check if the user specified a working directory for their Jupyter
  # notebook server. If the user did not specify a working directory, 
  # then set the working directory to the user's $HOME directory.
  if [[ -z "${jupyter_notebook_dir}" ]]; then
    jupyter_notebook_dir="${HOME}"  
  fi

  # Change the present working directory to the Jupyter notebook 
  # directory. If the directory does not exist, then halt the launch.
  cd "${jupyter_notebook_dir}"
  if [[ "${?}" -ne 0 ]]; then
    if [[ ! -d "${jupyter_notebook_dir}" ]]; then 
      slog error -m 'Jupyter notebook directory does not exist. Cannot change directory.'
    else
      slog error -m 'Unable to change directory to the Jupyter notebook directory.'
    fi 
    return 1 
  fi

  # Generate an authentication token to be used for first-time 
  # connections to the Jupyter notebook server and export it as a 
  # read-only environment variable.
  declare -xr JUPYTER_TOKEN="$(openssl rand -hex 16)"

  # Change present working directory to GALYLEO_CACHE_DIR. Generate and
  # store all Jupyter launch scripts and standard output files in the
  # GALYLEO_CACHE_DIR. Users should not need to access these files when
  # the service is working properly. They will generally only be useful
  # for debugging purposes by SDSC staff. A cleanup function to clear
  # the cache will be provided. We will eventually do some default
  # purging of older files to prevent cache buildup.
  if [[ ! -d "${GALYLEO_CACHE_DIR}" ]]; then
    mkdir -p "${GALYLEO_CACHE_DIR}"
    if [[ "${?}" -ne 0 ]]; then
      slog error -m "Failed to create GALYLEO_CACHE_DIR at ${GALYLEO_CACHE_DIR}."
      return 1
    fi
  fi
  cd "${GALYLEO_CACHE_DIR}"

  # Generate a Jupyter launch script.
  slog output -m 'Generating Jupyter launch script ...'
  if [[ ! -f "${job_name}.sh" ]]; then

    slog append -f "${job_name}.sh" -m '#!/usr/bin/env sh'
    slog append -f "${job_name}.sh" -m ''
    slog append -f "${job_name}.sh" -m "#SBATCH --job-name=${job_name}"

    if [[ -n "${account}" ]]; then
      slog append -f "${job_name}.sh" -m "#SBATCH --account=${account}"
    else
      slog error -m 'No account specified. Every job must be charged to an account.'
      rm "${job_name}.sh"
      return 1
    fi

    if [[ -n "${reservation}" ]]; then
      slog append -f "${job_name}.sh" -m "#SBATCH --reservation=${reservation}"
    fi

    slog append -f "${job_name}.sh" -m "#SBATCH --partition=${partition}"
    slog append -f "${job_name}.sh" -m "#SBATCH --nodes=${nodes}"
    slog append -f "${job_name}.sh" -m "#SBATCH --ntasks-per-node=${ntasks_per_node}"
    slog append -f "${job_name}.sh" -m "#SBATCH --cpus-per-task=${cpus_per_task}"

    if (( "${memory_per_node}" > 0 )); then
      slog append -f "${job_name}.sh" -m "#SBATCH --mem=${memory_per_node}G"
    else
      slog append -f "${job_name}.sh" -m "#SBATCH --mem-per-cpu=${memory_per_cpu}G"
    fi

    if [[ -n "${gpus}" && -z "${gres}" ]]; then
      slog append -f "${job_name}.sh" -m "#SBATCH --gpus=${gpus}"
    elif [[ -z "${gpus}" && -n "${gres}" ]]; then
      slog append -f "${job_name}.sh" -m "#SBATCH --gres=${gres}"
    fi

    slog append -f "${job_name}.sh" -m "#SBATCH --time=${time_limit}"

    if [[ -n "${constraint}" ]]; then
      slog append -f "${job_name}.sh" -m "#SBATCH --constraint=${constraint}"
    fi

    slog append -f "${job_name}.sh" -m "#SBATCH --no-requeue"
    slog append -f "${job_name}.sh" -m "#SBATCH --export=ALL"
    slog append -f "${job_name}.sh" -m "#SBATCH --output=${job_name}.o%j.%N"
    slog append -f "${job_name}.sh" -m ''

    slog append -f "${job_name}.sh" -m 'declare -xr JUPYTER_RUNTIME_DIR="${HOME}/.jupyter/runtime"'
    slog append -f "${job_name}.sh" -m 'declare -xi JUPYTER_PORT=-1'
    slog append -f "${job_name}.sh" -m 'declare -xir LOWEST_EPHEMERAL_PORT=49152'
    slog append -f "${job_name}.sh" -m 'declare -i random_ephemeral_port=-1'
    slog append -f "${job_name}.sh" -m ''

    slog append -f "${job_name}.sh" -m 'module purge'

    if [[ -n "${env_modules}" ]]; then
      IFS=','
      read -r -a modules <<< "${env_modules}"
      unset IFS
      for module in "${modules[@]}"; do
        slog append -f "${job_name}.sh" -m  "module load ${module}"
      done
    fi

    if [[ -n "${conda_env}" ]]; then
      slog append -f "${job_name}.sh" -m 'source ~/.bashrc'
      slog append -f "${job_name}.sh" -m "conda activate ${conda_env}"
    fi
    slog append -f "${job_name}.sh" -m ''

    slog append -f "${job_name}.sh" -m 'while (( "${JUPYTER_PORT}" < 0 )); do'
    slog append -f "${job_name}.sh" -m '  while (( "${random_ephemeral_port}" < "${LOWEST_EPHEMERAL_PORT}" )); do'
    slog append -f "${job_name}.sh" -m '    random_ephemeral_port="$(od -An -N 2 -t u2 -v < /dev/urandom)"'
    slog append -f "${job_name}.sh" -m '  done'
    slog append -f "${job_name}.sh" -m '  ss -nutlp | cut -d : -f2 | grep "^${random_ephemeral_port})" > /dev/null'
    slog append -f "${job_name}.sh" -m '  if [[ "${?}" -ne 0 ]]; then'
    slog append -f "${job_name}.sh" -m '    JUPYTER_PORT="${random_ephemeral_port}"'
    slog append -f "${job_name}.sh" -m '  fi'
    slog append -f "${job_name}.sh" -m 'done'
    slog append -f "${job_name}.sh" -m ''

    if [[ -n "${singularity_image_file}" ]]; then
      slog append -f "${job_name}.sh" -m 'singularity exec \'
      if [[ -n "${singularity_bind_mounts}" ]]; then
        slog append -f "${job_name}.sh" -m "  --bind ${singularity_bind_mounts} \\"
      fi
      if [[ -n "${singularity_gpu_type}" ]]; then
        slog append -f "${job_name}.sh" -m "  --${singularity_gpu_type} \\"
      fi
      slog append -f "${job_name}.sh" -m "  ${singularity_image_file} \\"
    fi
    slog append -f "${job_name}.sh" -m "jupyter ${jupyter_interface} --ip=\"\$(hostname -s).${dns_domain}\" --notebook-dir='${jupyter_notebook_dir}' --port=\"\${JUPYTER_PORT}\" --NotebookApp.allow_origin='*' --no-browser &"
    slog append -f "${job_name}.sh" -m 'if [[ "${?}" -ne 0 ]]; then'
    slog append -f "${job_name}.sh" -m "  echo 'ERROR: Failed to launch Jupyter.'"
    slog append -f "${job_name}.sh" -m '  exit 1'
    slog append -f "${job_name}.sh" -m 'fi'
    slog append -f "${job_name}.sh" -m ''

    # Redeem the connection token from reverse proxy service.
    slog append -f "${job_name}.sh" -m 'echo "https://manage.${REVERSE_PROXY_FQDN}/redeemtoken.cgi?token=${REVERSE_PROXY_TOKEN}&port=${JUPYTER_PORT}"'
    slog append -f "${job_name}.sh" -m "eval curl '\"https://manage.\${REVERSE_PROXY_FQDN}/redeemtoken.cgi?token=\${REVERSE_PROXY_TOKEN}&port=\${JUPYTER_PORT}\"'"
    slog append -f "${job_name}.sh" -m ''

    slog append -f "${job_name}.sh" -m 'wait'

  else

    slog error -m 'Jupyter launch script already exists. Cannot overwrite.'
    return 1

  fi

  # Submit Jupyter launch script to Slurm.
  job_id="$(sbatch ${job_name}.sh | grep -o '[[:digit:]]*')"
  if [[ "${?}" -ne 0 ]]; then
    slog error -m 'Failed job submission to Slurm.'
    return 1
  else
    slog output -m "Submitted Jupyter launch script to Slurm. Your SLURM_JOB_ID is ${job_id}."
  fi

  # Always print to standard output the URL where the Jupyter notebook 
  # server may be accessed by the user.
  slog output -m 'Please copy and paste the HTTPS URL provided below into your web browser.'
  slog output -m 'Do not share this URL with others. It is the password to your Jupyter notebook session.'
  slog output -m 'Your Jupyter notebook session will begin once compute resources are allocated to your Slurm job by the scheduler.'
  slog output -m ''
  echo "https://${REVERSE_PROXY_TOKEN}.${REVERSE_PROXY_FQDN}?token=${JUPYTER_TOKEN}"

  return 0

}

# ----------------------------------------------------------------------
# galyleo_clean
#
#   Clean up GALYLEO_CACHE_DIR. 
#
# Globals:
#
#   None
#
# Arguments:
#
#   None
#
# Returns:
#
#   True (0) always.
#
# ----------------------------------------------------------------------
function galyleo_clean() {

  rm -r "${GALYLEO_CACHE_DIR}"

  return 0

}

# ----------------------------------------------------------------------
# galyleo_help
#
#   Provides usage information to help users run galyleo.
#
# Globals:
#
#   None
#
# Arguments:
#
#   None
#
# Returns:
#
#   True (0) always.
#
# ----------------------------------------------------------------------
function galyleo_help() {

  slog output -m 'USAGE: galyleo.sh launch [command-line option] {value}'
  slog output -m ''
  slog output -m '  command-line option      : value'
  slog output -m ''
  slog output -m "    -A | --account         : ${account}"
  slog output -m "    -R | --reservation     : ${reservation}"
  slog output -m "    -p | --partition       : ${partition}"
  slog output -m "    -q | --qos             : ${qos}"
  slog output -m "    -N | --nodes           : ${nodes}"
  slog output -m "    -n | --ntasks-per-node : ${ntasks_per_node}"
  slog output -m "    -c | --cpus-per-task   : ${cpus_per_task}"
  slog output -m "    -M | --memory-per-node : ${memory_per_node}"
  slog output -m "    -m | --memory-per-cpu  : ${memory_per_cpu}"
  slog output -m "    -G | --gpus            : ${gpus}"
  slog output -m "       | --gres            : ${gres}"
  slog output -m "    -t | --time-limit      : ${time_limit}"
  slog output -m "    -j | --jupyter         : ${jupyter_interface}"
  slog output -m "    -d | --notebook-dir    : ${jupyter_notebook_dir}"
  slog output -m "    -r | --reverse-proxy   : ${reverse_proxy_fqdn}"
  slog output -m "    -D | --dns-domain      : ${dns_domain}"
  slog output -m "    -s | --sif             : ${singularity_image_file}"
  slog output -m "    -B | --bind            : ${singularity_bind_mounts}"
  slog output -m "       | --nv              : ${singularity_gpu_type}"
  slog output -m "    -e | --env-modules     : ${env_modules}"
  slog output -m "       | --conda-env       : ${conda_env}"
  slog output -m ''

  return 0

}

# ----------------------------------------------------------------------
# galyleo
#
#   This is the main function used to control the execution of galyleo
#   and its auxiliary functions.
#
# Globals:
#
#   @
#
# Arguments:
#
#   @
#
# Returns:
#
#   True  (0) if galyleo executed successfully without issue.
#   False (1) if galyleo failed to execute properly.
#
# ----------------------------------------------------------------------
function galyleo() {

  # Define local variables.
  local galyleo_command

  # Assign default values to local variables.
  galyleo_command=''

  # If at least one command-line argument was provided by the user, then
  # start parsing the command-line arguments. Otherwise, throw an error.
  if (( "${#}" > 0 )); then
 
    # Read in the first command-line argument, which is expected to be 
    # the main command issued by the user.
    galyleo_command="${1}"
    shift 1

    # Determine if the command provided by user is a valid. If it is a
    # valid command, then execute that command. Otherwise, throw an error.
    if [[ "${galyleo_command}" = 'launch' ]]; then

      galyleo_launch "${@}"
      if [[ "${?}" -ne 0 ]]; then
        slog error -m 'galyleo_launch command failed.'
        exit 1
      fi

    elif [[ "${galyleo_command}" = 'clean' ]]; then
    
      galyleo_clean
      if [[ "${?}" -ne 0 ]]; then
        slog error -m 'galyleo_clean command failed.'
        exit 1
      fi

    elif [[ "${galyleo_command}" = 'help' || \
            "${galyleo_command}" = '-h' || \
            "${galyleo_command}" = '--help' ]]; then

      galyleo_help
      if [[ "${?}" -ne 0 ]]; then
        slog error -m 'galyleo_help command failed.'
        exit 1
      fi
    
    else
    
      slog error -m 'Command not recognized or not supported.'
      exit 1

    fi

  else

    slog error -m 'No command-line arguments were provided.'
    exit 1

  fi
  
  exit 0

}

# ----------------------------------------------------------------------

galyleo "${@}"

# ======================================================================
