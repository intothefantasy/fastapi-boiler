#!/bin/bash


expected_python_version="3.9"

script_directory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
venv_path=${script_directory}/../venv
backend_path=${script_directory}/../backend
app_path=${script_directory}/../backend/api_server

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NORMAL_COLOUR='\033[0;0m'
OVERWRITE_PREVIOUS_LINE='\r\033[1A'


function print_help {
  echo ""
  echo "setup_python_venv.sh script usage:"
  echo ""
  echo "Passing the -r flag will delete and recreate the venv directory"
  echo "Passing the -m flag will turn off colour output for echo commands"
  echo "Passing the -p flag allows the user to pass a specific path to a python executable"
  echo "Passing the -h flag prints this message"
  echo ""
  echo "Examples"
  echo ""
  echo "1) Setup venv for the first time"
  echo -e "${YELLOW}    setup_python_venv.sh${NORMAL_COLOUR}"
  echo ""
  echo "2) Update current venv with latest requirements"
  echo -e "${YELLOW}    setup_python_venv.sh${NORMAL_COLOUR}"
  echo "    (i.e. the same command as (1), but venv folder already exists)"
  echo ""
  echo "3) Overwrite existing venv"
  echo -e "${YELLOW}    setup_python_venv.sh -r${NORMAL_COLOUR}"
  echo ""
  echo "4) Create venv with a specific python executable"
  echo -e "${YELLOW}    setup_python_venv.sh -r -p <path-to-python-executable>${NORMAL_COLOUR}"
  echo ""
  echo ""
}

function get_python_version {
  # This function takes one parameter:
  # The name of (or path to) the python executable
  python_version=$($1 -c 'import sys; version=sys.version_info[:2]; print("{0}.{1}".format(*version))' 2> /dev/null)
}

creating_venv_message="Creating the venv"
while getopts "hramp:" arg
do
  case ${arg} in
    h)
      print_help
      exit 0
      ;;
    r)
      if [ -d ${venv_path} ] ; then
        echo "Removing the venv from $(realpath -s ${venv_path})"
        rm -rf ${venv_path}
        creating_venv_message="Recreating the venv"
      fi
      ;;
    m)
      # monochrome (colourless) output
      RED=''
      GREEN=''
      YELLOW=''
      NORMAL_COLOUR=''
      ;;
    p)
      if [[ ! -f ${OPTARG} ]] ; then
        echo -e "${RED}The path to your python executable does not exist: ${OPTARG}${NORMAL_COLOUR}"
        exit 1
      else
        python_path=${OPTARG}
        get_python_version ${python_path}
        python_version_return_value=$?
        if [ ${python_version_return_value} -ne 0 ] ; then
          echo -e "${RED}Invalid python executable: ${python_path}${NORMAL_COLOUR}"
          exit 1
        else
          echo -e "${GREEN}Using Python ${python_version} from path: ${python_path}${NORMAL_COLOUR}"
          if [ $(echo ${python_version} | grep -c ${expected_python_version}) -eq 0 ] ; then
            echo -e "${RED}Python version ${python_version} is not the recommended version: ${expected_python_version}${NORMAL_COLOUR}"
            exit 1
          fi
        fi
      fi
      ;;
    \?)
      echo -e "${RED}Invalid flag passed: ${OPTARG}${NORMAL_COLOUR}" 1>&2
      exit 1
      ;;
  esac
done


function find_correct_python_executable {
  echo "Python ${expected_python_version} is required, but you are using Python ${python_version} from: $(which python)"
  echo "Checking to see if you have python version ${expected_python_version} installed"

  IFS=:
  python_path=$(for path in ${PATH}
  do
    find ${path} -name python${expected_python_version} -print -quit 2> /dev/null
  done)

  if [[ ${python_path} != '' ]] ; then
    echo -e "${OVERWRITE_PREVIOUS_LINE}${GREEN}Successfully found python version ${expected_python_version} in location: ${python_path}${NORMAL_COLOUR}"
    get_python_version "${python_path}"
    python_version_return_value=$?
    if [ ${python_version_return_value} -ne 0 ] ; then
      echo -e "${RED}Failed to discover version by running '${python_path}'${NORMAL_COLOUR}"
      echo -e "${RED}Try adding the -p flag with the path to your Python ${expected_python_version} binary${NORMAL_COLOUR}"
      exit 1
    fi
  else
    echo -e "${RED}Unable to find python version ${expected_python_version} on your path${NORMAL_COLOUR}"
    echo
    echo "Your \$PATH is:"
    echo
    echo "${PATH//:/$'\n'}"
    echo
    echo -e "${RED}Failed to create venv: incorrect Python version ${python_version} (should be ${expected_python_version})${NORMAL_COLOUR}"
    echo -e "${RED}Try adding the -p flag with the path to your Python ${expected_python_version} binary${NORMAL_COLOUR}"
    exit 1
  fi
}

