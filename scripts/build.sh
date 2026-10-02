#!/usr/bin/env bash

###
#
# Creates a zip with the need files to import the plugin in Godot
#
###

source "$(dirname "$0")/shared"



# Define a cleanup function to run at the end, no matter what
cleanup() {
  if [ -f "$temp_file" ]; then
    rm "$temp_file"
  fi
}

# Register the cleanup function to run on exit
trap cleanup EXIT

# Default values
temp_file="-"
test_version=false

# Parse options
while getopts ":t" opt; do
  case $opt in
    t)
      test_version=true
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Shift away the parsed options
shift $((OPTIND - 1))

# The version needs to be the same in the code and in the plugin config
if [ "${PLUGIN_VERSION}" != "${PLUGIN_CONFIG_VERSION}" ]; then
  fail "Version mismatch: ${COLOR_VERSION}${PLUGIN_VERSION}${COLOR_RESET} in $(basename "${VERSION_GD_FILE}") != ${COLOR_VERSION}${PLUGIN_CONFIG_VERSION}${COLOR_RESET} in $(basename "${PLUGIN_CONFIG_FILE}")"
fi

# If -t was given, test that the version is the same as the tag to use
if [ "${test_version}" = true ]; then
  tagName=$(get_github_tag)

  if [ -z "${tagName}" ]; then
    fail "No tag detected."
  fi

  info "Codebase version: ${COLOR_VERSION}${PLUGIN_VERSION}${COLOR_RESET}"
  info "Building from tag: ${COLOR_TAG}${tagName}${COLOR_RESET}"

  if [ "v${PLUGIN_VERSION}" != "${tagName}" ]; then
    fail "Version mismatch: ${COLOR_VERSION}${PLUGIN_VERSION}${COLOR_RESET} != ${COLOR_TAG}${tagName}${COLOR_RESET}".
  else
    info "Versions match."
  fi
fi

# Create a temporal file
temp_file=$(mktemp)

# Calculate variables to use
zip_file="${OUTPUT_FOLDER}/$(basename "${PLUGIN_FOLDER}")-${PLUGIN_VERSION}.zip"
# Initial dot needs to be removed for paths to be preserved
find "${PLUGIN_FOLDER}" -type f ! -name "*.uid" | sed 's|^\./||' > "${temp_file}"

# Output feedback
echo -e "Creating a .zip file for ${COLOR_NAME}${PLUGIN_NAME} ${COLOR_VERSION}v${PLUGIN_VERSION}${COLOR_RESET} > ${COLOR_FILE}${zip_file}${COLOR_RESET}"
while IFS= read -r file; do
  echo -e "${COLOR_DIM} - ${file}${COLOR_RESET}"
done < "${temp_file}"
echo

# If the output file existed, remove it
if [ -f "${zip_file}" ]; then
  rm "${zip_file}"
fi

# If the output folder doesn't exist, create it
if [ ! -d "${OUTPUT_FOLDER}" ]; then
  mkdir -p "${OUTPUT_FOLDER}"
fi

# Create the zip file
zip_files "${zip_file}" "${temp_file}"