function create_venv {
  echo ${creating_venv_message}

  # ${python_path} will already be set if using the -p flag
  if [[ ${python_path} == "" ]] ; then
    # Python should always be available as 'python'
    # if it is installed
    python_path="python"

    if ! [ -x "$(command -v ${python_path})" ] ; then
      echo -e "${RED}Cannot find Python within \$PATH:${NORMAL_COLOUR}"
      echo
      echo "${PATH//:/$'\n'}"
      echo
      echo -e "${RED}Failed to create venv - cannot find Python${NORMAL_COLOUR}"
      echo -e "${RED}Try adding the -p flag with the path to your Python ${expected_python_version} binary${NORMAL_COLOUR}"
      exit 1
    fi

    # Check the Python version
    get_python_version "${python_path}"
    python_version_return_value=$?

    if [ ${python_version_return_value} -ne 0 ] ; then
      echo -e "${RED}Failed to discover version by running '${python_path}'${NORMAL_COLOUR}"
      echo -e "${RED}Try adding the -p flag with the path to your Python ${expected_python_version} binary${NORMAL_COLOUR}"
      exit 1
    elif [ "${expected_python_version}" != "${python_version}" ] ; then
      find_correct_python_executable
    fi
  fi

  # Create the venv
  echo "Creating venv using Python ${python_version}"
  ${python_path} -m venv ${venv_path}
  if [ ! -d ${venv_path} ] ; then
      echo -e "${RED}Failed to create venv: '${python_path} -m venv venv' command failed${NORMAL_COLOUR}"
      exit 1
  else
      echo -e "${OVERWRITE_PREVIOUS_LINE}${GREEN}Successfully created venv with Python ${python_version}${NORMAL_COLOUR}"
  fi
}

function activate_venv {
  echo "Activating the venv"
  if [ -d "${venv_path}/Scripts" ]; then
    . ${venv_path}/Scripts/activate
  elif [ -d "${venv_path}/bin" ]; then
    . ${venv_path}/bin/activate
  fi

  if [[ ${VIRTUAL_ENV} != '' ]]
  then
    # this need three echo statements as on windows
    # as echo -e formats ${VIRTUAL_ENV} badly over 2 lines
    echo -en "${OVERWRITE_PREVIOUS_LINE}${GREEN}Successfully activated venv: "
    echo -n "${VIRTUAL_ENV}"
    echo -e "${NORMAL_COLOUR}"
  else
    echo -e "${RED}Failed to activate venv${NORMAL_COLOUR}"
    exit 1
  fi
}

function install_requirements {
  echo "Installing requirements"
  python -m pip install --upgrade pip
  pip install pip-tools --upgrade

  pip-sync ${app_path}/requirements.txt
  pip_sync_return_value=$?
  if [ ${pip_sync_return_value} -ne 0 ]; then
    echo -e "${RED}Failed to install requirements${NORMAL_COLOUR}"
    exit ${pip_sync_return_value}
  else
    echo -e "${GREEN}Successfully installed requirements${NORMAL_COLOUR}"
  fi
}


[ ! -d ${venv_path} ] && create_venv
activate_venv
install_requirements

site_packages_path=$(find ${venv_path} -name site-packages)

echo ""
echo -e "${GREEN}┌─────────────────────────┐"
echo -e "│ Successfully setup venv │"
echo -e "└─────────────────────────┘${NORMAL_COLOUR}"
echo ""
